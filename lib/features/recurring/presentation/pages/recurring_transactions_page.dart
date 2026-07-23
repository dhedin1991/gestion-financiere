import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../providers/recurring_providers.dart';
import '../widgets/recurring_tile.dart';

class RecurringTransactionsPage extends ConsumerWidget {
  const RecurringTransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(allRecurringTransactionsProvider);
    final accountsAsync = ref.watch(allAccountsIncludingArchivedProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('Transactions récurrentes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.autorenew,
              message: 'Aucune transaction récurrente',
              subtitle: 'Loyer, salaire, abonnements... configure-les une fois, '
                  'l\'app les enregistre automatiquement à chaque échéance.',
            );
          }

          final accounts = accountsAsync.valueOrNull ?? <Account>[];

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = items[index];
              final match = accounts.where((a) => a.id == r.accountId).toList();
              final accountName = match.isNotEmpty ? match.first.name : 'Compte supprimé';
              return RecurringTile(
                recurring: r,
                accountName: accountName,
                onTap: () => _showForm(context, existing: r),
              );
            },
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, {RecurringTransaction? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RecurringFormSheet(existing: existing),
    );
  }
}

class _RecurringFormSheet extends ConsumerStatefulWidget {
  final RecurringTransaction? existing;
  const _RecurringFormSheet({this.existing});

  @override
  ConsumerState<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late TransactionType _type;
  late RecurrenceFrequency _frequency;
  late DateTime _nextDueDate;
  int? _accountId;
  int? _categoryId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountController = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _type = e?.type ?? TransactionType.depense;
    _frequency = e?.frequency ?? RecurrenceFrequency.mensuelle;
    _nextDueDate = e?.nextDueDate ?? DateTime.now();
    _accountId = e?.accountId;
    _categoryId = e?.categoryId;
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) setState(() => _nextDueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _accountId == null) {
      if (_accountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisis un compte.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    try {
      final actions = ref.read(recurringActionsProvider);
      if (widget.existing == null) {
        await actions.create(RecurringTransaction(
          accountId: _accountId!,
          categoryId: _categoryId,
          type: _type,
          amount: amount,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          frequency: _frequency,
          nextDueDate: _nextDueDate,
          active: _active,
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        await actions.update(widget.existing!.copyWith(
          accountId: _accountId,
          categoryId: _categoryId,
          type: _type,
          amount: amount,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          frequency: _frequency,
          nextDueDate: _nextDueDate,
          active: _active,
          updatedAt: now,
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existing?.id == null) return;
    await ref.read(recurringActionsProvider).delete(widget.existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(allAccountsIncludingArchivedProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final dateFmt = MaterialLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Nouvelle récurrence' : 'Modifier la récurrence',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.depense, label: Text('Dépense')),
                  ButtonSegment(value: TransactionType.revenu, label: Text('Revenu')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder()),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (ex: Loyer, Salaire...)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _accountId,
                decoration: const InputDecoration(labelText: 'Compte', border: OutlineInputBorder()),
                items: (accountsAsync.valueOrNull ?? <Account>[])
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Catégorie (optionnel)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucune')),
                  ...(categoriesAsync.valueOrNull ?? <AppCategory>[])
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency>(
                value: _frequency,
                decoration: const InputDecoration(labelText: 'Fréquence', border: OutlineInputBorder()),
                items: RecurrenceFrequency.values
                    .map((f) => DropdownMenuItem(value: f, child: Text(frequencyLabel(f))))
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v!),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Prochaine échéance : ${dateFmt.formatMediumDate(_nextDueDate)}'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('En pause, elle ne génère plus de transaction'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
