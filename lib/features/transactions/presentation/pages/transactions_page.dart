import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_error_message.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/panel.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transaction_providers.dart';
import '../../../../core/ledger/operation_service.dart';
import '../widgets/operation_form_sheet.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transfer_form_sheet.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(transactionFiltersProvider.notifier).update((f) => f.copyWith(search: value));
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(transactionFiltersProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final accountsAsync = ref.watch(allAccountsIncludingArchivedProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Revenus & Dépenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Virement entre comptes',
            onPressed: () => _showTransferForm(context),
          ),
          const AppMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher une transaction...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filters.search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _typeFilterChip(context, filters, TransactionType.depense, 'Dépenses'),
                const SizedBox(width: 8),
                _typeFilterChip(context, filters, TransactionType.revenu, 'Revenus'),
                const SizedBox(width: 8),
                ...accountsAsync.valueOrNull?.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _accountFilterChip(context, filters, a),
                      ),
                    ) ??
                    [],
                ...categoriesAsync.valueOrNull?.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _categoryFilterChip(context, filters, c),
                      ),
                    ) ??
                    [],
                if (filters.isActive)
                  ActionChip(
                    label: const Text('Réinitialiser'),
                    avatar: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(transactionFiltersProvider.notifier).state =
                          const TransactionFilters();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text(AppErrorMessage.friendly(err))),
              data: (page) {
                final transactions = page.items;
                if (transactions.isEmpty) {
                  return EmptyState(
                    icon: filters.isActive ? Icons.search_off : Icons.receipt_long_outlined,
                    message: filters.isActive
                        ? 'Aucun résultat pour ces filtres'
                        : 'Aucune transaction pour le moment',
                    subtitle: filters.isActive
                        ? null
                        : 'Ajoute ton premier revenu ou dépense avec le bouton +',
                  );
                }

                final accounts = accountsAsync.valueOrNull ?? <Account>[];

                final showFooter = page.hasMore || page.loadingMore;

                // Entrées : synthèse, puis un en-tête par jour suivi de ses lignes.
                final entries = <Object>['summary'];
                String? lastDay;
                for (final t in transactions) {
                  final d = DateFormat('yyyy-MM-dd').format(t.transactionDate);
                  if (d != lastDay) {
                    entries.add(d);
                    lastDay = d;
                  }
                  entries.add(t);
                }
                final dayNet = <String, double>{};
                for (final t in transactions) {
                  if (t.isTransfer) continue;
                  final d = DateFormat('yyyy-MM-dd').format(t.transactionDate);
                  dayNet[d] = (dayNet[d] ?? 0) + (t.type == TransactionType.revenu ? t.amount : -t.amount);
                }
                final colors = context.appColors;
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length + (showFooter ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= entries.length) {
                      // Ligne de pied de liste : bouton "Charger plus" (ou
                      // indicateur de chargement pendant la page suivante).
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: page.loadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  onPressed: () =>
                                      ref.read(filteredTransactionsProvider.notifier).loadMore(),
                                  child: const Text('Charger plus'),
                                ),
                        ),
                      );
                    }

                    final e = entries[index];
                    if (e is String && e == 'summary') {
                      return _TransactionsSummary(items: transactions);
                    }
                    if (e is String) {
                      final date = DateTime.parse(e);
                      final label = e == today
                          ? 'Aujourd’hui'
                          : e == yesterday
                              ? 'Hier'
                              : DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
                      final net = dayNet[e] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                        child: Row(children: [
                          Expanded(
                            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.muted)),
                          ),
                          if (net != 0)
                            Text(
                              '${net > 0 ? '+' : '-'} ${AppFormat.currency(symbol: transactions.first.currency).format(net.abs())}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: net > 0 ? colors.positive : colors.negative),
                            ),
                        ]),
                      );
                    }

                    final t = e as FinancialTransaction;
                    final account = accounts.where((a) => a.id == t.accountId).toList();
                    final accountName = account.isNotEmpty ? account.first.name : 'Compte supprimé';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      clipBehavior: Clip.antiAlias,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onSecondaryTapUp: (t.isTransfer || t.kind != null) ? null : (d) => _showContextMenu(context, ref, t, d.globalPosition),
                        onLongPressStart: (t.isTransfer || t.kind != null) ? null : (d) => _showContextMenu(context, ref, t, d.globalPosition),
                        child: TransactionTile(
                          transaction: t,
                          accountName: accountName,
                          onTap: () => (t.isTransfer || t.kind != null)
                              ? _confirmDeleteTransfer(context, ref, t)
                              : _showTransactionForm(context, ref, existing: t),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeFilterChip(
    BuildContext context,
    TransactionFilters filters,
    TransactionType type,
    String label,
  ) {
    final selected = filters.type == type;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (isSelected) {
        ref.read(transactionFiltersProvider.notifier).update(
              (f) => f.copyWith(type: () => isSelected ? type : null),
            );
      },
    );
  }

  Widget _accountFilterChip(BuildContext context, TransactionFilters filters, Account account) {
    final selected = filters.accountId == account.id;
    return FilterChip(
      label: Text(account.name),
      selected: selected,
      onSelected: (isSelected) {
        ref.read(transactionFiltersProvider.notifier).update(
              (f) => f.copyWith(accountId: () => isSelected ? account.id : null),
            );
      },
    );
  }

  Widget _categoryFilterChip(BuildContext context, TransactionFilters filters, AppCategory category) {
    final selected = filters.categoryId == category.id;
    return FilterChip(
      label: Text(category.name),
      selected: selected,
      onSelected: (isSelected) {
        ref.read(transactionFiltersProvider.notifier).update(
              (f) => f.copyWith(categoryId: () => isSelected ? category.id : null),
            );
      },
    );
  }

  void _showTransactionForm(BuildContext context, WidgetRef ref, {FinancialTransaction? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => existing == null ? const OperationFormSheet() : _TransactionFormSheet(existing: existing),
    );
  }

  /// Menu contextuel (clic droit sur Windows, appui long sur mobile).
  Future<void> _showContextMenu(BuildContext context, WidgetRef ref, FinancialTransaction t, Offset position) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('Modifier')),
        PopupMenuItem(value: 'duplicate', child: Text('Dupliquer (aujourd\u2019hui)')),
        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
      ],
    );
    if (!context.mounted || choice == null) return;
    final actions = ref.read(transactionActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (choice == 'edit') {
        _showTransactionForm(context, ref, existing: t);
      } else if (choice == 'duplicate') {
        final now = DateTime.now();
        await actions.create(_copyWithoutId(t, date: now));
        messenger.showSnackBar(const SnackBar(content: Text('Écriture dupliquée')));
      } else if (choice == 'delete' && t.id != null) {
        await actions.delete(t.id!);
        _showUndoDelete(messenger, actions, t);
      }
    } catch (e) {
      if (context.mounted) AppErrorMessage.showSnackBar(context, e);
    }
  }

  void _showTransferForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TransferFormSheet(),
    );
  }

  Future<void> _confirmDeleteTransfer(BuildContext context, WidgetRef ref, FinancialTransaction t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.kind == null ? 'Supprimer ce virement ?' : 'Supprimer cette opération ?'),
        content: Text(
          t.kind == null
              ? 'Les deux écritures liées à ce virement (sur les deux comptes) seront supprimées ensemble.'
              : 'Tout ce que cette opération a créé ou modifié (comptes, dette, crédit, épargne) sera annulé.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (t.kind != null && t.id != null) {
        await ref.read(operationServiceProvider).deleteLedgerEntry(t.id!);
      } else {
        await ref.read(transactionRepositoryProvider).deleteTransfer(t.transferGroup!);
      }
      ref.invalidate(accountsListProvider);
      ref.invalidate(allAccountsIncludingArchivedProvider);
      ref.invalidate(globalBalanceProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(filteredTransactionsProvider);
    } catch (e) {
      if (context.mounted) AppErrorMessage.showSnackBar(context, e);
    }
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
    final accountsAsync = ref.watch(allAccountsIncludingArchivedProvider);
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
                error: (e, _) => Text(AppErrorMessage.friendly(e)),
                data: (accounts) {
                  // On ne propose pas les comptes archivés pour une NOUVELLE
                  // transaction, mais on garde celui actuellement sélectionné
                  // même s'il a été archivé depuis, pour ne pas faire planter
                  // le menu déroulant lors d'une modification.
                  final selectable = accounts
                      .where((a) => !a.isArchived || a.id == _selectedAccountId)
                      .toList();
                  if (selectable.isEmpty) {
                    return const Text(
                      'Crée d\'abord un compte avant d\'ajouter une transaction.',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  _selectedAccountId ??= selectable.first.id;
                  return DropdownButtonFormField<int>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(labelText: 'Compte *'),
                    items: selectable
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.isArchived ? '${a.name} (archivé)' : a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    validator: (v) => v == null ? 'Sélectionne un compte' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(AppErrorMessage.friendly(e)),
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

    try {
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
    } catch (e) {
      if (mounted) {
        AppErrorMessage.showSnackBar(context, e);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.existing?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette transaction ?'),
        content: const Text('Cette action est définitive et ajustera le solde du compte concerné.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = widget.existing!;
      final messenger = ScaffoldMessenger.of(context);
      final actions = ref.read(transactionActionsProvider);
      await actions.delete(deleted.id!);
      if (mounted) Navigator.of(context).pop();
      _showUndoDelete(messenger, actions, deleted);
    } catch (e) {
      if (mounted) {
        AppErrorMessage.showSnackBar(context, e);
      }
    }
  }
}

/// Ouvre le formulaire de saisie d'une écriture (nouvelle ou existante).
/// Utilisable depuis n'importe quel écran (bouton « + », Accueil, recherche).
void showTransactionFormSheet(BuildContext context, {FinancialTransaction? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => existing == null ? const OperationFormSheet() : _TransactionFormSheet(existing: existing),
  );
}

/// Ouvre le formulaire de virement entre deux comptes.
void showTransferFormSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const TransferFormSheet(),
  );
}


FinancialTransaction _copyWithoutId(FinancialTransaction t, {DateTime? date}) {
  final now = DateTime.now();
  return FinancialTransaction(
    accountId: t.accountId,
    categoryId: t.categoryId,
    type: t.type,
    amount: t.amount,
    currency: t.currency,
    description: t.description,
    paymentMethod: t.paymentMethod,
    transactionDate: date ?? t.transactionDate,
    createdAt: now,
    updatedAt: now,
  );
}

/// Affiche « Écriture supprimée — Annuler » : l'annulation recrée l'écriture
/// (le solde du compte est ajusté comme pour une saisie normale).
void _showUndoDelete(ScaffoldMessengerState messenger, TransactionActions actions, FinancialTransaction deleted) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Écriture supprimée'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () async {
            try {
              await actions.create(_copyWithoutId(deleted));
            } catch (_) {
              messenger.showSnackBar(const SnackBar(content: Text('Impossible de rétablir l\u2019écriture')));
            }
          },
        ),
      ),
    );
}


/// Synthèse des transactions affichées : revenus, dépenses, solde net
/// (les virements entre comptes sont exclus).
class _TransactionsSummary extends StatelessWidget {
  final List<FinancialTransaction> items;
  const _TransactionsSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final real = items.where((t) => !t.isTransfer);
    final income = real.where((t) => t.type == TransactionType.revenu).fold<double>(0, (s, t) => s + t.amount);
    final expense = real.where((t) => t.type == TransactionType.depense).fold<double>(0, (s, t) => s + t.amount);
    final net = income - expense;
    final fmt = AppFormat.currency(symbol: items.first.currency);

    Widget cell(String label, double v, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: colors.muted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(fmt.format(v), style: amountTextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
        );

    return Panel(
      title: 'Synthèse (${items.length} transaction${items.length > 1 ? 's' : ''} affichée${items.length > 1 ? 's' : ''})',
      child: Row(children: [
        cell('Revenus', income, colors.positive),
        cell('Dépenses', expense, colors.negative),
        cell('Solde net', net.abs(), net >= 0 ? colors.positive : colors.negative),
      ]),
    );
  }
}
