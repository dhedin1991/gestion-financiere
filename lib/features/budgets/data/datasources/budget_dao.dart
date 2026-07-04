import '../../../../core/database/app_database.dart';
import '../../domain/entities/budget.dart';
import '../models/budget_model.dart';

/// Accès direct à la base SQLite pour tout ce qui concerne les budgets.
class BudgetDao {
  final AppDatabase _appDatabase;

  BudgetDao(this._appDatabase);

  Future<int> create(BudgetModel budget) async {
    final db = await _appDatabase.database;
    return db.insert('budgets', budget.toMap());
  }

  Future<int> update(BudgetModel budget) async {
    final db = await _appDatabase.database;
    return db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BudgetModel>> getAll() async {
    final db = await _appDatabase.database;
    final rows = await db.query('budgets', orderBy: 'start_date DESC');
    return rows.map((row) => BudgetModel.fromMap(row)).toList();
  }

  Future<BudgetModel?> getById(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('budgets', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return BudgetModel.fromMap(rows.first);
  }

  /// Calcule la date de fin d'une période de budget à partir de sa date
  /// de début et de son type de période.
  DateTime periodEndDate(DateTime startDate, BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.hebdomadaire:
        return startDate.add(const Duration(days: 7));
      case BudgetPeriod.mensuel:
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      case BudgetPeriod.annuel:
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
    }
  }

  /// Calcule le montant déjà dépensé pour un budget donné, en se basant
  /// sur les transactions de type 'depense' dans la période concernée.
  /// - Si le budget est global (categoryId null) : toutes les dépenses.
  /// - Si le budget cible une catégorie : uniquement ses dépenses.
  Future<double> getSpentAmount(BudgetModel budget) async {
    final db = await _appDatabase.database;
    final endDate = periodEndDate(budget.startDate, budget.period);

    final whereClauses = <String>[
      "type = 'depense'",
      'transaction_date >= ?',
      'transaction_date < ?',
    ];
    final whereArgs = <Object?>[
      budget.startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    if (budget.categoryId != null) {
      whereClauses.add('category_id = ?');
      whereArgs.add(budget.categoryId);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE ${whereClauses.join(' AND ')}',
      whereArgs,
    );

    final total = result.first['total'];
    if (total == null) return 0.0;
    return (total as num).toDouble();
  }
}
