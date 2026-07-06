import 'package:sqflite/sqflite.dart';

import '../models/patrimoine_item_model.dart';

/// Accès direct à la table `patrimoine_items` de la base SQLite.
/// Contient uniquement des requêtes SQL brutes — aucune logique métier ici.
class PatrimoineDao {
  final Database db;

  PatrimoineDao(this.db);

  static const String _table = 'patrimoine_items';

  Future<int> insert(PatrimoineItemModel item) async {
    return db.insert(_table, item.toMap());
  }

  Future<int> update(PatrimoineItemModel item) async {
    if (item.id == null) {
      throw ArgumentError('Impossible de mettre à jour un bien sans id');
    }
    return db.update(
      _table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    return db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<PatrimoineItemModel?> getById(int id) async {
    final results = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return PatrimoineItemModel.fromMap(results.first);
  }

  Future<List<PatrimoineItemModel>> getAll() async {
    final results = await db.query(_table, orderBy: 'name ASC');
    return results.map((map) => PatrimoineItemModel.fromMap(map)).toList();
  }

  Future<List<PatrimoineItemModel>> getByCategory(String category) async {
    final results = await db.query(
      _table,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return results.map((map) => PatrimoineItemModel.fromMap(map)).toList();
  }

  /// Calcule la somme totale des valeurs estimées de tous les biens.
  Future<double> getTotalValue() async {
    final result = await db.rawQuery(
      'SELECT SUM(estimated_value) as total FROM $_table',
    );
    final total = result.first['total'];
    if (total == null) return 0.0;
    return (total as num).toDouble();
  }
}
