import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/entity_dao.dart';
import '../../domain/entities/business_entity.dart';

const _kCurrentEntityIdKey = 'current_entity_id';

final entityDaoProvider = Provider<EntityDao>((ref) {
  return EntityDao(ref.watch(appDatabaseProvider));
});

final entitiesListProvider = FutureProvider.autoDispose<List<BusinessEntity>>((ref) async {
  return ref.watch(entityDaoProvider).findAll();
});

/// Id de l'entité actuellement sélectionnée. Persisté pour retrouver la
/// même entité à la prochaine ouverture de l'app. `null` tant que le
/// premier chargement n'a pas encore déterminé la valeur.
class CurrentEntityController extends StateNotifier<int?> {
  final Ref _ref;
  CurrentEntityController(this._ref) : super(null) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_kCurrentEntityIdKey);
    final entities = await _ref.read(entitiesListProvider.future);
    if (entities.isEmpty) return;

    final match = entities.where((e) => e.id == savedId);
    state = match.isNotEmpty ? match.first.id : entities.first.id;
  }

  Future<void> select(int entityId) async {
    state = entityId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCurrentEntityIdKey, entityId);
  }
}

final currentEntityIdProvider = StateNotifierProvider<CurrentEntityController, int?>((ref) {
  return CurrentEntityController(ref);
});
