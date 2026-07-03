import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/datasources/category_dao.dart';
import '../../domain/entities/category.dart';

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  return CategoryDao(ref.watch(appDatabaseProvider));
});

/// Catégories de revenus, utilisées dans le formulaire d'ajout de transaction.
final incomeCategoriesProvider = FutureProvider.autoDispose<List<AppCategory>>((ref) async {
  final dao = ref.watch(categoryDaoProvider);
  final rows = await dao.findByType('revenu');
  return rows.map(_mapRow).toList();
});

/// Catégories de dépenses.
final expenseCategoriesProvider = FutureProvider.autoDispose<List<AppCategory>>((ref) async {
  final dao = ref.watch(categoryDaoProvider);
  final rows = await dao.findByType('depense');
  return rows.map(_mapRow).toList();
});

final categoryActionsProvider = Provider<CategoryActions>((ref) {
  return CategoryActions(ref, ref.watch(categoryDaoProvider));
});

class CategoryActions {
  final Ref _ref;
  final CategoryDao _dao;
  CategoryActions(this._ref, this._dao);

  Future<void> create(String name, CategoryType type) async {
    await _dao.insert({'name': name, 'type': type.name == 'revenu' ? 'revenu' : 'depense'});
    _ref.invalidate(incomeCategoriesProvider);
    _ref.invalidate(expenseCategoriesProvider);
  }

  Future<void> delete(int id) async {
    await _dao.delete(id);
    _ref.invalidate(incomeCategoriesProvider);
    _ref.invalidate(expenseCategoriesProvider);
  }
}

AppCategory _mapRow(Map<String, dynamic> row) {
  return AppCategory(
    id: row['id'] as int,
    name: row['name'] as String,
    type: AppCategory.typeFromString(row['type'] as String),
    parentId: row['parent_id'] as int?,
    color: row['color'] as int?,
    icon: row['icon'] as String?,
    isDefault: (row['is_default'] as int? ?? 0) == 1,
  );
}
