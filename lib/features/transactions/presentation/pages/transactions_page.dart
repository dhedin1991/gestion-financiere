import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_tile.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Revenus & Dépenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucune transaction pour le moment.\nAjoute ton premier revenu ou dépense avec le bouton +',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final accounts = accountsAsync.asData?.value ?? <Account>[];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = transactions[index];
              final account = accounts.where((a) => a.id == t.accountId).toList();
              final accountName = account.isNotEmpty ? account.first.name : 'Compte supprimé';

              return TransactionTile(
                transaction: t,
                accountName: accountName,
                onTap: () => _showTransactionForm(context, ref, existing: t),
              );
            },
          );
        },
      ),
    );
  }

  void _showTransactionForm(BuildContext context, WidgetRef ref, {FinancialTransaction? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TransactionFormSheet(existing: existing),
    );
  }
}

class _TransactionFormSheet extends ConsumerStatefulWidget {
  final FinancialTransaction? existing;
  const _TransactionFormSheet({this.existing});

  @override
  ConsumerState<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<_TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  TransactionType _type = TransactionType.depense;
  int? _selectedAccountId;
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountController = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    _descriptionController = TextEditingController(text: e?.description ?? '');
    if (e != null) {
      _type = e.type;
      _selectedAccountId = e.accountId;
      _selectedCategoryId = e.categoryId;
      _selectedDate = e.transactionDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);
    final categoriesAsync = _type == TransactionType.revenu
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);
    final isEditing = widget.existing != null;

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
                isEditing ? 'Modifier la transaction' : 'Nouvelle transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.depense,
                    label: Text('Dépense'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: TransactionType.revenu,
                    label: Text('Revenu'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _selectedCategoryId = null; // les catégories changent selon le type
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur comptes : $e'),
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Text(
                      'Crée d\'abord un compte avant d\'ajouter une transaction.',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  _selectedAccountId ??= accounts.first.id;
                  return DropdownButtonFormField<int>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(labelText: 'Compte *'),
                    items: accounts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    validator: (v) => v == null ? 'Sélectionne un compte' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur catégories : $e'),
                data: (categories) => DropdownButtonFormField<int>(
                  value: categories.any((c) => c.id == _selectedCategoryId)
                      ? _selectedCategoryId
                      : null,
                  decoration: const InputDecoration(labelText: 'Catégorie (optionnel)'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optionnel)'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
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
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _selectedAccountId == null ? null : _submit,
                child: Text(isEditing ? 'Enregistrer' : 'Ajouter la transaction'),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _delete,
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
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final actions = ref.read(transactionActionsProvider);
    final now = DateTime.now();

    if (widget.existing == null) {
      await actions.create(FinancialTransaction(
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId,
        type: _type,
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        transactionDate: _selectedDate,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await actions.update(widget.existing!.copyWith(
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId,
        type: _type,
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        transactionDate: _selectedDate,
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing?.id == null) return;
    await ref.read(transactionActionsProvider).delete(widget.existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }
}

// Petit utilitaire pour lire une valeur AsyncValue de façon synchrone
// sans provoquer d'erreur si elle n'est pas encore chargée.
extension _AsyncValueX<T> on AsyncValue<T> {
  AsyncData<T>? get asData => whenOrNull(data: (d) => AsyncData(d)) as AsyncData<T>?;
}
