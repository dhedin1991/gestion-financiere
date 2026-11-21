import '../../../../core/database/app_database.dart';
import '../../../../core/ledger/ledger.dart';
import '../../../../core/utils/money.dart';

/// DAO Épargne.
///
/// Point important : chaque versement/retrait doit mettre à jour à la fois
/// `savings.current_balance` ET `accounts.current_balance` du compte lié.
/// On utilise `db.transaction()` pour garantir que les trois écritures
/// (mouvement + solde épargne + solde compte) se font ensemble ou pas
/// du tout (atomicité), exactement comme pour le module Transactions.
///
/// Les montants transitent en unités normales (double) dans l'API
/// publique de ce DAO ; la conversion vers/depuis les centimes entiers
/// stockés en base se fait ici, juste avant/après chaque requête SQL.
class SavingsDao {
  final AppDatabase _appDatabase;
  SavingsDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await _appDatabase.database;
    return db.query('savings', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> findById(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('savings', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('savings', data);
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    await db.update('savings', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _appDatabase.database;
    await db.delete('savings', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> findTransactionsBySavings(int savingsId) async {
    final db = await _appDatabase.database;
    return db.query(
      'savings_transactions',
      where: 'savings_id = ?',
      whereArgs: [savingsId],
      orderBy: 'date DESC, id DESC',
    );
  }

  /// Enregistre un versement ou un retrait ET répercute l'effet sur :
  /// - le solde de l'épargne (savings.current_balance)
  /// - le solde du compte lié (accounts.current_balance)
  /// signedAmount est positif pour un versement, négatif pour un retrait.
  /// Pour le compte, l'effet est inversé : un versement retire de l'argent
  /// du compte (donc -signedAmount côté compte), un retrait lui en rend.
  Future<int> insertTransactionWithBalanceUpdate({
    required Map<String, dynamic> data,
    required int savingsId,
    required int accountId,
    required double signedAmount,
  }) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    final signedCents = Money.toCents(signedAmount);
    return db.transaction((txn) async {
      final id = await txn.insert('savings_transactions', data);

      // Le solde de l'épargne évolue dans le même sens que le mouvement.
      await txn.rawUpdate(
        'UPDATE savings SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [signedCents, nowIso, savingsId],
      );

      // Le solde du compte évolue en sens inverse (un versement sort de l'argent
      // du compte) : écriture neutre du grand livre.
      final sv = await txn.query('savings',
          columns: ['name', 'currency'], where: 'id = ?', whereArgs: [savingsId], limit: 1);
      await Ledger.post(
        txn,
        accountId: accountId,
        signedCents: -signedCents,
        kind: LedgerKind.epargneObjectif,
        refId: id,
        currency: sv.isEmpty ? 'XOF' : (sv.first['currency'] as String? ?? 'XOF'),
        description: '${signedCents >= 0 ? 'Versement' : 'Retrait'} épargne — ${sv.isEmpty ? '' : sv.first['name']}',
        date: DateTime.tryParse('${data['date']}'),
      );

      return id;
    });
  }

  /// Met à jour un mouvement existant (montant, date, note, type) ET
  /// répercute correctement la différence sur les deux soldes : on annule
  /// d'abord l'effet de l'ancien montant, puis on applique l'effet du
  /// nouveau, en une seule transaction atomique.
  Future<void> updateTransactionWithBalanceUpdate({
    required int transactionId,
    required Map<String, dynamic> data,
    required int savingsId,
    required int accountId,
    required double oldSignedAmount,
    required double newSignedAmount,
  }) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    // Le delta est calculé en centimes directement (différence de deux
    // valeurs déjà converties) pour éviter tout écart d'arrondi entre
    // deux conversions séparées.
    final deltaCents = Money.toCents(newSignedAmount) - Money.toCents(oldSignedAmount);

    await db.transaction((txn) async {
      await txn.update(
        'savings_transactions',
        data,
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      await txn.rawUpdate(
        'UPDATE savings SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [deltaCents, nowIso, savingsId],
      );

      final linked = await txn.query('transactions',
          where: 'kind = ? AND ref_id = ?', whereArgs: [LedgerKind.epargne, transactionId], limit: 1);
      if (linked.isNotEmpty) {
        throw StateError('Ce versement vient d\u2019une opération Transactions : supprimez-le puis recréez-le.');
      }
      final n = await Ledger.unpost(txn, kinds: [LedgerKind.epargneObjectif], refId: transactionId);
      if (n == 0) {
        await txn.rawUpdate(
          'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
          [deltaCents, nowIso, accountId],
        );
      } else {
        final sv = await txn.query('savings',
            columns: ['name', 'currency'], where: 'id = ?', whereArgs: [savingsId], limit: 1);
        await Ledger.post(
          txn,
          accountId: accountId,
          signedCents: -Money.toCents(newSignedAmount),
          kind: LedgerKind.epargneObjectif,
          refId: transactionId,
          currency: sv.isEmpty ? 'XOF' : (sv.first['currency'] as String? ?? 'XOF'),
          description: 'Épargne — ${sv.isEmpty ? '' : sv.first['name']}',
          date: DateTime.tryParse('${data['date']}'),
        );
      }
    });
  }

  /// Supprime un mouvement ET annule son effet sur les deux soldes.
  Future<void> deleteTransactionWithBalanceUpdate({
    required int transactionId,
    required int savingsId,
    required int accountId,
    required double signedAmount,
  }) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    final signedCents = Money.toCents(signedAmount);
    await db.transaction((txn) async {
      await txn.delete('savings_transactions', where: 'id = ?', whereArgs: [transactionId]);

      await txn.rawUpdate(
        'UPDATE savings SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [signedCents, nowIso, savingsId],
      );

      final n = await Ledger.unpost(txn,
          kinds: [LedgerKind.epargneObjectif, LedgerKind.epargne], refId: transactionId);
      if (n == 0) {
        await txn.rawUpdate(
          'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
          [signedCents, nowIso, accountId],
        );
      }
    });
  }
}
