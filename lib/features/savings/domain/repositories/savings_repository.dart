import '../entities/savings.dart';

/// Contrat du repository Épargne. La couche présentation (providers, pages)
/// ne dépend que de cette interface, jamais de l'implémentation concrète.
abstract class SavingsRepository {
  Future<List<Savings>> getAllSavings();

  Future<Savings?> getSavingsById(int id);

  Future<Savings> createSavings(Savings savings);

  Future<void> updateSavings(Savings savings);

  Future<void> deleteSavings(int id);

  Future<List<SavingsTransaction>> getTransactionsForSavings(int savingsId);

  /// Ajoute un versement ou un retrait : met à jour le solde de l'épargne
  /// ET le solde du compte lié, de façon atomique.
  Future<void> addSavingsTransaction(SavingsTransaction transaction);

  /// Modifie un mouvement existant (montant, date, note, type) en ajustant
  /// correctement les soldes de l'épargne et du compte lié.
  Future<void> updateSavingsTransaction(SavingsTransaction transaction);

  Future<void> deleteSavingsTransaction(int transactionId, int savingsId);
}
