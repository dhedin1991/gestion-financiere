import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money.dart';
import '../models/net_worth_snapshot_model.dart';

/// Requêtes d'agrégation pour le module Bilans : calcul du patrimoine net
/// (comptes + épargne + biens + créances - dettes - crédits restants) et
/// données brutes pour les graphiques Revenus/Dépenses.
///
/// Toutes les colonnes sommées ici (`current_balance`, `estimated_value`,
/// `total_amount`, `amount`) sont stockées en base en **centimes entiers**
/// (voir `core/utils/money.dart`) : chaque somme SQL brute est donc
/// reconvertie en unités normales via [Money.fromCents] avant d'être
/// utilisée par le reste de l'application.
///
/// Tous les calculs sont limités à l'entité active ([entityId]) : comptes,
/// épargne, biens, dettes et crédits d'une autre entité n'y entrent pas.
/// Les dettes et crédits sans compte lié sont, comme dans leurs écrans,
/// visibles dans toutes les entités.
class BilanDao {
  final AppDatabase appDatabase;

  BilanDao(this.appDatabase);

  /// Fragment SQL « le compte appartient à l'entité » (vide si pas d'entité).
  static String _accountInEntity(String column) =>
      '$column IN (SELECT id FROM accounts WHERE entity_id = ?)';

  // ---------------- PATRIMOINE NET ----------------

  /// Devise principale = la plus utilisée parmi les comptes actifs de
  /// l'entité (même règle que `pickMainCurrency`, côté Dart). Les bilans
  /// n'additionnent que cette devise pour ne jamais mélanger XOF et EUR.
  Future<String> _mainCurrency(int? entityId) async {
    final db = await appDatabase.database;
    final rows = await db.rawQuery(
      'SELECT currency, COUNT(*) AS c FROM accounts WHERE is_archived = 0 '
      '${entityId == null ? '' : 'AND entity_id = ? '}'
      "GROUP BY currency ORDER BY c DESC, CASE WHEN currency = 'XOF' THEN 0 ELSE 1 END, currency LIMIT 1",
      [if (entityId != null) entityId],
    );
    return rows.isEmpty ? 'XOF' : rows.first['currency'] as String;
  }

  Future<double> _getTotalAccountsBalance(String currency, int? entityId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery(
      'SELECT SUM(current_balance) as total FROM accounts '
      'WHERE is_archived = 0 AND currency = ? ${entityId == null ? '' : 'AND entity_id = ?'}',
      [currency, if (entityId != null) entityId],
    );
    return Money.fromCents((((result.first['total'] as num?) ?? 0)).toInt());
  }

  Future<double> _getTotalSavingsBalance(String currency, int? entityId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery(
      'SELECT SUM(current_balance) as total FROM savings '
      'WHERE currency = ? ${entityId == null ? '' : 'AND ${_accountInEntity('account_id')}'}',
      [currency, if (entityId != null) entityId],
    );
    return Money.fromCents((((result.first['total'] as num?) ?? 0)).toInt());
  }

  Future<double> _getTotalPatrimoineValue(String currency, int? entityId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery(
      'SELECT SUM(estimated_value) as total FROM patrimoine_items '
      'WHERE currency = ? ${entityId == null ? '' : 'AND entity_id = ?'}',
      [currency, if (entityId != null) entityId],
    );
    return Money.fromCents((((result.first['total'] as num?) ?? 0)).toInt());
  }

  /// Somme des restes dus sur les dettes/créances du [type] donné.
  Future<double> _getTotalRemainingDebts(String type, String currency, int? entityId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('''
      SELECT SUM(d.total_amount - COALESCE(p.paid, 0)) as total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) as paid FROM debt_payments GROUP BY debt_id
      ) p ON p.debt_id = d.id
      WHERE d.type = ? AND d.currency = ?
      ${entityId == null ? '' : 'AND (d.account_id IS NULL OR ${_accountInEntity('d.account_id')})'}
    ''', [type, currency, if (entityId != null) entityId]);
    return Money.fromCents((((result.first['total'] as num?) ?? 0)).toInt());
  }

  /// Somme des créances restantes (argent qu'on te doit).
  Future<double> _getTotalReceivables(String currency, int? entityId) =>
      _getTotalRemainingDebts('creance', currency, entityId);

  /// Somme des dettes restantes (argent que tu dois).
  Future<double> _getTotalDebts(String currency, int? entityId) =>
      _getTotalRemainingDebts('dette', currency, entityId);

  /// Somme des échéances de crédit pas encore payées (capital restant dû approximatif).
  Future<double> _getTotalCreditsRemaining(String currency, int? entityId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('''
      SELECT SUM(ci.amount) as total
      FROM credit_installments ci
      JOIN credits c ON c.id = ci.credit_id
      WHERE ci.status != 'payee' AND c.currency = ?
      ${entityId == null ? '' : 'AND (c.account_id IS NULL OR ${_accountInEntity('c.account_id')})'}
    ''', [currency, if (entityId != null) entityId]);
    return Money.fromCents((((result.first['total'] as num?) ?? 0)).toInt());
  }

  /// Calcule le patrimoine net actuel de l'entité [entityId] (sans le
  /// sauvegarder). [entityId] null = toutes les entités.
  Future<NetWorthSnapshotModel> computeCurrentSnapshot({int? entityId}) async {
    final currency = await _mainCurrency(entityId);
    final totalAccounts = await _getTotalAccountsBalance(currency, entityId);
    final totalSavings = await _getTotalSavingsBalance(currency, entityId);
    final totalPatrimoine = await _getTotalPatrimoineValue(currency, entityId);
    final totalReceivables = await _getTotalReceivables(currency, entityId);
    final totalDebts = await _getTotalDebts(currency, entityId);
    final totalCreditsRemaining = await _getTotalCreditsRemaining(currency, entityId);

    final netWorth = totalAccounts +
        totalSavings +
        totalPatrimoine +
        totalReceivables -
        totalDebts -
        totalCreditsRemaining;

    final now = DateTime.now();
    return NetWorthSnapshotModel(
      snapshotDate: now,
      totalAccounts: totalAccounts,
      totalSavings: totalSavings,
      totalPatrimoine: totalPatrimoine,
      totalReceivables: totalReceivables,
      totalDebts: totalDebts,
      totalCreditsRemaining: totalCreditsRemaining,
      netWorth: netWorth,
      createdAt: now,
    );
  }

  /// Enregistre ou met à jour la photo du jour de l'entité [entityId] (si
  /// elle existe déjà pour aujourd'hui, elle est remplacée avec les valeurs
  /// à jour). Une photo par jour ET par entité.
  Future<void> upsertTodaySnapshot(NetWorthSnapshotModel snapshot, {int? entityId}) async {
    final db = await appDatabase.database;
    final dateKey = snapshot.snapshotDate.toIso8601String().split('T').first;
    final values = {...snapshot.toMap(), 'entity_id': entityId};

    final existing = await db.query(
      'net_worth_snapshots',
      where: 'snapshot_date = ? AND IFNULL(entity_id, 0) = ?',
      whereArgs: [dateKey, entityId ?? 0],
    );

    if (existing.isEmpty) {
      await db.insert('net_worth_snapshots', values);
    } else {
      await db.update(
        'net_worth_snapshots',
        values,
        where: 'snapshot_date = ? AND IFNULL(entity_id, 0) = ?',
        whereArgs: [dateKey, entityId ?? 0],
      );
    }
  }

  /// Historique des photos de l'entité [entityId] (null = toutes), du plus
  /// ancien au plus récent.
  Future<List<NetWorthSnapshotModel>> getAllSnapshots({int? entityId}) async {
    final db = await appDatabase.database;
    final results = await db.query(
      'net_worth_snapshots',
      where: entityId == null ? null : 'entity_id = ?',
      whereArgs: entityId == null ? null : [entityId],
      orderBy: 'snapshot_date ASC',
    );
    return results.map((map) => NetWorthSnapshotModel.fromMap(map)).toList();
  }

  // ---------------- REVENUS / DÉPENSES ----------------

  /// Retourne les transactions brutes (type, montant, date) entre deux dates,
  /// pour que la couche présentation les regroupe par période au choix.
  /// Limitées à l'entité [entityId] et à sa devise principale (jamais de
  /// mélange de devises).
  Future<List<Map<String, dynamic>>> getTransactionsBetween(
    DateTime start,
    DateTime end, {
    int? entityId,
  }) async {
    final db = await appDatabase.database;
    final currency = await _mainCurrency(entityId);
    return db.query(
      'transactions',
      columns: ['type', 'amount', 'transaction_date'],
      where: 'transaction_date >= ? AND transaction_date <= ? AND currency = ?'
          '${entityId == null ? '' : ' AND ${_accountInEntity('account_id')}'}',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
        currency,
        if (entityId != null) entityId,
      ],
      orderBy: 'transaction_date ASC',
    );
  }
}
