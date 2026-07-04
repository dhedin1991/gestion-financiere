import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/savings.dart';
import '../providers/savings_providers.dart';

class SavingsMovementDialog extends ConsumerStatefulWidget {
  final Savings savings;
  final SavingsTransactionType type;

  const SavingsMovementDialog({super.key, required this.savings, required this.type});

  @override
  ConsumerState<SavingsMovementDialog> createState() => _SavingsMovementDialogState();
}

class _SavingsMovementDialogState extends ConsumerState<SavingsMovementDialog> {
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
