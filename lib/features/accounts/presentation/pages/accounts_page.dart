import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../entities/presentation/widgets/entity_selector_bar.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/entities/account.dart';
import '../providers/account_providers.dart';
import '../providers/balance_alerts.dart';
import '../widgets/accounts_overview.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(
  leading: const AppBackButton(),
  title: const Text('Mes Comptes'),
  actions: [
    const AppMenuButton(),
    IconButton(
      icon: const Icon(Icons.playlist_add_check),
      tooltip: 'Créer mes comptes types',
      onPressed: () => _createStandardAccounts(context, ref),
    ),
    IconButton(
      icon: const Icon(Icons.notifications_active_outlined),
      tooltip: 'Seuils d\u2019alerte des soldes',
      onPressed: () => _showThresholds(context, ref),
    ),
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
      body: Column(
        children: [
          const EntitySelectorBar(),
          Expanded(
            child: accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text(AppErrorMessage.friendly(err))),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const _EmptyState();
                }
                return AccountsOverview(
                  accounts: accounts,
                  onOpen: (account) => _showAccountForm(context, ref, existing: account),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Crée les comptes du cahier des charges qui n'existent pas encore
  /// (soldes à 0, à ajuster ensuite) : Agent liquide (caisse principale),
  /// Banque courante, Banque secondaire, Moov, MTN.
  Future<void> _createStandardAccounts(BuildContext context, WidgetRef ref) async {
    final existing = (await ref.read(accountsListProvider.future)).map((a) => a.name.trim().toLowerCase()).toSet();
    final now = DateTime.now();
    Account mk(String name, AccountType type, {String? role}) => Account(
          name: name,
          type: type,
          initialBalance: 0,
          currentBalance: 0,
          role: role,
          createdAt: now,
          updatedAt: now,
        );
    final wanted = [
      mk('Agent liquide', AccountType.especes, role: 'caisse'),
      mk('Banque courante', AccountType.courant),
      mk('Banque secondaire', AccountType.courant),
      mk('Moov', AccountType.mobileMoney, role: 'epargne'),
      mk('MTN', AccountType.mobileMoney),
    ].where((a) => !existing.contains(a.name.toLowerCase())).toList();
    if (!context.mounted) return;
    if (wanted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tes comptes types existent déjà.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer mes comptes types ?'),
        content: Text('Seront créés (solde 0, à ajuster ensuite) :\n${wanted.map((a) => '• ${a.name}').join('\n')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    for (final a in wanted) {
      await ref.read(accountActionsProvider).create(a);
    }
  }

  Future<void> _showThresholds(BuildContext context, WidgetRef ref) async {
    final current = ref.read(balanceThresholdsProvider);
    final warn = TextEditingController(text: current.warning.toStringAsFixed(0));
    final crit = TextEditingController(text: current.critical.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seuils d\u2019alerte des soldes'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sous le seuil « faible », le compte passe en orange ; sous le seuil « critique », il passe en rouge (graphique, cercle et alerte). Chaque compte peut avoir ses propres seuils dans sa fiche.'),
          const SizedBox(height: 12),
          TextField(controller: warn, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seuil solde faible (orange)')),
          const SizedBox(height: 8),
          TextField(controller: crit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seuil solde critique (rouge)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true) {
      final w = double.tryParse(warn.text.replaceAll(',', '.'));
      final c = double.tryParse(crit.text.replaceAll(',', '.'));
      if (w != null && c != null) {
        await ref.read(balanceThresholdsProvider.notifier).set(warning: w, critical: c);
      }
    }
    warn.dispose();
    crit.dispose();
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
  late final TextEditingController _warnController;
  late final TextEditingController _critController;
  String? _role;
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
    _warnController = TextEditingController(text: e?.alertWarning?.toStringAsFixed(0) ?? '');
    _critController = TextEditingController(text: e?.alertCritical?.toStringAsFixed(0) ?? '');
    if (e != null) {
      _selectedType = e.type;
      _selectedCurrency = e.currency;
      _role = e.role;
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Rôle du compte',
                helperText: 'Caisse : reçoit les retraits Mobile Money. Épargne : reçoit les versements d\u2019épargne.',
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Aucun rôle particulier')),
                DropdownMenuItem<String?>(value: 'caisse', child: Text('Caisse principale (Agent liquide)')),
                DropdownMenuItem<String?>(value: 'epargne', child: Text('Compte d\u2019épargne immédiate')),
              ],
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _warnController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Alerte faible (orange)', helperText: 'Vide = seuil par défaut'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _critController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Alerte critique (rouge)', helperText: 'Vide = seuil par défaut'),
                ),
              ),
            ]),
            if (isEditing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentBalanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Ajuster le solde actuel',
                  helperText: 'L\u2019écart crée une transaction « Correction de solde » visible dans l\u2019historique',
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
    if (_role != null) {
      // Un seul compte par rôle (caisse principale / épargne immédiate).
      final db = await ref.read(appDatabaseProvider).database;
      await db.rawUpdate('UPDATE accounts SET role = NULL WHERE role = ? AND id IS NOT ?', [_role, widget.existing?.id]);
    }
    if (widget.existing == null) {
      await actions.create(Account(
        name: _nameController.text.trim(),
        bankName: _bankController.text.trim().isEmpty ? null : _bankController.text.trim(),
        type: _selectedType,
        currency: _selectedCurrency,
        initialBalance: balance,
        currentBalance: balance,
        role: _role,
        alertWarning: double.tryParse(_warnController.text.replaceAll(',', '.')),
        alertCritical: double.tryParse(_critController.text.replaceAll(',', '.')),
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      final currentBalance = double.parse(_currentBalanceController.text.replaceAll(',', '.'));
      final old = widget.existing!;
      await actions.update(Account(
        id: old.id,
        name: _nameController.text.trim(),
        bankName: _bankController.text.trim().isEmpty ? null : _bankController.text.trim(),
        type: _selectedType,
        currency: _selectedCurrency,
        initialBalance: balance,
        currentBalance: old.currentBalance,
        color: old.color,
        icon: old.icon,
        isArchived: old.isArchived,
        entityId: old.entityId,
        role: _role,
        alertWarning: double.tryParse(_warnController.text.replaceAll(',', '.')),
        alertCritical: double.tryParse(_critController.text.replaceAll(',', '.')),
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      ));
      // Un écart de solde est tracé par une transaction de correction visible
      // dans l'historique (au lieu d'écraser silencieusement le solde).
      final diff = currentBalance - widget.existing!.currentBalance;
      if (diff.abs() >= 0.005) {
        await ref.read(transactionActionsProvider).create(FinancialTransaction(
          accountId: widget.existing!.id!,
          type: diff > 0 ? TransactionType.revenu : TransactionType.depense,
          amount: diff.abs(),
          currency: _selectedCurrency,
          description: 'Correction de solde',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    if (mounted) Navigator.of(context).pop();
  } catch (e) {
    if (mounted) {
      AppErrorMessage.showSnackBar(context, e);
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
            AppErrorMessage.showSnackBar(context, e);
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
          AppErrorMessage.showSnackBar(context, e);
        }
      }
    }
  }
} 
