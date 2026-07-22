import '../../domain/entities/recurring_transaction.dart';
import '../../domain/repositories/recurring_transaction_repository.dart';
import '../datasources/recurring_transaction_dao.dart';
import '../models/recurring_transaction_model.dart';

class RecurringTransactionRepositoryImpl implements RecurringTransactionRepository {
  final RecurringTransactionDao _dao;
  RecurringTransactionRepositoryImpl(this._dao);

  @override
  Future<List<RecurringTransaction>> getAll() async {
    final rows = await _dao.findAll();
    return rows.map(RecurringTransactionModel.fromMap).toList();
  }

  @override
  Future<List<RecurringTransaction>> getDue() async {
    final todayIso = DateTime.now().toIso8601String();
    final rows = await _dao.findDue(todayIso: todayIso);
    return rows.map(RecurringTransactionModel.fromMap).toList();
  }

  @override
  Future<int> create(RecurringTransaction r) {
    return _dao.insert(RecurringTransactionModel.toMap(r));
  }

  @override
  Future<void> update(RecurringTransaction r) {
    if (r.id == null) throw ArgumentError('id requis pour la mise à jour');
    return _dao.update(r.id!, RecurringTransactionModel.toMap(r));
  }

  @override
  Future<void> delete(int id) {
    return _dao.delete(id);
  }
}
