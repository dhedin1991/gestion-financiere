import '../../domain/entities/net_worth_snapshot.dart';
import '../../domain/repositories/bilan_repository.dart';
import '../datasources/bilan_dao.dart';

class BilanRepositoryImpl implements BilanRepository {
  final BilanDao dao;

  BilanRepositoryImpl(this.dao);

  @override
  Future<NetWorthSnapshot> refreshTodaySnapshot() async {
    final snapshot = await dao.computeCurrentSnapshot();
    await dao.upsertTodaySnapshot(snapshot);
    return snapshot;
  }

  @override
  Future<List<NetWorthSnapshot>> getNetWorthHistory() async {
    return dao.getAllSnapshots();
  }

  @override
  Future<List<Map<String, dynamic>>> getTransactionsBetween(DateTime start, DateTime end) async {
    return dao.getTransactionsBetween(start, end);
  }
}
