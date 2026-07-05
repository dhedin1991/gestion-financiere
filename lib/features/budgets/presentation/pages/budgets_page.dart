import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../domain/entities/budget.dart';
import '../providers/budget_providers.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(budgetsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau budget'),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              return _BudgetCard(
                budget: budget,
                onTap: () => _showBudgetForm(context, ref, existing: budget),
              );
            },
          );
        },
      ),
    );
  }

  void _showBudgetForm(BuildContext context, WidgetRef ref, {Budget? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BudgetFormSheet(existing: existing),
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
            Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucun budget défini',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Crée un budget global ou par catégorie pour suivre tes dépenses',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final Budget budget;
  final VoidCallback onTap;

  const _BudgetCard({required this.budget, required this.onTap});

  String _periodLabel(BudgetPeriod p) {
    switch (p) {
      case BudgetPeriod.journalier:
        return 'Journalier';
      case BudgetPeriod.hebdomadaire:
        return 'Hebdomadaire';
      case BudgetPeriod.mensuel:
        return 'Mensuel';
      case BudgetPeriod.trimestriel:
        return 'Trimestriel';
      case BudgetPeriod.semestriel:
        return 'Semestriel';
      case BudgetPeriod.annuel:
        return 'Annuel';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spentAsync = ref.watch(budgetSpentAmountProvider(budget.id!));
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: budget.currency, decimalDigits: 0);

    String title;
    if (budget.name != null && budget.name!.isNotEmpty) {
      title = budget.name!;
    } else if (budget.isGlobal) {
      title = 'Budget global';
    } else {
      final categories = categoriesAsync.valueOrNull ?? <AppCategory>[];
      final match = categories.where((c) => c.id == budget.categoryId).toList();
      title = match.isNotEmpty ? match.first.name : 'Catégorie';
    }

    return Card(
      child: InkWell(
        onTap: onTap,
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
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  Chip(
                    label: Text(_periodLabel(budget.period)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              spentAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur : $e'),
                data: (spent) {
                  final ratio = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
                  final isOverBudget = spent > budget.amount;
                  final color = ratio >= 1.0
                      ? Colors.red
                      : ratio >= 0.8
                          ? Colors.orange
                          : Colors.green;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: color.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOverBudget
                            ? '${fmt.format(spent)} dépensés — Budget dépassé de ${fmt.format(spent - budget.amount)} !'
                            : '${fmt.format(spent)} dépensés sur ${fmt.format(budget.amount)}',
                        style: TextStyle(
                          color: isOverBudget ? Colors.red : Colors.grey.shade700,
                          fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
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

class _BudgetFormSheet extends ConsumerStatefulWidget {
  final Budget? existing;
  const _BudgetFormSheet({this.existing});

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  BudgetPeriod _selectedPeriod = BudgetPeriod.mensuel;
  int? _selectedCategoryId;
  DateTime _selectedStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    if (e != null) {
      _selectedPeriod = e.period;
      _selectedCategoryId = e.categoryId;
      _selectedStartDate = e.startDate;
    }
  }

  String _periodLabel(BudgetPeriod p) {
    switch (p) {
      case BudgetPeriod.journalier:
        return 'Journalier';
      case BudgetPeriod.hebdomadaire:
        return 'Hebdomadaire';
      case BudgetPeriod.mensuel:
        return 'Mensuel';
      case BudgetPeriod.trimestriel:
        return 'Trimestriel';
      case BudgetPeriod.semestriel:
        return 'Semestriel';
      case BudgetPeriod.annuel:
        return 'Annuel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final categoriesAsync = ref.watch(allCategoriesProvider);

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
                isEditing ? 'Modifier le budget' : 'Nouveau budget',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom (optionnel)'),
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur catégories : $e'),
                data: (categories) => DropdownButtonFormField<int?>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    helperText: 'Laisse vide pour un budget global',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Budget global (toutes catégories)')),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant limite *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BudgetPeriod>(
                value: _selectedPeriod,
                decoration: const InputDecoration(labelText: 'Période'),
                items: BudgetPeriod.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(_periodLabel(p))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPeriod = v ?? _selectedPeriod),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date de début'),
                subtitle: Text(
                  '${_selectedStartDate.day}/${_selectedStartDate.month}/${_selectedStartDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedStartDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _selectedStartDate = picked);
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? 'Enregistrer' : 'Créer le budget'),
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

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final actions = ref.read(budgetActionsProvider);
    final now = DateTime.now();

    try {
      if (widget.existing == null) {
        await actions.create(Budget(
          name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          categoryId: _selectedCategoryId,
          amount: amount,
          period: _selectedPeriod,
          startDate: _selectedStartDate,
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        await actions.update(widget.existing!.copyWith(
          name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          categoryId: _selectedCategoryId,
          amount: amount,
          period: _selectedPeriod,
          startDate: _selectedStartDate,
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
        title: const Text('Supprimer ce budget ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirmed == true && widget.existing?.id != null) {
      try {
        await ref.read(budgetActionsProvider).delete(widget.existing!.id!);
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
