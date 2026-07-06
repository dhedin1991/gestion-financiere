import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/credit.dart';
import '../../domain/entities/credit_installment.dart';
import '../providers/credit_providers.dart';
import '../widgets/credit_form_sheet.dart';

class CreditDetailPage extends ConsumerWidget {
  final Credit credit;

  const CreditDetailPage({super.key, required this.credit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installmentsAsync = ref.watch(creditInstallmentsProvider(credit.id!));
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: credit.currency, decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(credit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => CreditFormSheet(existing: credit),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capital emprunté : ${fmt.format(credit.principalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('Taux d\'intérêt : ${credit.interestRate}%'),
                Text('Mensualité : ${fmt.format(credit.monthlyPayment)}'),
                Text('Durée : ${credit.durationMonths} mois'),
                Text(
                  'Début : ${DateFormat('dd/MM/yyyy').format(credit.startDate)}',
                ),
                if (credit.notes != null && credit.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(credit.notes!, style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Échéancier',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: installmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (installments) {
                if (installments.isEmpty) {
                  return const Center(child: Text('Aucune échéance'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: installments.length,
                  itemBuilder: (context, index) {
                    final installment = installments[index];
                    return _InstallmentTile(installment: installment, index: index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce crédit ?'),
        content: Text(
          'Voulez-vous vraiment supprimer "${credit.name}" ? Toutes ses échéances seront également supprimées. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && credit.id != null) {
        try {
          await ref.read(creditActionsProvider).delete(credit.id!);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Crédit supprimé')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur lors de la suppression : $e')),
            );
          }
        }
      }
    });
  }
}

class _InstallmentTile extends ConsumerWidget {
  final CreditInstallment installment;
  final int index;

  const _InstallmentTile({required this.installment, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);
    final isPaid = installment.status == InstallmentStatus.payee;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isPaid,
        onChanged: (checked) async {
          try {
            final actions = ref.read(creditActionsProvider);
            if (checked == true) {
              await actions.markInstallmentPaid(installment);
            } else {
              await actions.markInstallmentUnpaid(installment);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur : $e')),
              );
            }
          }
        },
        title: Text('Échéance ${index + 1} — ${fmt.format(installment.amount)}'),
        subtitle: Text(
          isPaid && installment.paymentDate != null
              ? 'Payée le ${DateFormat('dd/MM/yyyy').format(installment.paymentDate!)}'
              : 'Prévue le ${DateFormat('dd/MM/yyyy').format(installment.dueDate)}',
        ),
        secondary: Icon(
          isPaid ? Icons.check_circle : Icons.schedule,
          color: isPaid ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
