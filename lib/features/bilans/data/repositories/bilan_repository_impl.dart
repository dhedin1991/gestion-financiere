import '../../domain/entities/net_worth_snapshot.dart';
import '../../domain/repositories/bilan_repository.dart';
import '../datasources/bilan_dao.dart';

class BilanRepositoryImpl implements BilanRepository {
  final BilanDao dao;

  BilanRepositoryImpl(this.dao);

  @override
  Future<NetWorthSnapshot> refreshTodaySnapshot({int? entityId}) async {
    final snapshot = await dao.computeCurrentSnapshot(entityId: entityId);
    await dao.upsertTodaySnapshot(snapshot, entityId: entityId);
    return snapshot;
  }

  @override
  Future<List<NetWorthSnapshot>> getNetWorthHistory({int? entityId}) async {
    return dao.getAllSnapshots(entityId: entityId);
  }

  @override
  Future<List<Map<String, dynamic>>> getTransactionsBetween(DateTime start, DateTime end,
      {int? entityId}) async {
    return dao.getTransactionsBetween(start, end, entityId: entityId);
  }
}
