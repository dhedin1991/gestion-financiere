import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../domain/entities/debt.dart';
import '../providers/debt_providers.dart';

class DebtsPage extends ConsumerWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('Dettes & Créances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(debtsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDebtForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle entrée'),
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur : $err')),
        data: (debts) {
          if (debts.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: debts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final debt = debts[index];
              return _DebtCard(
                debt: debt,
                onTap: () => _showDebtForm(context, ref, existing: debt),
                onPay: () => _showPaymentForm(context, ref, debt),
              );
            },
          );
        },
      ),
    );
  }

  void _showDebtForm(BuildContext context, WidgetRef ref, {Debt? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DebtFormSheet(existing: existing),
    );
  }

  void _showPaymentForm(BuildContext context, WidgetRef ref, Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PaymentFormSheet(debt: debt),
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
            Icon(Icons.handshake_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucune dette ni créance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoute une dette (tu dois de l\'argent) ou une créance (on te doit de l\'argent)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  final Debt debt;
  final VoidCallback onTap;
  final VoidCallback onPay;

  const _DebtCard({required this.debt, required this.onTap, required this.onPay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDette = debt.type == DebtType.dette;
    final color = debt.isSettled ? Colors.grey : (isDette ? Colors.red : Colors.green);
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: debt.currency, decimalDigits: 0);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(isDette ? Icons.arrow_upward : Icons.arrow_downward, color: color),
        ),
        title: Text(debt.personName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          debt.isSettled
              ? 'Soldée'
              : 'Reste ${fmt.format(debt.remainingAmount)} sur ${fmt.format(debt.totalAmount)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!debt.isSettled) TextButton(onPressed: onPay, child: const Text('Payer')),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'history') {
                  _showHistory(context);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'history',
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Historique des paiements'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PaymentHistorySheet(debt: debt),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: const Text('Cette action supprimera aussi l\'historique des paiements liés.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && debt.id != null) {
        try {
          await ref.read(debtActionsProvider).delete(debt.id!);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Entrée supprimée')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur : $e')),
            );
          }
        }
      }
    });
  }
}

class _PaymentHistorySheet extends ConsumerWidget {
  final Debt debt;

  const _PaymentHistorySheet({required this.debt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(debtPaymentsProvider(debt.id!));
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: debt.currency, decimalDigits: 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Historique des paiements — ${debt.personName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: paymentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Erreur : $err')),
                data: (payments) {
                  if (payments.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'Aucun paiement enregistré',
                    );
                  }
                  return ListView.separated(
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      return ListTile(
                        title: Text(fmt.format(payment.amount)),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(payment.paymentDate)}'
                          '${payment.note != null && payment.note!.isNotEmpty ? ' - ${payment.note}' : ''}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Supprimer ce paiement ?'),
                                content: const Text('Le montant restant dû sera recalculé automatiquement.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && payment.id != null) {
                              await ref.read(debtActionsProvider).deletePayment(
                                    payment.id!,
                                    debt.id!,
                                    accountId: debt.accountId,
                                  );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtFormSheet extends ConsumerStatefulWidget {
  final Debt? existing;
  const _DebtFormSheet({this.existing});

  @override
  ConsumerState<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<_DebtFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _personController;
  late final TextEditingController _descController;
  late final TextEditingController _amountController;
  DebtType _selectedType = DebtType.dette;
  String _selectedCurrency = 'XOF';
  int? _selectedAccountId;

  static const currencies = ['XOF', 'EUR', 'USD', 'NGN', 'GHS'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _personController = TextEditingController(text: e?.personName ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.totalAmount.toStringAsFixed(0) : '',
    );
    if (e != null) {
      _selectedType = e.type;
      _selectedCurrency = e.currency;
      _selectedAccountId = e.accountId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final accountsAsync = ref.watch(allAccountsIncludingArchivedProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Modifier' : 'Nouvelle dette / créance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            SegmentedButton<DebtType>(
              segments: const [
                ButtonSegment(value: DebtType.dette, label: Text('Je dois')),
                ButtonSegment(value: DebtType.creance, label: Text('On me doit')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (s) => setState(() => _selectedType = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _personController,
              decoration: const InputDecoration(labelText: 'Nom de la personne *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optionnel)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Montant total *'),
                    enabled: !isEditing,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Champ requis';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Nombre invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Devise'),
                    items: currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCurrency = v ?? _selectedCurrency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (accounts) {
                final selectable = accounts
                    .where((a) => !a.isArchived || a.id == _selectedAccountId)
                    .toList();
                return DropdownButtonFormField<int?>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Compte lié (optionnel)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Aucun')),
                    ...selectable.map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.isArchived ? '${a.name} (archivé)' : a.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Enregistrer' : 'Créer'),
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _confirmDelete(context),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Supprimer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final actions = ref.read(debtActionsProvider);
    final now = DateTime.now();

    try {
      if (widget.existing == null) {
        await actions.create(Debt(
          type: _selectedType,
          personName: _personController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          totalAmount: amount,
          currency: _selectedCurrency,
          accountId: _selectedAccountId,
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        await actions.update(widget.existing!.copyWith(
          type: _selectedType,
          personName: _personController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          currency: _selectedCurrency,
          accountId: _selectedAccountId,
        ));
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: const Text('Cette action supprimera aussi l\'historique des paiements.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirmed == true && widget.existing?.id != null) {
      try {
        await ref.read(debtActionsProvider).delete(widget.existing!.id!);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _PaymentFormSheet extends ConsumerStatefulWidget {
  final Debt debt;
  const _PaymentFormSheet({required this.debt});

  @override
  ConsumerState<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends ConsumerState<_PaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: widget.debt.currency, decimalDigits: 0);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enregistrer un paiement', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Reste à payer : ${fmt.format(widget.debt.remainingAmount)}'),
            const SizedBox(height: 8),
            if (widget.debt.accountId != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_alt, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.debt.type == DebtType.dette
                            ? 'Le solde du compte lié sera automatiquement diminué de ce montant.'
                            : 'Le solde du compte lié sera automatiquement augmenté de ce montant.',
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aucun compte lié à cette entrée : le paiement sera enregistré ici, mais aucun solde ne sera mis à jour. Modifie l\'entrée pour lier un compte.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant payé *'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ requis';
                final val = double.tryParse(v.replaceAll(',', '.'));
                if (val == null) return 'Nombre invalide';
                if (val <= 0) return 'Doit être supérieur à 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optionnel)'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('Enregistrer le paiement')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    try {
      await ref.read(debtActionsProvider).addPayment(
            DebtPayment(
              debtId: widget.debt.id!,
              amount: amount,
              paymentDate: DateTime.now(),
              note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
              createdAt: DateTime.now(),
            ),
            widget.debt,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
