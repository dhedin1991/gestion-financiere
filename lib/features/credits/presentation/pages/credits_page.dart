import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_menu_button.dart';
import '../../domain/entities/credit.dart';
import '../providers/credit_providers.dart';
import '../widgets/credit_form_sheet.dart';
import 'credit_detail_page.dart';

class CreditsPage extends ConsumerWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('Crédits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(creditsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreditForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau crédit'),
      ),
      body: creditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (credits) {
          if (credits.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: credits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _CreditCard(credit: credits[index]),
          );
        },
      ),
    );
  }

  void _showCreditForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreditFormSheet(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucun crédit pour le moment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoute un crédit professionnel, son échéancier sera généré automatiquement',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditCard extends ConsumerWidget {
  final Credit credit;

  const _CreditCard({required this.credit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: credit.currency, decimalDigits: 0);
    final paidCountAsync = ref.watch(creditPaidCountProvider(credit.id!));

    final isSolde = credit.status == CreditStatus.solde;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CreditDetailPage(credit: credit)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      credit.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  Chip(
                    label: Text(isSolde ? 'Soldé' : 'Actif'),
                    backgroundColor: isSolde
                        ? Colors.green.withOpacity(0.15)
                        : Colors.blue.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSolde ? Colors.green.shade800 : Colors.blue.shade800,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (credit.contractNumber != null && credit.contractNumber!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Contrat n° ${credit.contractNumber}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Capital : ${fmt.format(credit.principalAmount)}  •  Mensualité : ${fmt.format(credit.monthlyPayment)}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              paidCountAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (paidCount) {
                  final ratio = credit.durationMonths == 0
                      ? 0.0
                      : paidCount / credit.durationMonths;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$paidCount / ${credit.durationMonths} échéances payées',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
