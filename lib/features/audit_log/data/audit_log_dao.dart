import '../../../core/database/app_database.dart';

/// Accès à la table history_log : trace des créations/modifications/
/// suppressions sur les entités principales de l'app.
class AuditLogDao {
  final AppDatabase _appDatabase;
  AuditLogDao(this._appDatabase);

  Future<void> log({
    required String entityType,
    required int entityId,
    required String action,
    String? oldValue,
    String? newValue,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now();
    await db.insert('history_log', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'old_value': oldValue,
      'new_value': newValue,
      'date': now.toIso8601String().split('T').first,
      'time': now.toIso8601String().split('T').last,
    });
  }

  Future<List<Map<String, dynamic>>> recent({int limit = 200}) async {
    final db = await _appDatabase.database;
    return db.query('history_log', orderBy: 'id DESC', limit: limit);
  }
}
