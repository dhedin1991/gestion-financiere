import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_message.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../providers/transaction_providers.dart';

/// Formulaire de virement entre deux comptes : crée les deux écritures
/// liées (dépense + revenu) via TransactionRepository.createTransfer.
/// N'affiche que des comptes de la MÊME devise (source et destination) —
/// virer entre deux devises différentes demanderait un taux de change que
/// l'app ne gère pas.
class TransferFormSheet extends ConsumerStatefulWidget {
  const TransferFormSheet({super.key});

  @override
  ConsumerState<TransferFormSheet> createState() => _TransferFormSheetState();
}

class _TransferFormSheetState extends ConsumerState<TransferFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _fromAccountId;
  int? _toAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(String currency) async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccountId == null || _toAccountId == null) return;
    if (_fromAccountId == _toAccountId) {
      AppErrorMessage.showSnackBar(context, 'Le compte source et le compte destination doivent être différents.');
      return;
    }
    setState(() => _busy = true);
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      await ref.read(transactionRepositoryProvider).createTransfer(
            fromAccountId: _fromAccountId!,
            toAccountId: _toAccountId!,
            amount: amount,
            currency: currency,
            date: _selectedDate,
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          );
      ref.invalidate(accountsListProvider);
      ref.invalidate(allAccountsIncludingArchivedProvider);
      ref.invalidate(globalBalanceProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(filteredTransactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppErrorMessage.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Virement entre comptes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              accountsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(AppErrorMessage.friendly(e)),
                data: (accounts) {
                  if (accounts.length < 2) {
                    return const Text(
                      'Il faut au moins deux comptes actifs pour faire un virement.',
                      style: TextStyle(color: Colors.red),
                    );
                  }

                  final currency = accounts
                      .firstWhere((a) => a.id == (_fromAccountId ?? accounts.first.id),
                          orElse: () => accounts.first)
                      .currency;
                  // On ne propose comme destination que des comptes de la
                  // même devise que la source (voir doc de la classe).
                  final sameCurrency = accounts.where((a) => a.currency == currency).toList();
                  if (_fromAccountId == null) _fromAccountId = sameCurrency.first.id;
                  if (_toAccountId == null || _toAccountId == _fromAccountId) {
                    final other = sameCurrency.where((a) => a.id != _fromAccountId).toList();
                    _toAccountId = other.isNotEmpty ? other.first.id : null;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _fromAccountId,
                        decoration: const InputDecoration(labelText: 'Depuis *'),
                        items: accounts
                            .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.currency})')))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _fromAccountId = v;
                          _toAccountId = null; // la devise a pu changer
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _toAccountId,
                        decoration: InputDecoration(
                          labelText: 'Vers * (en $currency)',
                          helperText: sameCurrency.length < 2
                              ? 'Aucun autre compte en $currency : crée-en un, ou vire depuis un compte de cette devise.'
                              : null,
                        ),
                        items: sameCurrency
                            .where((a) => a.id != _fromAccountId)
                            .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _toAccountId = v),
                        validator: (v) => v == null ? 'Choisis un compte destination' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Montant * ($currency)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Champ requis';
                          final parsed = double.tryParse(v.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) return 'Montant invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Note (optionnel)'),
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
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy || sameCurrency.length < 2 ? null : () => _submit(currency),
                        child: _busy
                            ? const SizedBox(
                                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Enregistrer le virement'),
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
