import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../domain/entities/credit.dart';
import '../providers/credit_providers.dart';

class CreditFormSheet extends ConsumerStatefulWidget {
  final Credit? existing;

  const CreditFormSheet({super.key, this.existing});

  @override
  ConsumerState<CreditFormSheet> createState() => _CreditFormSheetState();
}

class _CreditFormSheetState extends ConsumerState<CreditFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _contractController;
  late TextEditingController _principalController;
  late TextEditingController _interestController;
  late TextEditingController _durationController;
  late TextEditingController _monthlyPaymentController;
  late TextEditingController _currencyController;
  late TextEditingController _notesController;

  DateTime _startDate = DateTime.now();
  int? _accountId;
  CreditStatus _status = CreditStatus.actif;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _contractController = TextEditingController(text: existing?.contractNumber ?? '');
    _principalController = TextEditingController(
      text: existing != null ? existing.principalAmount.toStringAsFixed(0) : '',
    );
    _interestController = TextEditingController(
      text: existing != null ? existing.interestRate.toString() : '0',
    );
    _durationController = TextEditingController(
      text: existing != null ? existing.durationMonths.toString() : '',
    );
    _monthlyPaymentController = TextEditingController(
      text: existing != null ? existing.monthlyPayment.toStringAsFixed(0) : '',
    );
    _currencyController = TextEditingController(text: existing?.currency ?? 'XOF');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _startDate = existing?.startDate ?? DateTime.now();
    _accountId = existing?.accountId;
    _status = existing?.status ?? CreditStatus.actif;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contractController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _durationController.dispose();
    _monthlyPaymentController.dispose();
    _currencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Calcule la mensualité théorique à partir du capital, du taux annuel
  /// et de la durée, selon la formule d'amortissement bancaire classique.
  /// Retourne null si les champs nécessaires ne sont pas encore remplis
  /// correctement.
  double? _calculateSuggestedPayment() {
    final principal = double.tryParse(_principalController.text.replaceAll(',', '.'));
    final rate = double.tryParse(_interestController.text.replaceAll(',', '.'));
    final duration = int.tryParse(_durationController.text);

    if (principal == null || principal <= 0) return null;
    if (rate == null || rate < 0) return null;
    if (duration == null || duration <= 0) return null;

    if (rate == 0) {
      return principal / duration;
    }

    final monthlyRate = rate / 100 / 12;
    final payment = principal * monthlyRate / (1 - math.pow(1 + monthlyRate, -duration));
    return payment;
  }

  void _applySuggestedPayment() {
    final suggested = _calculateSuggestedPayment();
    if (suggested == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remplis d\'abord le capital, le taux et la durée pour calculer la mensualité'),
        ),
      );
      return;
    }
    setState(() {
      _monthlyPaymentController.text = suggested.toStringAsFixed(0);
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final credit = Credit(
        id: widget.existing?.id,
        name: _nameController.text.trim(),
        contractNumber: _contractController.text.trim().isEmpty
            ? null
            : _contractController.text.trim(),
        principalAmount: double.parse(_principalController.text.replaceAll(',', '.')),
        interestRate: double.parse(_interestController.text.replaceAll(',', '.')),
        startDate: _startDate,
        durationMonths: int.parse(_durationController.text),
        monthlyPayment: double.parse(_monthlyPaymentController.text.replaceAll(',', '.')),
        accountId: _accountId,
        currency: _currencyController.text.trim().isEmpty ? 'XOF' : _currencyController.text.trim(),
        status: _status,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      final actions = ref.read(creditActionsProvider);
      if (_isEditing) {
        await actions.update(credit);
      } else {
        await actions.create(credit);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Crédit modifié'
                  : 'Crédit ajouté, échéancier généré automatiquement',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEditing ? 'Modifier le crédit' : 'Nouveau crédit',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom / organisme prêteur',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contractController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de contrat (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _principalController,
                      decoration: const InputDecoration(
                        labelText: 'Capital emprunté',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Obligatoire';
                        if (double.tryParse(value.replaceAll(',', '.')) == null) {
                          return 'Valeur invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _currencyController,
                      decoration: const InputDecoration(
                        labelText: 'Devise',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _interestController,
                decoration: const InputDecoration(
                  labelText: 'Taux d\'intérêt (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Obligatoire';
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Valeur invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_isEditing) ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de début (non modifiable)',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Durée en mois (non modifiable)',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_durationController.text),
                ),
              ] else ...[
                InkWell(
                  onTap: _pickStartDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date de début',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Durée (en mois)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Obligatoire';
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed <= 0) return 'Durée invalide';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _monthlyPaymentController,
                decoration: InputDecoration(
                  labelText: 'Montant de la mensualité',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate_outlined),
                    tooltip: 'Calculer à partir du capital, du taux et de la durée',
                    onPressed: _applySuggestedPayment,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Obligatoire';
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Valeur invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Astuce : remplis le capital, le taux et la durée, puis appuie sur 🧮 pour calculer automatiquement la mensualité.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (accounts) {
                  return DropdownButtonFormField<int?>(
                    value: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Compte de remboursement (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Aucun'),
                      ),
                      ...accounts.map((Account account) {
                        return DropdownMenuItem<int?>(
                          value: account.id,
                          child: Text(account.name),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _accountId = value),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CreditStatus>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: CreditStatus.actif, child: Text('Actif')),
                  DropdownMenuItem(value: CreditStatus.solde, child: Text('Soldé')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Enregistrer les modifications' : 'Créer le crédit'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
