import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money.dart';

/// DAO Transactions.
///
/// Point important : chaque écriture (création/modification/suppression)
/// doit AUSSI mettre à jour `accounts.current_balance` pour rester cohérent.
/// On utilise `db.transaction()` (transaction SQL, à ne pas confondre avec
/// l'entité métier "Transaction") pour garantir qu'aucune des deux écritures
/// ne se fasse sans l'autre (atomicité).
class TransactionDao {
  final AppDatabase _appDatabase;
  TransactionDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> find({
    int? accountId,
    int? categoryId,
    String? type,
    String? fromIso,
    String? toIso,
    String? searchText,
    int limit = 100,
  }) async {
    final db = await _appDatabase.database;

    final conditions = <String>[];
    final args = <Object?>[];

    if (accountId != null) {
      conditions.add('account_id = ?');
      args.add(accountId);
    }
    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    if (fromIso != null) {
      conditions.add('transaction_date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      conditions.add('transaction_date <= ?');
      args.add(toIso);
    }
    if (searchText != null && searchText.trim().isNotEmpty) {
      conditions.add('description LIKE ?');
      args.add('%${searchText.trim()}%');
    }

    return db.query(
      'transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : args,
      orderBy: 'transaction_date DESC, id DESC',
      limit: limit,
    );
  }

  Future<double> sumByType(String type, {String? fromIso, String? toIso}) async {
    final db = await _appDatabase.database;
    final conditions = <String>['type = ?'];
    final args = <Object?>[type];
    if (fromIso != null) {
      conditions.add('transaction_date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      conditions.add('transaction_date <= ?');
      args.add(toIso);
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE ${conditions.join(' AND ')}',
      args,
    );
    final totalCents = (result.first['total'] as num).toInt();
    return Money.fromCents(totalCents);
  }

  /// Crée une transaction ET applique son effet sur le solde du compte,
  /// dans une seule transaction SQL atomique.
  Future<int> insertWithBalanceUpdate(Map<String, dynamic> data, double signedAmount) async {
    final db = await _appDatabase.database;
    final safeData = Map<String, dynamic>.from(data);
    if (safeData['amount'] != null) {
      // Filet de sécurité : garantit un entier même si un appelant a
      // fourni un montant encore en double au lieu de passer par
      // TransactionModel.toMap() (qui convertit déjà en centimes).
      safeData['amount'] = (safeData['amount'] as num).round();
    }
    final signedCents = Money.toCents(signedAmount);
    return db.transaction((txn) async {
      final id = await txn.insert('transactions', safeData);
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [signedCents, DateTime.now().toIso8601String(), data['account_id']],
      );
      return id;
    });
  }

  /// Supprime une transaction ET annule son effet sur le solde du compte.
  Future<void> deleteWithBalanceUpdate(int id, int accountId, double signedAmount) async {
    final db = await _appDatabase.database;
    final signedCents = Money.toCents(signedAmount);
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [signedCents, DateTime.now().toIso8601String(), accountId],
      );
    });
  }

  /// Modifie une transaction : annule l'ancien effet, applique le nouveau.
  /// (Les deux comptes concernés peuvent être différents si l'utilisateur
  /// change le compte de la transaction.)
  Future<void> updateWithBalanceUpdate({
    required int id,
    required Map<String, dynamic> newData,
    required int oldAccountId,
    required double oldSignedAmount,
    required int newAccountId,
    required double newSignedAmount,
  }) async {
    final db = await _appDatabase.database;
    final safeNewData = Map<String, dynamic>.from(newData);
    if (safeNewData['amount'] != null) {
      safeNewData['amount'] = (safeNewData['amount'] as num).round();
    }
    final oldSignedCents = Money.toCents(oldSignedAmount);
    final newSignedCents = Money.toCents(newSignedAmount);
    await db.transaction((txn) async {
      await txn.update('transactions', safeNewData, where: 'id = ?', whereArgs: [id]);

      // Annule l'ancien effet sur l'ancien compte.
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [oldSignedCents, DateTime.now().toIso8601String(), oldAccountId],
      );
      // Applique le nouvel effet sur le nouveau compte.
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
        [newSignedCents, DateTime.now().toIso8601String(), newAccountId],
      );
    });
  }

  Future<Map<String, dynamic>?> findById(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }
}
