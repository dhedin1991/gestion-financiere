import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/patrimoine_item.dart';
import '../providers/patrimoine_providers.dart';

class PatrimoineFormSheet extends ConsumerStatefulWidget {
  final PatrimoineItem? existing;

  const PatrimoineFormSheet({super.key, this.existing});

  @override
  ConsumerState<PatrimoineFormSheet> createState() => _PatrimoineFormSheetState();
}

class _PatrimoineFormSheetState extends ConsumerState<PatrimoineFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomController;
  late TextEditingController _valeurController;
  late TextEditingController _deviseController;
  late TextEditingController _descriptionController;
  late TextEditingController _localisationController;

  PatrimoineCategory _categorie = PatrimoineCategory.immobilier;
  DateTime? _dateAcquisition;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nomController = TextEditingController(text: existing?.nom ?? '');
    _valeurController = TextEditingController(
      text: existing != null ? existing.valeurEstimee.toStringAsFixed(0) : '',
    );
    _deviseController = TextEditingController(text: existing?.devise ?? 'XOF');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _localisationController = TextEditingController(text: existing?.localisation ?? '');
    _categorie = existing?.categorie ?? PatrimoineCategory.immobilier;
    _dateAcquisition = existing?.dateAcquisition;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _valeurController.dispose();
    _deviseController.dispose();
    _descriptionController.dispose();
    _localisationController.dispose();
    super.dispose();
  }

  String _categoryLabel(PatrimoineCategory category) {
    switch (category) {
      case PatrimoineCategory.immobilier:
        return 'Immobilier';
      case PatrimoineCategory.vehicule:
        return 'Véhicule';
      case PatrimoineCategory.materiel:
        return 'Matériel';
      case PatrimoineCategory.autre:
        return 'Autre';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateAcquisition ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateAcquisition = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final valeur = double.parse(_valeurController.text.replaceAll(',', '.'));
      final now = DateTime.now();

      final item = PatrimoineItem(
        id: widget.existing?.id,
        nom: _nomController.text.trim(),
        categorie: _categorie,
        valeurEstimee: valeur,
        devise: _deviseController.text.trim().isEmpty ? 'XOF' : _deviseController.text.trim(),
        dateAcquisition: _dateAcquisition,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        localisation: _localisationController.text.trim().isEmpty
            ? null
            : _localisationController.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      final actions = ref.read(patrimoineActionsProvider);
      if (_isEditing) {
        await actions.update(item);
      } else {
        await actions.create(item);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Bien modifié' : 'Bien ajouté')),
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
                _isEditing ? 'Modifier le bien' : 'Nouveau bien',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom du bien',
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
              DropdownButtonFormField<PatrimoineCategory>(
                initialValue: _categorie,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: PatrimoineCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(_categoryLabel(category)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _categorie = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _valeurController,
                      decoration: const InputDecoration(
                        labelText: 'Valeur estimée',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obligatoire';
                        }
                        final parsed = double.tryParse(value.replaceAll(',', '.'));
                        if (parsed == null || parsed < 0) {
                          return 'Valeur invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _deviseController,
                      decoration: const InputDecoration(
                        labelText: 'Devise',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date d\'acquisition (optionnel)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    _dateAcquisition != null
                        ? DateFormat('dd/MM/yyyy').format(_dateAcquisition!)
                        : 'Non renseignée',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localisationController,
                decoration: const InputDecoration(
                  labelText: 'Localisation (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
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
                    : Text(_isEditing ? 'Enregistrer les modifications' : 'Ajouter le bien'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
