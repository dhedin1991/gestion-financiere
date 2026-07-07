import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/savings.dart';
import '../providers/savings_providers.dart';

class SavingsMovementDialog extends ConsumerStatefulWidget {
  final Savings savings;
  final SavingsTransactionType type;

  /// Si non-null, le dialogue passe en mode "modification" de ce mouvement
  /// existant, au lieu de créer un nouveau mouvement.
  final SavingsTransaction? existing;

  const SavingsMovementDialog({
    super.key,
    required this.savings,
    required this.type,
    this.existing,
  });

  @override
  ConsumerState<SavingsMovementDialog> createState() => _SavingsMovementDialogState();
}

class _SavingsMovementDialogState extends ConsumerState<SavingsMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  late SavingsTransactionType _type;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _selectedDate = existing?.date ?? DateTime.now();
    _type = existing?.type ?? widget.type;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVersement = _type == SavingsTransactionType.versement;

    // Solde disponible pour un retrait : si on modifie un retrait existant,
    // on "rend" d'abord son ancien montant avant de vérifier la limite,
    // pour ne pas bloquer inutilement une modification qui ne change pas
    // vraiment le solde disponible.
    final availableForWithdrawal = widget.savings.currentBalance +
        (_isEditing && widget.existing!.type == SavingsTransactionType.retrait
            ? widget.existing!.amount
            : 0);

    return AlertDialog(
      title: Text(
        _isEditing
            ? 'Modifier le mouvement'
            : (isVersement ? 'Verser sur "${widget.savings.name}"' : 'Retirer de "${widget.savings.name}"'),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditing) ...[
              SegmentedButton<SavingsTransactionType>(
                segments: const [
                  ButtonSegment(value: SavingsTransactionType.versement, label: Text('Versement')),
                  ButtonSegment(value: SavingsTransactionType.retrait, label: Text('Retrait')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant *'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ requis';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Montant invalide';
                if (!isVersement && parsed > availableForWithdrawal) {
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
        FilledButton(onPressed: _submit, child: Text(_isEditing ? 'Enregistrer' : 'Valider')),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    try {
      final actions = ref.read(savingsActionsProvider);
      if (_isEditing) {
        await actions.updateTransaction(
          SavingsTransaction(
            id: widget.existing!.id,
            savingsId: widget.savings.id!,
            type: _type,
            amount: amount,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            createdAt: widget.existing!.createdAt,
          ),
        );
      } else {
        await actions.addTransaction(
          SavingsTransaction(
            savingsId: widget.savings.id!,
            type: _type,
            amount: amount,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
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
}
