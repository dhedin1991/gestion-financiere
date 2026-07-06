import '../../../../core/database/app_database.dart';
import '../models/net_worth_snapshot_model.dart';

/// Requêtes d'agrégation pour le module Bilans : calcul du patrimoine net
/// (comptes + épargne + biens + créances - dettes - crédits restants) et
/// données brutes pour les graphiques Revenus/Dépenses.
class BilanDao {
  final AppDatabase appDatabase;

  BilanDao(this.appDatabase);

  // ---------------- PATRIMOINE NET ----------------

  Future<double> _getTotalAccountsBalance() async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('SELECT SUM(current_balance) as total FROM accounts');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<double> _getTotalSavingsBalance() async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('SELECT SUM(current_balance) as total FROM savings');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<double> _getTotalPatrimoineValue() async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('SELECT SUM(estimated_value) as total FROM patrimoine_items');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  /// Somme des créances restantes (argent qu'on te doit).
  Future<double> _getTotalReceivables() async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('''
      SELECT SUM(d.total_amount - COALESCE(p.paid, 0)) as total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) as paid FROM debt_payments GROUP BY debt_id
      ) p ON p.debt_id = d.id
      WHERE d.type = 'creance'
    ''');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  /// Somme des dettes restantes (argent que tu dois).
  Future<double> _getTotalDebts() async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('''
      SELECT SUM(d.total_amount - COALESCE(p.paid, 0)) as total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) as paid FROM debt_payments GROUP BY debt_id
      ) p ON p.debt_id = d.id
      WHERE d.type = 'dette'
    ''');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  /// Somme des échéances de crédit pas encore payées (capital restant dû approximatif).
  Future<double> _getTotalCreditsRemaining() async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM credit_installments WHERE status != 'payee'
    ''');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  /// Calcule le patrimoine net actuel (sans le sauvegarder).
  Future<NetWorthSnapshotModel> computeCurrentSnapshot() async {
    final totalAccounts = await _getTotalAccountsBalance();
    final totalSavings = await _getTotalSavingsBalance();
    final totalPatrimoine = await _getTotalPatrimoineValue();
    final totalReceivables = await _getTotalReceivables();
    final totalDebts = await _getTotalDebts();
    final totalCreditsRemaining = await _getTotalCreditsRemaining();

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

  /// Enregistre une photo du jour, seulement si aucune photo n'existe déjà
  /// pour aujourd'hui (grâce à l'index unique sur snapshot_date).
  Future<void> saveSnapshotIfNeeded(NetWorthSnapshotModel snapshot) async {
    final db = await appDatabase.database;
    await db.insert(
      'net_worth_snapshots',
      snapshot.toMap(),
      conflictAlgorithm: null, // on gère le conflit manuellement ci-dessous
    );
  }

  /// Enregistre ou met à jour la photo du jour (si elle existe déjà pour
  /// aujourd'hui, elle est remplacée avec les valeurs à jour).
  Future<void> upsertTodaySnapshot(NetWorthSnapshotModel snapshot) async {
    final db = await appDatabase.database;
    final dateKey = snapshot.snapshotDate.toIso8601String().split('T').first;

    final existing = await db.query(
      'net_worth_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: [dateKey],
    );

    if (existing.isEmpty) {
      await db.insert('net_worth_snapshots', snapshot.toMap());
    } else {
      await db.update(
        'net_worth_snapshots',
        snapshot.toMap(),
        where: 'snapshot_date = ?',
        whereArgs: [dateKey],
      );
    }
  }

  Future<List<NetWorthSnapshotModel>> getAllSnapshots() async {
    final db = await appDatabase.database;
    final results = await db.query('net_worth_snapshots', orderBy: 'snapshot_date ASC');
    return results.map((map) => NetWorthSnapshotModel.fromMap(map)).toList();
  }

  // ---------------- REVENUS / DÉPENSES ----------------

  /// Retourne les transactions brutes (type, montant, date) entre deux dates,
  /// pour que la couche présentation les regroupe par période au choix.
  Future<List<Map<String, dynamic>>> getTransactionsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await appDatabase.database;
    return db.query(
      'transactions',
      columns: ['type', 'amount', 'transaction_date'],
      where: 'transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'transaction_date ASC',
    );
  }
}
