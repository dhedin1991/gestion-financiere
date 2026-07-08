import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../accounts/presentation/providers/account_providers.dart';
import '../../domain/entities/savings.dart';
import '../providers/savings_providers.dart';

class SavingsFormSheet extends ConsumerStatefulWidget {
  final Savings? existing;
  const SavingsFormSheet({super.key, this.existing});

  @override
  ConsumerState<SavingsFormSheet> createState() => _SavingsFormSheetState();
}

class _SavingsFormSheetState extends ConsumerState<SavingsFormSheet> {
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
                data: (accounts) {
                  final selectable = accounts
                      .where((a) => !a.isArchived || a.id == _selectedAccountId)
                      .toList();
                  return DropdownButtonFormField<int>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(labelText: 'Compte lié *'),
                    items: selectable
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.isArchived ? '${a.name} (archivé)' : a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    validator: (v) => v == null ? 'Choisis un compte' : null,
                  );
                },
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette épargne ?'),
        content: const Text('Cette action est définitive. L\'historique des mouvements sera aussi supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
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
