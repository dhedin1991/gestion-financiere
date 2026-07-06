import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_menu_button.dart';
import '../../domain/entities/account.dart';
import '../providers/account_providers.dart';
import '../widgets/account_card.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(
  leading: const AppMenuButton(),
  title: const Text('Mes Comptes'),
  actions: [
    IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'Actualiser',
      onPressed: () {
        ref.invalidate(accountsListProvider);
        ref.invalidate(globalBalanceProvider);
      },
    ),
  ],
),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau compte'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur : $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return AccountCard(
                account: account,
                onTap: () => _showAccountForm(context, ref, existing: account),
              );
            },
          );
        },
      ),
    );
  }

  void _showAccountForm(BuildContext context, WidgetRef ref, {Account? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccountFormSheet(existing: existing),
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
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucun compte pour le moment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoute ton premier compte (banque, mobile money, espèces...) avec le bouton +',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  final Account? existing;
  const _AccountFormSheet({this.existing});

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bankController;
  late final TextEditingController _balanceController;
  late final TextEditingController _currentBalanceController;
  AccountType _selectedType = AccountType.courant;
  String _selectedCurrency = 'XOF';

  static const currencies = ['XOF', 'EUR', 'USD', 'NGN', 'GHS'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _bankController = TextEditingController(text: e?.bankName ?? '');
    _balanceController = TextEditingController(
      text: e != null ? e.initialBalance.toStringAsFixed(0) : '',
    );
    _currentBalanceController = TextEditingController(
      text: e != null ? e.currentBalance.toStringAsFixed(0) : '',
    );
    if (e != null) {
      _selectedType = e.type;
      _selectedCurrency = e.currency;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Modifier le compte' : 'Nouveau compte',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom du compte *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankController,
              decoration: const InputDecoration(labelText: 'Banque / Opérateur (optionnel)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type de compte'),
              items: AccountType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v ?? _selectedType),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isEditing ? 'Solde initial' : 'Solde de départ *',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Champ requis';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Nombre invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Devise'),
                    items: currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCurrency = v ?? _selectedCurrency),
                  ),
                ),
              ],
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentBalanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Corriger le solde actuel',
                  helperText: 'Modifie uniquement le solde affiché, sans toucher au solde de départ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Nombre invalide';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Enregistrer les modifications' : 'Créer le compte'),
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _confirmDelete(context),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Supprimer ce compte'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(AccountType type) {
    switch (type) {
      case AccountType.courant:
        return 'Compte courant';
      case AccountType.epargne:
        return 'Épargne';
      case AccountType.mobileMoney:
        return 'Mobile Money';
      case AccountType.especes:
        return 'Espèces';
      case AccountType.autre:
        return 'Autre';
    }
  }

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  final balance = double.parse(_balanceController.text.replaceAll(',', '.'));
  final actions = ref.read(accountActionsProvider);
  final now = DateTime.now();

  try {
    if (widget.existing == null) {
      await actions.create(Account(
        name: _nameController.text.trim(),
        bankName: _bankController.text.trim().isEmpty ? null : _bankController.text.trim(),
        type: _selectedType,
        currency: _selectedCurrency,
        initialBalance: balance,
        currentBalance: balance,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      final currentBalance = double.parse(_currentBalanceController.text.replaceAll(',', '.'));
      await actions.update(widget.existing!.copyWith(
        name: _nameController.text.trim(),
        bankName: _bankController.text.trim().isEmpty ? null : _bankController.text.trim(),
        type: _selectedType,
        currency: _selectedCurrency,
        initialBalance: balance,
        currentBalance: currentBalance,
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
    if (widget.existing?.id == null) return;
    final accountId = widget.existing!.id!;

    final repository = ref.read(accountRepositoryProvider);
    final hasLinkedData = await repository.hasLinkedData(accountId);

    if (!mounted) return;

    if (hasLinkedData) {
      final archived = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Compte non vide'),
          content: const Text(
            'Ce compte contient des transactions, dettes ou épargnes liées. '
            'Pour protéger tes données, il ne peut pas être supprimé définitivement. '
            'Veux-tu l\'archiver à la place ? (Il sera masqué de la liste principale, sans rien perdre.)',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Archiver')),
          ],
        ),
      );

      if (archived == true) {
        try {
          await ref.read(accountActionsProvider).archive(accountId);
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(accountActionsProvider).delete(accountId);
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
