import '../entities/patrimoine_item.dart';

/// Contrat que doit respecter toute implémentation de la gestion
/// des biens (Patrimoine). Les couches supérieures (providers, pages)
/// ne dépendent que de cette interface, jamais de l'implémentation
/// concrète ni du DAO directement.
abstract class PatrimoineRepository {
  Future<int> addItem(PatrimoineItem item);

  Future<int> updateItem(PatrimoineItem item);

  Future<int> deleteItem(int id);

  Future<PatrimoineItem?> getItemById(int id);

  Future<List<PatrimoineItem>> getAllItems();

  Future<List<PatrimoineItem>> getItemsByCategory(PatrimoineCategory category);

  Future<double> getTotalValue();
}
