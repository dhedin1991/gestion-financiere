import '../../../../core/database/app_database.dart';

class CategoryDao {
  final AppDatabase _appDatabase;
  CategoryDao(this._appDatabase);

  Future<List<Map<String, dynamic>>> findByType(String type) async {
    final db = await _appDatabase.database;
    return db.query('categories', where: 'type = ?', whereArgs: [type], orderBy: 'name ASC');
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _appDatabase.database;
    return db.insert('categories', data);
  }

  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
