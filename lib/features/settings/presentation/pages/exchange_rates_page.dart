import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/utils/app_error_message.dart';
import '../providers/exchange_rate_providers.dart';

/// Taux de change saisis à la main (1 devise = X XOF), utilisés uniquement
/// pour calculer une estimation du solde global toutes devises confondues
/// sur le Tableau de bord. L'app restant 100% hors ligne, aucun taux n'est
/// récupéré automatiquement : c'est à l'utilisateur de les tenir à jour.
class ExchangeRatesPage extends ConsumerStatefulWidget {
  const ExchangeRatesPage({super.key});

  @override
  ConsumerState<ExchangeRatesPage> createState() => _ExchangeRatesPageState();
}

class _ExchangeRatesPageState extends ConsumerState<ExchangeRatesPage> {
  Future<void> _editRate(String currency, double? currentRate) async {
    final controller = TextEditingController(text: currentRate?.toStringAsFixed(2) ?? '');
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('1 $currency = ? XOF'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Taux en XOF'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) return;
    try {
      await ref.read(exchangeRateDaoProvider).setRate(currency, value);
      ref.invalidate(exchangeRatesProvider);
      ref.invalidate(missingRatesProvider);
      ref.invalidate(convertedGlobalBalanceProvider);
    } catch (e) {
      if (mounted) AppErrorMessage.showSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(currenciesNeedingRateProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Taux de change'),
        actions: const [AppMenuButton()],
      ),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppErrorMessage.friendly(e))),
        data: (currencies) {
          if (currencies.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tous tes comptes sont en XOF : aucun taux n\\'est nécessaire.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final rates = ratesAsync.valueOrNull ?? const {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Saisis manuellement combien vaut 1 unité de chaque devise en XOF. '
                'Ces taux servent uniquement à estimer ton solde global toutes devises '
                'confondues sur le Tableau de bord — ils ne sont jamais récupérés '
                'automatiquement en ligne (l\\'app reste 100% hors ligne) et doivent être '
                'mis à jour à la main quand ils changent.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              for (final currency in currencies)
                Card(
                  child: ListTile(
                    title: Text(currency),
                    subtitle: Text(
                      rates.containsKey(currency)
                          ? '1 $currency = ${rates[currency]!.toStringAsFixed(2)} XOF'
                          : 'Taux non renseigné',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editRate(currency, rates[currency]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
