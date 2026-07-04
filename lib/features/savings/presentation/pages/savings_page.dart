import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../domain/entities/savings.dart';
import '../providers/savings_providers.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(savingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Épargne'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(savingsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSavingsForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle épargne'),
      ),
      body: savingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (savingsList) {
          if (savingsList.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: savingsList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final savings = savingsList[index];
              return _SavingsCard(savings: savings);
            },
          );
        },
      ),
    );
  }

  void _showSavingsForm(BuildContext context, WidgetRef ref, {Savings? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SavingsFormSheet(existing: existing),
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
            Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucune épargne pour le moment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Crée une épargne, avec ou sans objectif, reliée à un de tes comptes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsCard extends ConsumerWidget {
  final Savings savings;

  const _SavingsCard({required this.savings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: savings.currency, decimalDigits: 0);

    String accountName = '...';
    final accounts = accountsAsync.valueOrNull ?? <Account>[];
    final match = accounts.where((a) => a.id == savings.accountId).toList();
    if (match.isNotEmpty) accountName = match.first.name;

    Color gaugeColor(double ratio) {
      if (ratio >= 1.0) return Colors.green;
      if (ratio >= 0.5) return Colors.orange;
      return Colors.blueGrey;
    }

    return Card(
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _SavingsFormSheet(existing: savings),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      savings.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  Chip(
                    label: Text(accountName),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (savings.hasTarget) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: savings.progress,
                    minHeight: 10,
                    backgroundColor: gaugeColor(savings.progress!).withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(gaugeColor(savings.progress!)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${fmt.format(savings.currentBalance)} sur ${fmt.format(savings.targetAmount)}'
                  '${savings.targetDate != null ? ' — avant le ${DateFormat('dd/MM/yyyy').format(savings.targetDate!)}' : ''}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ] else ...[
                Text(
                  'Solde : ${fmt.format(savings.currentBalance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showMovementDialog(
                        context,
                        ref,
                        savings,
                        SavingsTransactionType.versement,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Verser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showMovementDialog(
                        context,
                        ref,
                        savings,
                        SavingsTransactionType.retrait,
                      ),
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text('Retirer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SavingsHistoryPage(savings: savings),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Historique'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMovementDialog(
    BuildContext context,
    WidgetRef ref,
    Savings savings,
    SavingsTransactionType type,
  ) {
    showDialog(
      context: context,
      builder: (_) => _MovementDialog(savings: savings, type: type),
    );
  }
}

class _MovementDialog extends ConsumerStatefulWidget {
  final Savings savings;
  final SavingsTransactionType type;

  const _MovementDialog({required this.savings, required this.type});

  @override
  ConsumerState<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends ConsumerState<_MovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isVersement = widget.type == SavingsTransactionType.versement;

    return AlertDialog(
      title: Text(isVersement ? 'Verser sur "${widget.savings.name}"' : 'Retirer de "${widget.savings.name}"'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant *'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ requis';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Montant invalide';
                if (!isVersement && parsed > widget.savings.currentBalance) {
                  return 'Solde insuffisant dans cette épargne';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optionnel)'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Valider')),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    try {
      await ref.read(savingsActionsProvider).addTransaction(
            SavingsTransaction(
              savingsId: widget.savings.id!,
              type: widget.type,
              amount: amount,
              date: _selectedDate,
              note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
              createdAt: DateTime.now(),
            ),
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

class SavingsHistoryPage extends ConsumerWidget {
  final Savings savings;
  const SavingsHistoryPage({super.key, required this.savings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(savingsTransactionsProvider(savings.id!));
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: savings.currency, decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: Text('Historique — ${savings.name}')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('Aucun mouvement enregistré'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = transactions[index];
              final isVersement = t.type == SavingsTransactionType.versement;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isVersement ? Colors.green : Colors.red).withOpacity(0.15),
                  child: Icon(
                    isVersement ? Icons.add : Icons.remove,
                    color: isVersement ? Colors.green : Colors.red,
                  ),
                ),
                title: Text('${isVersement ? '+' : '-'}${fmt.format(t.amount)}'),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy').format(t.date)}'
                  '${t.note != null && t.note!.isNotEmpty ? ' — ${t.note}' : ''}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Supprimer ce mouvement ?'),
                        content: const Text('Le solde de l\'épargne et du compte lié seront ajustés.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(savingsActionsProvider).deleteTransaction(t.id!, savings.id!);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavingsFormSheet extends ConsumerStatefulWidget {
  final Savings? existing;
  const _SavingsFormSheet({this.existing});

  @override
  ConsumerState<_SavingsFormSheet> createState() => _SavingsFormSheetState();
}

class _SavingsFormSheetState extends ConsumerState<_SavingsFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  int? _selectedAccountId;
  DateTime? _selectedTargetDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _targetAmountController = TextEditingController(
      text: e?.targetAmount != null ? e!.targetAmount!.toStringAsFixed(0) : '',
    );
    _selectedAccountId = e?.accountId;
    _selectedTargetDate = e?.targetDate;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final accountsAsync = ref.watch(accountsListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Modifier l\'épargne' : 'Nouvelle épargne',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur comptes : $e'),
                data: (accounts) => DropdownButtonFormField<int>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Compte lié *'),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                  validator: (v) => v == null ? 'Choisis un compte' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant cible (optionnel)',
                  helperText: 'Laisse vide pour une épargne libre, sans objectif',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date cible (optionnel)'),
                subtitle: Text(
                  _selectedTargetDate != null
                      ? DateFormat('dd/MM/yyyy').format(_selectedTargetDate!)
                      : 'Aucune',
                ),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedTargetDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _selectedTargetDate = picked);
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? 'Enregistrer' : 'Créer l\'épargne'),
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
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final targetText = _targetAmountController.text.trim();
    final targetAmount = targetText.isEmpty ? null : double.tryParse(targetText.replaceAll(',', '.'));

    final actions = ref.read(savingsActionsProvider);
    final now = DateTime.now();

    try {
      if (widget.existing == null) {
        await actions.create(Savings(
          name: _nameController.text.trim(),
          accountId: _selectedAccountId!,
          targetAmount: targetAmount,
          targetDate: _selectedTargetDate,
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        await actions.update(widget.existing!.copyWith(
          name: _nameController.text.trim(),
          accountId: _selectedAccountId!,
          targetAmount: targetAmount,
          targetDate: _selectedTargetDate,
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
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette épargne ?'),
        content: const Text('Cette action est définitive. L\'historique des mouvements sera aussi supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirmed == true && widget.existing?.id != null) {
      try {
        await ref.read(savingsActionsProvider).delete(widget.existing!.id!);
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
