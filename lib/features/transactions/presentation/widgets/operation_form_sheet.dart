import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ledger/operation_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/utils/loan_calculator.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../credits/domain/entities/credit.dart';
import '../../../credits/domain/entities/credit_installment.dart';
import '../../../credits/presentation/providers/credit_providers.dart';
import '../../../debts/domain/entities/debt.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../../savings/presentation/providers/savings_providers.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transaction_providers.dart';

/// Une opération proposée dans le formulaire « Nouvelle opération ».
class _Op {
  final String label;
  final IconData icon;
  final OperationKind kind;

  /// Catégorie pré-sélectionnée (créée au besoin) pour les dépenses courantes.
  final String? presetCategory;
  const _Op(this.label, this.icon, this.kind, {this.presetCategory});
}

const _groups = <(String, List<_Op>)>[
  (
    'Entrées',
    [
      _Op('Revenu', Icons.south_west, OperationKind.revenu),
      _Op('Dépôt / ajout d’argent', Icons.add_card, OperationKind.depot),
      _Op('Encaissement de créance', Icons.request_quote_outlined, OperationKind.encaissementCreance),
    ]
  ),
  (
    'Dépenses',
    [
      _Op('Dépense courante', Icons.north_east, OperationKind.depense, presetCategory: 'Dépenses quotidiennes'),
      _Op('Achat', Icons.shopping_bag_outlined, OperationKind.depense, presetCategory: 'Achat'),
      _Op('Achat à crédit', Icons.credit_score_outlined, OperationKind.achatCredit, presetCategory: 'Achat'),
      _Op('Loyer', Icons.home_outlined, OperationKind.depense, presetCategory: 'Loyer'),
      _Op('Transport', Icons.directions_bus_outlined, OperationKind.depense, presetCategory: 'Transport'),
      _Op('Alimentation', Icons.restaurant_outlined, OperationKind.depense, presetCategory: 'Alimentation'),
      _Op('Paiement de facture', Icons.receipt_long_outlined, OperationKind.depense, presetCategory: 'Factures'),
      _Op('Autre dépense', Icons.more_horiz, OperationKind.depense),
    ]
  ),
  (
    'Mouvements entre comptes',
    [
      _Op('Retrait', Icons.atm_outlined, OperationKind.retrait),
      _Op('Transfert', Icons.swap_horiz, OperationKind.transfert),
      _Op('Épargne', Icons.savings_outlined, OperationKind.epargne),
    ]
  ),
  (
    'Crédits et dettes',
    [
      _Op('Crédit contracté', Icons.account_balance_outlined, OperationKind.creditRecu),
      _Op('Dette contractée', Icons.arrow_circle_down_outlined, OperationKind.detteRecue),
      _Op('Créance accordée', Icons.arrow_circle_up_outlined, OperationKind.creanceAccordee),
      _Op('Remboursement de crédit', Icons.event_available_outlined, OperationKind.rembCredit),
      _Op('Remboursement de dette', Icons.payments_outlined, OperationKind.rembDette),
    ]
  ),
];

/// Formulaire unique de saisie : les champs s'adaptent à la nature de
/// l'opération, et une seule saisie met à jour comptes, épargnes, crédits,
/// dettes, statistiques et historique.
class OperationFormSheet extends ConsumerStatefulWidget {
  const OperationFormSheet({super.key});

  @override
  ConsumerState<OperationFormSheet> createState() => _OperationFormSheetState();
}

class _OperationFormSheetState extends ConsumerState<OperationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _counterparty = TextEditingController();
  final _duration = TextEditingController(text: '12');
  final _rate = TextEditingController(text: '0');
  final _monthly = TextEditingController();

  _Op _op = _groups[1].$2.first;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  int? _debtId;
  int? _creditId;
  int? _installmentId;
  int? _savingsId;
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  bool _saving = false;

  OperationKind get _kind => _op.kind;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _counterparty.dispose();
    _duration.dispose();
    _rate.dispose();
    _monthly.dispose();
    super.dispose();
  }

  void _select(_Op op, List<Account> accounts) {
    setState(() {
      _op = op;
      _categoryId = null;
      _debtId = null;
      _creditId = null;
      _installmentId = null;
      _savingsId = null;
      _toAccountId = null;
      _applyDefaults(accounts);
    });
  }

  Account? _byRole(List<Account> accounts, String role) {
    final m = accounts.where((a) => a.role == role && !a.isArchived).toList();
    return m.isEmpty ? null : m.first;
  }

  /// Pré-remplit intelligemment les comptes selon l'opération.
  void _applyDefaults(List<Account> accounts) {
    final active = accounts.where((a) => !a.isArchived).toList();
    if (active.isEmpty) return;
    final caisse = _byRole(active, 'caisse');
    final epargne = _byRole(active, 'epargne');
    switch (_kind) {
      case OperationKind.retrait:
        final momo = active.where((a) => a.type == AccountType.mobileMoney).toList();
        _accountId = (momo.isNotEmpty ? momo.first : active.first).id;
        _toAccountId = (caisse ?? active.firstWhere((a) => a.id != _accountId, orElse: () => active.first)).id;
        break;
      case OperationKind.epargne:
        _toAccountId = (epargne ?? active.firstWhere((a) => a.type == AccountType.epargne, orElse: () => active.first)).id;
        final src = active.where((a) => a.id != _toAccountId).toList();
        _accountId = (caisse != null && caisse.id != _toAccountId ? caisse : (src.isEmpty ? active.first : src.first)).id;
        break;
      case OperationKind.transfert:
        _accountId ??= active.first.id;
        final other = active.where((a) => a.id != _accountId).toList();
        _toAccountId = other.isEmpty ? null : other.first.id;
        break;
      default:
        _accountId ??= (caisse ?? active.first).id;
    }
    if (_accountId == _toAccountId) {
      final other = active.where((a) => a.id != _accountId).toList();
      _toAccountId = other.isEmpty ? null : other.first.id;
    }
  }

  String _accountLabel() {
    switch (_kind) {
      case OperationKind.retrait:
        return 'Compte débité (retrait depuis) *';
      case OperationKind.transfert:
        return 'Compte source *';
      case OperationKind.epargne:
        return 'Compte qui verse l’épargne *';
      case OperationKind.rembDette:
      case OperationKind.rembCredit:
        return 'Compte qui paie *';
      case OperationKind.encaissementCreance:
        return 'Compte qui encaisse *';
      case OperationKind.creditRecu:
      case OperationKind.detteRecue:
        return 'Compte qui reçoit l’argent *';
      case OperationKind.creanceAccordee:
        return 'Compte qui prête l’argent *';
      case OperationKind.depot:
        return 'Compte à créditer *';
      case OperationKind.revenu:
        return 'Compte à créditer *';
      default:
        return 'Compte à débiter *';
    }
  }

  String _toLabel() {
    switch (_kind) {
      case OperationKind.retrait:
        return 'Compte crédité (reçoit l’argent) *';
      case OperationKind.epargne:
        return 'Compte d’épargne crédité *';
      default:
        return 'Compte destinataire *';
    }
  }

  bool get _needsTo =>
      _kind == OperationKind.retrait || _kind == OperationKind.transfert || _kind == OperationKind.epargne;

  bool get _needsCounterparty =>
      _kind == OperationKind.detteRecue ||
      _kind == OperationKind.creanceAccordee ||
      _kind == OperationKind.achatCredit ||
      _kind == OperationKind.creditRecu;

  String _counterpartyLabel() {
    switch (_kind) {
      case OperationKind.creditRecu:
        return 'Nom du crédit ou organisme *';
      case OperationKind.creanceAccordee:
        return 'Personne qui te doit l’argent *';
      case OperationKind.achatCredit:
        return 'Fournisseur / vendeur *';
      default:
        return 'Personne ou organisme à qui tu dois *';
    }
  }

  void _updateSuggestedMonthly() {
    final v = calculateMonthlyPayment(
      principal: double.tryParse(_amount.text.replaceAll(',', '.')),
      annualRatePercent: double.tryParse(_rate.text.replaceAll(',', '.')),
      durationMonths: int.tryParse(_duration.text),
    );
    if (v != null) _monthly.text = v.toStringAsFixed(0);
  }

  Future<void> _submit(List<Account> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;
    final amount = double.parse(_amount.text.replaceAll(',', '.'));
    final account = accounts.firstWhere((a) => a.id == _accountId);
    final desc = _description.text.trim().isEmpty ? null : _description.text.trim();
    setState(() => _saving = true);
    try {
      final service = ref.read(operationServiceProvider);
      if (_kind == OperationKind.revenu || _kind == OperationKind.depense) {
        int? categoryId = _categoryId;
        if (_op.presetCategory != null && categoryId == null) {
          categoryId = await service.ensureCategory(_op.presetCategory!, 'depense');
        }
        final now = DateTime.now();
        await ref.read(transactionActionsProvider).create(FinancialTransaction(
              accountId: _accountId!,
              categoryId: categoryId,
              type: _kind == OperationKind.revenu ? TransactionType.revenu : TransactionType.depense,
              amount: amount,
              currency: account.currency,
              description: desc ?? (_op.presetCategory == null ? null : _op.label),
              transactionDate: _date,
              createdAt: now,
              updatedAt: now,
            ));
      } else {
        int? categoryId;
        if (_kind == OperationKind.achatCredit && _op.presetCategory != null) {
          categoryId = await service.ensureCategory(_op.presetCategory!, 'depense');
        }
        await service.execute(OperationRequest(
          kind: _kind,
          amount: amount,
          date: _date,
          accountId: _accountId!,
          toAccountId: _toAccountId,
          categoryId: categoryId,
          description: desc,
          currency: account.currency,
          debtId: _debtId,
          creditId: _creditId,
          installmentId: _installmentId,
          savingsId: _savingsId,
          counterparty: _counterparty.text,
          dueDate: _dueDate,
          durationMonths: int.tryParse(_duration.text) ?? 12,
          interestRate: double.tryParse(_rate.text.replaceAll(',', '.')) ?? 0,
          monthlyPayment: double.tryParse(_monthly.text.replaceAll(',', '.')),
        ));
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opération enregistrée — toutes les rubriques sont à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppErrorMessage.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(allAccountsIncludingArchivedProvider);
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: accountsAsync.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (accounts) {
          final active = accounts.where((a) => !a.isArchived).toList();
          if (active.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Crée d’abord un compte avant d’enregistrer une opération.'),
            );
          }
          if (_accountId == null) _applyDefaults(accounts);
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nouvelle opération', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Une seule saisie : tout est mis à jour automatiquement.',
                      style: TextStyle(color: colors.muted, fontSize: 12)),
                  const SizedBox(height: 12),
                  for (final g in _groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(g.$1, style: TextStyle(color: colors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final o in g.$2)
                        ChoiceChip(
                          avatar: Icon(o.icon, size: 16),
                          label: Text(o.label),
                          selected: identical(_op, o),
                          onSelected: (_) => _select(o, accounts),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant *',
                      suffixText: accounts.firstWhere((a) => a.id == _accountId, orElse: () => active.first).currency,
                    ),
                    onChanged: (_) {
                      if (_kind == OperationKind.creditRecu) setState(_updateSuggestedMonthly);
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Champ requis';
                      final p = double.tryParse(v.replaceAll(',', '.'));
                      if (p == null || p <= 0) return 'Montant invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ..._accountFields(active),
                  ..._specificFields(active),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Description (optionnel)'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  _effectSummary(accounts, scheme),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : () => _submit(accounts),
                    child: Text(_saving ? 'Enregistrement…' : 'Enregistrer l’opération'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _accountFields(List<Account> active) {
    Widget dropdown(String label, int? value, ValueChanged<int?> onChanged, {Set<int?> exclude = const {}}) {
      final items = active.where((a) => !exclude.contains(a.id)).toList();
      return DropdownButtonFormField<int>(
        value: items.any((a) => a.id == value) ? value : null,
        decoration: InputDecoration(labelText: label),
        isExpanded: true,
        items: [
          for (final a in items)
            DropdownMenuItem(
              value: a.id,
              child: Text('${a.name} · ${AppFormat.currency(symbol: a.currency, decimalDigits: 0).format(a.currentBalance)}',
                  overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
        validator: (v) => v == null ? 'Sélectionne un compte' : null,
      );
    }

    return [
      dropdown(_accountLabel(), _accountId, (v) => setState(() {
            _accountId = v;
            if (_toAccountId == v) _toAccountId = null;
          })),
      if (_needsTo) ...[
        const SizedBox(height: 12),
        dropdown(_toLabel(), _toAccountId, (v) => setState(() => _toAccountId = v), exclude: {_accountId}),
      ],
    ];
  }

  List<Widget> _specificFields(List<Account> active) {
    final out = <Widget>[];
    // Catégorie (revenus et dépenses libres)
    if (_kind == OperationKind.revenu || (_kind == OperationKind.depense && _op.presetCategory == null)) {
      final cats = _kind == OperationKind.revenu
          ? ref.watch(incomeCategoriesProvider)
          : ref.watch(expenseCategoriesProvider);
      out.add(const SizedBox(height: 12));
      out.add(cats.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (List<AppCategory> list) => DropdownButtonFormField<int>(
          value: list.any((c) => c.id == _categoryId) ? _categoryId : null,
          decoration: const InputDecoration(labelText: 'Catégorie (optionnel)'),
          items: [for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
      ));
    }

    if (_needsCounterparty) {
      out.add(const SizedBox(height: 12));
      out.add(TextFormField(
        controller: _counterparty,
        decoration: InputDecoration(labelText: _counterpartyLabel()),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
      ));
    }

    if (_kind == OperationKind.detteRecue ||
        _kind == OperationKind.creanceAccordee ||
        _kind == OperationKind.achatCredit) {
      out.add(ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Échéance (optionnel)'),
        subtitle: Text(_dueDate == null ? 'Aucune' : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
        trailing: const Icon(Icons.event, size: 18),
        onTap: () async {
          final p = await showDatePicker(
            context: context,
            initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (p != null) setState(() => _dueDate = p);
        },
      ));
    }

    if (_kind == OperationKind.creditRecu) {
      out.add(const SizedBox(height: 4));
      out.add(Row(children: [
        Expanded(
          child: TextFormField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Durée (mois) *'),
            onChanged: (_) => setState(_updateSuggestedMonthly),
            validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Durée invalide' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Taux annuel (%)'),
            onChanged: (_) => setState(_updateSuggestedMonthly),
          ),
        ),
      ]));
      out.add(const SizedBox(height: 12));
      out.add(TextFormField(
        controller: _monthly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Mensualité (calculée, modifiable)'),
      ));
    }

    if (_kind == OperationKind.rembDette || _kind == OperationKind.encaissementCreance) {
      final wanted = _kind == OperationKind.rembDette ? DebtType.dette : DebtType.creance;
      final debts = ref.watch(debtsListProvider);
      out.add(const SizedBox(height: 12));
      out.add(debts.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (List<Debt> list) {
          final open = list.where((d) => d.type == wanted && !d.isSettled).toList();
          if (open.isEmpty) {
            return Text(wanted == DebtType.dette
                ? 'Aucune dette en cours à rembourser.'
                : 'Aucune créance en cours à encaisser.');
          }
          return DropdownButtonFormField<int>(
            value: open.any((d) => d.id == _debtId) ? _debtId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: wanted == DebtType.dette ? 'Dette concernée *' : 'Créance concernée *'),
            items: [
              for (final d in open)
                DropdownMenuItem(
                  value: d.id,
                  child: Text(
                    '${d.personName} · reste ${AppFormat.currency(symbol: d.currency, decimalDigits: 0).format(d.remainingAmount)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _debtId = v;
              final d = open.firstWhere((x) => x.id == v);
              _amount.text = d.remainingAmount.toStringAsFixed(0);
            }),
            validator: (v) => v == null ? 'Sélectionne la dette' : null,
          );
        },
      ));
    }

    if (_kind == OperationKind.rembCredit) {
      final credits = ref.watch(creditsListProvider);
      out.add(const SizedBox(height: 12));
      out.add(credits.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (List<Credit> list) {
          final open = list.where((c) => c.status == CreditStatus.actif).toList();
          if (open.isEmpty) return const Text('Aucun crédit en cours.');
          return DropdownButtonFormField<int>(
            value: open.any((c) => c.id == _creditId) ? _creditId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Crédit concerné *'),
            items: [for (final c in open) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() {
              _creditId = v;
              _installmentId = null;
            }),
            validator: (v) => v == null ? 'Sélectionne le crédit' : null,
          );
        },
      ));
      if (_creditId != null) {
        final inst = ref.watch(creditInstallmentsProvider(_creditId!));
        out.add(const SizedBox(height: 12));
        out.add(inst.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(AppErrorMessage.friendly(e)),
          data: (List<CreditInstallment> list) {
            final pending = list.where((i) => i.status != InstallmentStatus.payee).toList();
            if (pending.isEmpty) return const Text('Toutes les échéances sont payées.');
            return DropdownButtonFormField<int>(
              value: pending.any((i) => i.id == _installmentId) ? _installmentId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Échéance à régler *'),
              items: [
                for (final i in pending)
                  DropdownMenuItem(
                    value: i.id,
                    child: Text(
                      '${i.dueDate.day}/${i.dueDate.month}/${i.dueDate.year} · ${i.amount.toStringAsFixed(0)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                _installmentId = v;
                final i = pending.firstWhere((x) => x.id == v);
                _amount.text = i.amount.toStringAsFixed(0);
              }),
              validator: (v) => v == null ? 'Sélectionne l’échéance' : null,
            );
          },
        ));
      }
    }

    if (_kind == OperationKind.epargne) {
      final goals = ref.watch(savingsListProvider);
      out.add(const SizedBox(height: 12));
      out.add(goals.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(AppErrorMessage.friendly(e)),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return DropdownButtonFormField<int?>(
            value: list.any((g) => g.id == _savingsId) ? _savingsId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Objectif d’épargne alimenté (optionnel)'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Aucun objectif précis')),
              for (final g in list) DropdownMenuItem<int?>(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _savingsId = v),
          );
        },
      ));
    }
    return out;
  }

  /// Résumé en clair de ce que l'opération va modifier.
  Widget _effectSummary(List<Account> accounts, ColorScheme scheme) {
    String name(int? id) => accounts.where((a) => a.id == id).map((a) => a.name).firstOrNull ?? '…';
    final from = name(_accountId);
    final to = name(_toAccountId);
    String text;
    switch (_kind) {
      case OperationKind.revenu:
      case OperationKind.depot:
        text = '$from sera crédité.';
        break;
      case OperationKind.depense:
        text = '$from sera débité.';
        break;
      case OperationKind.retrait:
      case OperationKind.transfert:
      case OperationKind.epargne:
        text = '$from sera débité et $to crédité du même montant (pas compté comme revenu ni dépense).';
        break;
      case OperationKind.achatCredit:
        text = 'La dépense est enregistrée, une dette fournisseur est créée dans Dettes ; $from ne bouge pas avant le remboursement.';
        break;
      case OperationKind.creditRecu:
        text = '$from sera crédité, le crédit et son échéancier apparaissent dans Crédits.';
        break;
      case OperationKind.detteRecue:
        text = '$from sera crédité, la dette apparaît dans Dettes.';
        break;
      case OperationKind.creanceAccordee:
        text = '$from sera débité, la créance apparaît dans Dettes.';
        break;
      case OperationKind.rembCredit:
        text = '$from sera débité, l’échéance passe à « payée » dans Crédits.';
        break;
      case OperationKind.rembDette:
        text = '$from sera débité, le reste dû de la dette diminue (soldée à 0).';
        break;
      case OperationKind.encaissementCreance:
        text = '$from sera crédité, le reste à encaisser de la créance diminue.';
        break;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.sync, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}
