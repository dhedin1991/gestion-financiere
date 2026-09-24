import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../data/exchange_rate_dao.dart';

final exchangeRateDaoProvider = Provider<ExchangeRateDao>((ref) {
  return ExchangeRateDao(ref.watch(appDatabaseProvider));
});

/// `{ 'EUR': 655.0, ... }` — taux saisis manuellement (1 devise = X XOF).
final exchangeRatesProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  return ref.watch(exchangeRateDaoProvider).getAll();
});

/// Devises utilisées par au moins un compte actif, autres que XOF — ce sont
/// celles pour lesquelles un taux est nécessaire pour le total converti.
final currenciesNeedingRateProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final accounts = await ref.watch(allAccountsIncludingArchivedProvider.future);
  final currencies = accounts.map((a) => a.currency).where((c) => c != 'XOF').toSet().toList()..sort();
  return currencies;
});

/// Solde global TOUTES devises confondues, converti en XOF avec les taux
/// saisis manuellement. `null` si au moins une devise utilisée n'a pas de
/// taux renseigné (mieux vaut ne rien afficher qu'un total faux ou
/// partiel) — voir [missingRatesProvider] pour savoir lesquelles manquent.
final convertedGlobalBalanceProvider = FutureProvider.autoDispose<double?>((ref) async {
  final accounts = await ref.watch(allAccountsIncludingArchivedProvider.future);
  final active = accounts.where((a) => !a.isArchived);
  final rates = await ref.watch(exchangeRatesProvider.future);

  double total = 0;
  for (final a in active) {
    if (a.currency == 'XOF') {
      total += a.currentBalance;
    } else {
      final rate = rates[a.currency];
      if (rate == null) return null; // taux manquant : pas d'estimation partielle trompeuse
      total += a.currentBalance * rate;
    }
  }
  return total;
});

/// Devises utilisées mais sans taux renseigné (pour guider l'utilisateur
/// vers l'écran des taux plutôt que d'afficher un total incomplet en silence).
final missingRatesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final needed = await ref.watch(currenciesNeedingRateProvider.future);
  final rates = await ref.watch(exchangeRatesProvider.future);
  return needed.where((c) => !rates.containsKey(c)).toList();
});
