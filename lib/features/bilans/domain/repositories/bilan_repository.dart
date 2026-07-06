import '../entities/net_worth_snapshot.dart';

abstract class BilanRepository {
  /// Calcule et enregistre (ou met à jour) la photo du patrimoine net du jour.
  Future<NetWorthSnapshot> refreshTodaySnapshot();

  /// Historique complet des photos du patrimoine net, du plus ancien au plus récent.
  Future<List<NetWorthSnapshot>> getNetWorthHistory();

  /// Transactions brutes (type, montant, date) entre deux dates.
  Future<List<Map<String, dynamic>>> getTransactionsBetween(DateTime start, DateTime end);
}
