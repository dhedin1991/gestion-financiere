import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';

/// Data Access Object : seule classe autorisée à écrire du SQL brut
/// pour les tables `debts` et `debt_payments`.
class DebtDao {
  final AppDatabase _appDatabase;

  DebtDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await _appDatabase.database;
    return db.query('debts', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> findById(int id) async {
    final db = await _appDatabase.database;
    final results = await db.query('debts', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isEmpty ? null : results.first;
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('debts', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.update('debts', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  /// Somme des paiements déjà effectués pour une dette donnée.
  Future<double> sumPaymentsForDebt(int debtId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM debt_payments WHERE debt_id = ?',
      [debtId],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> findPaymentsByDebt(int debtId) async {
    final db = await _appDatabase.database;
    return db.query(
      'debt_payments',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'payment_date DESC',
    );
  }

  Future<int> insertPayment(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('debt_payments', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> deletePayment(int id) async {
    final db = await _appDatabase.database;
    return db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> findPaymentById(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('debt_payments', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Enregistre un paiement ET répercute son effet sur le solde du compte lié,
  /// dans une seule transaction SQL atomique (même mécanisme que le module
  /// Épargne / Transactions). signedAmount est déjà orienté par l'appelant :
  /// négatif pour un remboursement de dette (l'argent sort du compte),
  /// positif pour un encaissement de créance (l'argent entre sur le compte).
  Future<int> insertPaymentWithBalanceUpdate({
    required Map<String, dynamic> data,
    required int accountId,
    required double signedAmount,
  }) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final id = await txn.insert('debt_payments', data);
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [signedAmount, nowIso, accountId],
      );
      return id;
    });
  }

  /// Supprime un paiement ET annule son effet sur le solde du compte lié.
  Future<void> deletePaymentWithBalanceUpdate({
    required int paymentId,
    required int accountId,
    required double signedAmount,
  }) async {
    final db = await _appDatabase.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('debt_payments', where: 'id = ?', whereArgs: [paymentId]);
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [signedAmount, nowIso, accountId],
      );
    });
  }
}
