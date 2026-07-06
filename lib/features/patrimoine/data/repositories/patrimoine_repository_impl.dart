import '../../domain/entities/patrimoine_item.dart';
import '../../domain/repositories/patrimoine_repository.dart';
import '../datasources/patrimoine_dao.dart';
import '../models/patrimoine_item_model.dart';

class PatrimoineRepositoryImpl implements PatrimoineRepository {
  final PatrimoineDao dao;

  PatrimoineRepositoryImpl(this.dao);

  @override
  Future<int> addItem(PatrimoineItem item) async {
    final model = PatrimoineItemModel.fromEntity(item);
    return dao.insert(model);
  }

  @override
  Future<int> updateItem(PatrimoineItem item) async {
    final model = PatrimoineItemModel.fromEntity(item);
    return dao.update(model);
  }

  @override
  Future<int> deleteItem(int id) async {
    return dao.delete(id);
  }

  @override
  Future<PatrimoineItem?> getItemById(int id) async {
    return dao.getById(id);
  }

  @override
  Future<List<PatrimoineItem>> getAllItems() async {
    return dao.getAll();
  }

  @override
  Future<List<PatrimoineItem>> getItemsByCategory(
    PatrimoineCategory category,
  ) async {
    return dao.getByCategory(category.name);
  }

  @override
  Future<double> getTotalValue() async {
    return dao.getTotalValue();
  }
}
