import '../../../core/database/app_database.dart';
import '../domain/entities/business_entity.dart';

class EntityDao {
  final AppDatabase _appDatabase;
  EntityDao(this._appDatabase);

  Future<List<BusinessEntity>> findAll() async {
    final db = await _appDatabase.database;
    final rows = await db.query('business_entities', orderBy: 'id ASC');
    return rows
        .map((m) => BusinessEntity(
              id: m['id'] as int,
              name: m['name'] as String,
              type: (m['type'] as String) == 'professionnel'
                  ? BusinessEntityType.professionnel
                  : BusinessEntityType.personnel,
              createdAt: DateTime.parse(m['created_at'] as String),
            ))
        .toList();
  }

  Future<int> insert(String name, BusinessEntityType type) async {
    final db = await _appDatabase.database;
    return db.insert('business_entities', {
      'name': name,
      'type': type.name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
