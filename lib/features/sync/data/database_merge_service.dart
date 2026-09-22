import 'package:sqflite/sqflite.dart';

/// Fusionne les données d'une base distante (`remote`, jointe en lecture
/// seule via `ATTACH DATABASE`) dans la base locale ouverte (`db`), au lieu
/// de tout remplacer comme le fait la synchronisation Wi-Fi classique.
///
/// Principe : chaque table « catalogue » (comptes, catégories, entités,
/// épargnes, dettes, crédits, biens, budgets, récurrences) est rapprochée
/// par une **clé naturelle** (nom, ou combinaison de champs stables) plutôt
/// que par son `id` — deux appareils qui ont créé des données en parallèle
/// leur donnent des `id` différents pour la même chose, et parfois le même
/// `id` pour deux choses différentes. Un enregistrement du même nom des
/// deux côtés est considéré comme LE MÊME et n'est jamais dupliqué ; un
/// enregistrement nouveau reçoit un nouvel `id` local, et toutes ses
/// références (compte, catégorie, entité...) sont réécrites vers les `id`
/// locaux correspondants.
///
/// Les tables « mouvements » (transactions, versements d'épargne,
/// paiements de dette) sont fusionnées de façon additive : un mouvement du
/// fichier distant identique à un mouvement déjà présent (même compte,
/// même date, même montant, même description) est ignoré ; les autres sont
/// ajoutés. Cela permet de fusionner deux appareils qui ont chacun
/// enregistré des opérations différentes depuis la dernière synchronisation.
///
/// Volontairement laissés hors fusion (impact limité, complexité inutile) :
/// - le journal d'audit (`history_log`) — informatif seulement ;
/// - les photos de patrimoine (`net_worth_snapshots`) — régénérées
///   automatiquement à la prochaine ouverture de l'écran Bilans.
///
/// Après la fusion, `accounts.current_balance` et `savings.current_balance`
/// sont recalculés à partir des mouvements réels (plutôt que fusionnés
/// eux-mêmes), pour rester exacts quelle que soit la façon dont les deux
/// appareils avaient dérivé.
class DatabaseMergeService {
  final Database db;
  DatabaseMergeService(this.db);

  /// Résultat : nombre de nouveaux enregistrements ajoutés, par table.
  Future<Map<String, int>> mergeFrom(String remoteDbPath) async {
    final added = <String, int>{};

    await db.execute("ATTACH DATABASE ? AS remote", [remoteDbPath]);
    try {
      await db.transaction((txn) async {
        final entityMap = await _mergeByName(txn, added,
            table: 'business_entities', naturalCols: ['name']);

        final categoryMap = await _mergeByName(txn, added,
            table: 'categories', naturalCols: ['name', 'type']);
        await _remapColumn(txn, 'categories', 'parent_id', categoryMap);

        final accountMap = await _mergeByName(txn, added,
            table: 'accounts',
            naturalCols: ['name'],
            remap: {'entity_id': entityMap});

        await _mergeByName(txn, added,
            table: 'patrimoine_items',
            naturalCols: ['name', 'category'],
            remap: {'entity_id': entityMap},
            updateIfNewer: true);

        final savingsMap = await _mergeByName(txn, added,
            table: 'savings',
            naturalCols: ['name'],
            remap: {'account_id': accountMap});

        await _mergeByName(txn, added,
            table: 'recurring_transactions',
            naturalCols: ['account_id', 'category_id', 'type', 'amount', 'frequency', 'description'],
            remap: {'account_id': accountMap, 'category_id': categoryMap},
            onConflictKeepLatestOf: 'next_due_date'); // reprend l'échéance la plus avancée

        final debtMap = await _mergeByName(txn, added,
            table: 'debts',
            naturalCols: ['type', 'person_name', 'total_amount', 'due_date'],
            remap: {'account_id': accountMap},
            updateIfNewer: true);

        final creditMap = await _mergeByName(txn, added,
            table: 'credits',
            naturalCols: ['name', 'start_date', 'principal_amount'],
            remap: {'account_id': accountMap},
            updateIfNewer: true);

        await _mergeByName(txn, added,
            table: 'budgets',
            naturalCols: ['name', 'category_id', 'period', 'start_date'],
            remap: {'category_id': categoryMap, 'entity_id': entityMap},
            updateIfNewer: true);

        // ---- Fusion additive des mouvements ----
        await _mergeAdditive(txn, added,
            table: 'transactions',
            remap: {'account_id': accountMap, 'category_id': categoryMap},
            dedupeCols: ['account_id', 'transaction_date', 'type', 'amount', 'description']);

        await _mergeAdditive(txn, added,
            table: 'savings_transactions',
            remap: {'savings_id': savingsMap},
            dedupeCols: ['savings_id', 'date', 'type', 'amount']);

        await _mergeAdditive(txn, added,
            table: 'debt_payments',
            remap: {'debt_id': debtMap},
            dedupeCols: ['debt_id', 'payment_date', 'amount']);

        // ---- Échéances de crédit : rapprochées par date au sein du crédit,
        // le statut "payée" l'emporte toujours (une fois payé, ça le reste).
        await _mergeInstallments(txn, added, creditMap);

        // ---- Recalcul des soldes à partir des mouvements réels ----
        await txn.rawUpdate('''
          UPDATE accounts SET current_balance = initial_balance + IFNULL((
            SELECT SUM(CASE WHEN t.type = 'revenu' THEN t.amount ELSE -t.amount END)
            FROM transactions t WHERE t.account_id = accounts.id
          ), 0)
        ''');
        await txn.rawUpdate('''
          UPDATE savings SET current_balance = IFNULL((
            SELECT SUM(CASE WHEN st.type = 'versement' THEN st.amount ELSE -st.amount END)
            FROM savings_transactions st WHERE st.savings_id = savings.id
          ), 0)
        ''');
      });
    } finally {
      await db.execute("DETACH DATABASE remote");
    }

    return added;
  }

  /// Rapproche `remote.<table>` et `db.<table>` par une clé naturelle
  /// ([naturalCols], déjà exprimée en `id` LOCAUX grâce à [remap]).
  /// Retourne la correspondance `id distant -> id local`. Les colonnes de
  /// [remap] sont réécrites AVANT comparaison, donc deux lignes ne peuvent
  /// se rapprocher que si leurs références pointent déjà vers le même
  /// enregistrement local.
  Future<Map<int, int>> _mergeByName(
    Transaction txn,
    Map<String, int> added, {
    required String table,
    required List<String> naturalCols,
    Map<String, Map<int, int>> remap = const {},
    bool updateIfNewer = false,
    String? onConflictKeepLatestOf,
  }) async {
    final map = <int, int>{};
    final remoteRows = await txn.query('remote.$table');
    final localRows = await txn.query(table);

    String keyOf(Map<String, dynamic> row, Map<String, Map<int, int>> r) {
      return naturalCols.map((c) {
        var v = row[c];
        final m = r[c];
        if (m != null && v != null) v = m[v as int] ?? v;
        return '$c=$v';
      }).join('|');
    }

    final localByKey = <String, Map<String, dynamic>>{
      for (final row in localRows) keyOf(row, const {}): row,
    };

    for (final remoteRow in remoteRows) {
      final key = keyOf(remoteRow, remap);
      final localMatch = localByKey[key];
      final remoteId = remoteRow['id'] as int;

      if (localMatch != null) {
        map[remoteId] = localMatch['id'] as int;
        if (updateIfNewer &&
            remoteRow.containsKey('updated_at') &&
            localMatch.containsKey('updated_at') &&
            (remoteRow['updated_at'] as String?)
                    ?.compareTo(localMatch['updated_at'] as String? ?? '') ==
                1) {
          final values = _applyRemap(remoteRow, remap)..remove('id');
          await txn.update(table, values, where: 'id = ?', whereArgs: [localMatch['id']]);
        } else if (onConflictKeepLatestOf != null) {
          final localVal = localMatch[onConflictKeepLatestOf] as String?;
          final remoteVal = remoteRow[onConflictKeepLatestOf] as String?;
          if (remoteVal != null && (localVal == null || remoteVal.compareTo(localVal) > 0)) {
            await txn.update(table, {onConflictKeepLatestOf: remoteVal},
                where: 'id = ?', whereArgs: [localMatch['id']]);
          }
        }
        continue;
      }

      final values = _applyRemap(remoteRow, remap)..remove('id');
      final newId = await txn.insert(table, values);
      map[remoteId] = newId;
      added[table] = (added[table] ?? 0) + 1;
      localByKey[key] = {...values, 'id': newId};
    }
    return map;
  }

  /// Ajoute les lignes de `remote.<table>` absentes localement (comparées
  /// sur [dedupeCols], déjà réécrites via [remap]) ; ignore les autres.
  Future<void> _mergeAdditive(
    Transaction txn,
    Map<String, int> added, {
    required String table,
    required Map<String, Map<int, int>> remap,
    required List<String> dedupeCols,
  }) async {
    final remoteRows = await txn.query('remote.$table');
    final localRows = await txn.query(table, columns: dedupeCols);

    String keyOf(Map<String, dynamic> row) => dedupeCols.map((c) => '$c=${row[c]}').join('|');
    final localKeys = localRows.map(keyOf).toSet();

    for (final remoteRow in remoteRows) {
      final values = _applyRemap(remoteRow, remap)..remove('id');
      final key = keyOf(values);
      if (localKeys.contains(key)) continue;
      await txn.insert(table, values);
      localKeys.add(key);
      added[table] = (added[table] ?? 0) + 1;
    }
  }

  /// Échéances de crédit : rapprochées par (crédit local, date d'échéance).
  /// Le statut "payée" l'emporte toujours, qu'il vienne du fichier distant
  /// ou de la base locale — un paiement enregistré sur un appareil ne doit
  /// jamais être perdu par la fusion.
  Future<void> _mergeInstallments(
    Transaction txn,
    Map<String, int> added,
    Map<int, int> creditMap,
  ) async {
    final remoteRows = await txn.query('remote.credit_installments');
    final localRows = await txn.query('credit_installments');

    final localByKey = <String, Map<String, dynamic>>{
      for (final row in localRows) '${row['credit_id']}|${row['due_date']}': row,
    };

    for (final remoteRow in remoteRows) {
      final remoteCreditId = remoteRow['credit_id'] as int?;
      final localCreditId = remoteCreditId == null ? null : creditMap[remoteCreditId];
      if (localCreditId == null) continue; // crédit inconnu des deux côtés : ignoré
      final key = '$localCreditId|${remoteRow['due_date']}';
      final localMatch = localByKey[key];

      if (localMatch == null) {
        final values = Map<String, dynamic>.from(remoteRow)
          ..remove('id')
          ..['credit_id'] = localCreditId;
        await txn.insert('credit_installments', values);
        added['credit_installments'] = (added['credit_installments'] ?? 0) + 1;
        continue;
      }

      final remotePayee = remoteRow['status'] == 'payee';
      final localPayee = localMatch['status'] == 'payee';
      if (remotePayee && !localPayee) {
        await txn.update(
          'credit_installments',
          {'status': 'payee', 'payment_date': remoteRow['payment_date']},
          where: 'id = ?',
          whereArgs: [localMatch['id']],
        );
      }
    }
  }

  Map<String, dynamic> _applyRemap(Map<String, dynamic> row, Map<String, Map<int, int>> remap) {
    final values = Map<String, dynamic>.from(row);
    remap.forEach((col, map) {
      final v = values[col];
      if (v != null) values[col] = map[v as int] ?? v;
    });
    return values;
  }

  Future<void> _remapColumn(Transaction txn, String table, String col, Map<int, int> map) async {
    for (final entry in map.entries) {
      await txn.rawUpdate('UPDATE $table SET $col = ? WHERE $col = ?', [entry.value, entry.key]);
    }
  }
}
