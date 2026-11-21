import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_providers.dart';
import '../utils/loan_calculator.dart';
import '../utils/money.dart';
import '../../features/accounts/presentation/providers/account_providers.dart';
import '../../features/credits/data/models/credit_model.dart';
import '../../features/credits/domain/entities/credit.dart';
import '../../features/credits/presentation/providers/credit_providers.dart';
import '../../features/debts/domain/entities/debt.dart';
import '../../features/debts/presentation/providers/debt_providers.dart';
import '../../features/savings/presentation/providers/savings_providers.dart';
import '../../features/transactions/presentation/providers/transaction_providers.dart';
import 'ledger.dart';

/// Toutes les opérations financières saisissables en UNE seule fois.
enum OperationKind {
  revenu,
  depense,
  depot,
  retrait,
  transfert,
  epargne,
  achatCredit,
  creditRecu,
  detteRecue,
  creanceAccordee,
  rembCredit,
  rembDette,
  encaissementCreance,
}

/// Demande d'opération : seuls les champs utiles à la nature de l'opération
/// sont renseignés (le formulaire adapte les champs affichés).
class OperationRequest {
  final OperationKind kind;
  final double amount;
  final DateTime date;
  final String? description;
  final String currency;

  /// Compte principal (crédité, débité ou source selon l'opération).
  final int accountId;

  /// Compte destinataire (retrait, transfert, épargne).
  final int? toAccountId;
  final int? categoryId;

  /// Dette/créance concernée (remboursement, encaissement).
  final int? debtId;

  /// Crédit et échéance concernés (remboursement de crédit).
  final int? creditId;
  final int? installmentId;

  /// Objectif d'épargne alimenté (épargne).
  final int? savingsId;

  /// Tiers (dette, créance, achat à crédit).
  final String? counterparty;
  final DateTime? dueDate;

  /// Crédit contracté.
  final int durationMonths;
  final double interestRate;
  final double? monthlyPayment;

  const OperationRequest({
    required this.kind,
    required this.amount,
    required this.date,
    required this.accountId,
    this.description,
    this.currency = 'XOF',
    this.toAccountId,
    this.categoryId,
    this.debtId,
    this.creditId,
    this.installmentId,
    this.savingsId,
    this.counterparty,
    this.dueDate,
    this.durationMonths = 12,
    this.interestRate = 0,
    this.monthlyPayment,
  });
}

final operationServiceProvider = Provider<OperationService>((ref) => OperationService(ref));

class OperationService {
  final Ref _ref;
  OperationService(this._ref);

  Future<Database> get _db async => _ref.read(appDatabaseProvider).database;

  /// Exécute l'opération : une saisie, toutes les rubriques concernées sont
  /// mises à jour dans la même transaction SQL (tout ou rien).
  Future<void> execute(OperationRequest r) async {
    if (r.amount <= 0) throw ArgumentError('Le montant doit être supérieur à 0.');
    final cents = Money.toCents(r.amount);

    switch (r.kind) {
      case OperationKind.revenu:
      case OperationKind.depense:
        throw ArgumentError('Les revenus et dépenses simples passent par TransactionActions.');

      case OperationKind.depot:
        await _simple(r, cents, LedgerKind.depot, 1, r.description ?? 'Dépôt / ajout d’argent');
        break;

      case OperationKind.retrait:
        await _pair(r, cents, LedgerKind.retrait, 'Retrait');
        break;
      case OperationKind.transfert:
        await _pair(r, cents, LedgerKind.transfert, 'Transfert');
        break;
      case OperationKind.epargne:
        await _pair(r, cents, LedgerKind.epargne, 'Épargne');
        break;

      case OperationKind.detteRecue:
        await _debtOrigin(r, cents, DebtType.dette, LedgerKind.detteRecue, 1);
        break;
      case OperationKind.creanceAccordee:
        await _debtOrigin(r, cents, DebtType.creance, LedgerKind.creanceAccordee, -1);
        break;
      case OperationKind.achatCredit:
        await _purchaseOnCredit(r, cents);
        break;
      case OperationKind.creditRecu:
        await _creditOrigin(r);
        break;

      case OperationKind.rembDette:
      case OperationKind.encaissementCreance:
        await _debtPayment(r);
        break;
      case OperationKind.rembCredit:
        await _creditPayment(r);
        break;
    }
    _refreshAll();
  }

  // ---------------------------------------------------------------- simple

  Future<void> _simple(OperationRequest r, int cents, String kind, int sign, String label) async {
    final db = await _db;
    await db.transaction((txn) async {
      await Ledger.post(txn,
          accountId: r.accountId,
          signedCents: sign * cents,
          kind: kind,
          currency: r.currency,
          description: label,
          date: r.date);
    });
  }

  // ----------------------------------------------------------------- paire

  Future<void> _pair(OperationRequest r, int cents, String kind, String label) async {
    final to = r.toAccountId;
    if (to == null) throw ArgumentError('Choisis le compte destinataire.');
    if (to == r.accountId) {
      throw ArgumentError('Le compte source et le compte destinataire doivent être différents.');
    }
    final note = (r.description ?? '').trim();
    final text = note.isEmpty ? label : '$label — $note';
    final db = await _db;
    await db.transaction((txn) async {
      int? ref;
      if (kind == LedgerKind.epargne && r.savingsId != null) {
        // Alimente aussi l'objectif d'épargne choisi (sans toucher aux comptes :
        // le mouvement entre comptes est déjà porté par les deux écritures).
        final now = DateTime.now().toIso8601String();
        ref = await txn.insert('savings_transactions', {
          'savings_id': r.savingsId,
          'type': 'versement',
          'amount': cents,
          'date': r.date.toIso8601String(),
          'note': note.isEmpty ? null : note,
          'created_at': now,
        });
        await txn.rawUpdate(
          'UPDATE savings SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
          [cents, now, r.savingsId],
        );
      }
      final outId = await Ledger.post(txn,
          accountId: r.accountId,
          signedCents: -cents,
          kind: kind,
          refId: ref,
          currency: r.currency,
          description: text,
          date: r.date);
      await Ledger.post(txn,
          accountId: to,
          signedCents: cents,
          kind: kind,
          refId: ref,
          currency: r.currency,
          description: text,
          date: r.date,
          group: outId);
    });
  }

  // ------------------------------------------------------- dettes / crédits

  Future<int> _insertDebt(DatabaseExecutor txn, OperationRequest r, int cents, DebtType type) async {
    final now = DateTime.now().toIso8601String();
    return txn.insert('debts', {
      'type': type == DebtType.creance ? 'creance' : 'dette',
      'person_name': (r.counterparty ?? '').trim().isEmpty ? 'Non précisé' : r.counterparty!.trim(),
      'description': r.description,
      'total_amount': cents,
      'currency': r.currency,
      'account_id': r.accountId,
      'due_date': r.dueDate?.toIso8601String(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _debtOrigin(OperationRequest r, int cents, DebtType type, String kind, int sign) async {
    final db = await _db;
    await db.transaction((txn) async {
      final debtId = await _insertDebt(txn, r, cents, type);
      final who = (r.counterparty ?? '').trim();
      await Ledger.post(txn,
          accountId: r.accountId,
          signedCents: sign * cents,
          kind: kind,
          refId: debtId,
          currency: r.currency,
          description: '${LedgerKind.labels[kind]}${who.isEmpty ? '' : ' — $who'}',
          date: r.date);
    });
  }

  Future<void> _purchaseOnCredit(OperationRequest r, int cents) async {
    final db = await _db;
    await db.transaction((txn) async {
      final debtId = await _insertDebt(txn, r, cents, DebtType.dette);
      final who = (r.counterparty ?? '').trim();
      final label = (r.description ?? '').trim().isEmpty ? 'Achat à crédit' : 'Achat à crédit — ${r.description!.trim()}';
      // La dépense est réelle (comptée dans les statistiques) ; la contrepartie
      // neutre représente le crédit fournisseur : le solde du compte ne bouge
      // pas tant que la dette n'est pas remboursée.
      await Ledger.post(txn,
          accountId: r.accountId,
          signedCents: -cents,
          kind: LedgerKind.achatCredit,
          refId: debtId,
          categoryId: r.categoryId,
          neutral: false,
          currency: r.currency,
          description: label,
          date: r.date);
      await Ledger.post(txn,
          accountId: r.accountId,
          signedCents: cents,
          kind: LedgerKind.achatCreditDette,
          refId: debtId,
          currency: r.currency,
          description: 'Dette fournisseur${who.isEmpty ? '' : ' — $who'}',
          date: r.date);
    });
  }

  Future<void> _creditOrigin(OperationRequest r) async {
    final months = r.durationMonths < 1 ? 1 : r.durationMonths;
    final monthly = r.monthlyPayment ??
        calculateMonthlyPayment(
          principal: r.amount,
          annualRatePercent: r.interestRate,
          durationMonths: months,
        ) ??
        (r.amount / months);
    final now = DateTime.now();
    final name = (r.counterparty ?? '').trim().isEmpty ? 'Crédit' : r.counterparty!.trim();
    final credit = CreditModel(
      name: name,
      principalAmount: r.amount,
      interestRate: r.interestRate,
      startDate: r.date,
      durationMonths: months,
      monthlyPayment: monthly,
      accountId: r.accountId,
      currency: r.currency,
      status: CreditStatus.actif,
      notes: r.description,
      createdAt: now,
      updatedAt: now,
    );
    await _ref.read(creditDaoProvider).insertCreditWithSchedule(credit, receivePrincipal: true);
  }

  Future<void> _debtPayment(OperationRequest r) async {
    final id = r.debtId;
    if (id == null) throw ArgumentError('Choisis la dette ou la créance concernée.');
    final repo = _ref.read(debtRepositoryProvider);
    final debt = await repo.getDebtById(id);
    if (debt == null) throw StateError('Dette introuvable.');
    final paid = (await repo.getPaymentsForDebt(id)).fold<double>(0, (a, p) => a + p.amount);
    final remaining = debt.totalAmount - paid;
    if (r.amount > remaining + 0.0001) {
      throw ArgumentError('Le montant dépasse le reste dû (${remaining.toStringAsFixed(0)}).');
    }
    // Le paiement est imputé sur le compte choisi dans l'opération.
    final target = debt.copyWith(accountId: r.accountId);
    final now = DateTime.now();
    await _ref.read(debtActionsProvider).addPayment(
          DebtPayment(
            debtId: id,
            amount: r.amount,
            paymentDate: r.date,
            note: r.description,
            createdAt: now,
          ),
          target,
        );
  }

  Future<void> _creditPayment(OperationRequest r) async {
    final creditId = r.creditId;
    final instId = r.installmentId;
    if (creditId == null || instId == null) {
      throw ArgumentError('Choisis le crédit et l’échéance à régler.');
    }
    final repo = _ref.read(creditRepositoryProvider);
    final list = await repo.getInstallmentsForCredit(creditId);
    final inst = list.firstWhere((i) => i.id == instId, orElse: () => throw StateError('Échéance introuvable.'));
    await _ref.read(creditActionsProvider).markInstallmentPaid(inst.copyWith(paymentDate: r.date));
  }

  // --------------------------------------------------------- suppression

  /// Supprime une écriture du grand livre ET tout ce qu'elle a créé
  /// (dette, crédit, versement d'objectif...). Refuse si des remboursements
  /// existent déjà pour la dette/le crédit créé.
  Future<void> deleteLedgerEntry(int txId) async {
    final db = await _db;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [txId], limit: 1);
    if (rows.isEmpty) return;
    final row = rows.first;
    final kind = row['kind'] as String?;
    final ref = (row['ref_id'] as num?)?.toInt();

    switch (kind) {
      case LedgerKind.detteRecue:
      case LedgerKind.creanceAccordee:
      case LedgerKind.achatCredit:
      case LedgerKind.achatCreditDette:
        if (ref != null) await _ref.read(debtActionsProvider).delete(ref);
        break;
      case LedgerKind.creditRecu:
        if (ref != null) await _ref.read(creditActionsProvider).delete(ref);
        break;
      case LedgerKind.rembDette:
      case LedgerKind.encaissementCreance:
        if (ref != null) {
          final pay = await db.query('debt_payments', where: 'id = ?', whereArgs: [ref], limit: 1);
          if (pay.isNotEmpty) {
            final debtId = pay.first['debt_id'] as int;
            await _ref.read(debtActionsProvider).deletePayment(ref, debtId);
          }
        }
        break;
      case LedgerKind.rembCredit:
        if (ref != null) {
          final inst = await db.query('credit_installments', where: 'id = ?', whereArgs: [ref], limit: 1);
          if (inst.isNotEmpty) {
            final creditId = inst.first['credit_id'] as int;
            final list = await _ref.read(creditRepositoryProvider).getInstallmentsForCredit(creditId);
            final match = list.where((i) => i.id == ref);
            if (match.isNotEmpty) await _ref.read(creditActionsProvider).markInstallmentUnpaid(match.first);
          }
        }
        break;
      case LedgerKind.epargne:
      case LedgerKind.epargneObjectif:
        if (ref != null) {
          await db.transaction((txn) async {
            final mv = await txn.query('savings_transactions', where: 'id = ?', whereArgs: [ref], limit: 1);
            if (mv.isNotEmpty) {
              final signed = (mv.first['type'] == 'versement' ? 1 : -1) * (mv.first['amount'] as num).toInt();
              await txn.rawUpdate(
                'UPDATE savings SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
                [signed, DateTime.now().toIso8601String(), mv.first['savings_id']],
              );
              await txn.delete('savings_transactions', where: 'id = ?', whereArgs: [ref]);
            }
            await Ledger.unpost(txn, kinds: [LedgerKind.epargne, LedgerKind.epargneObjectif], refId: ref);
          });
        } else {
          await _deleteGroup(row);
        }
        break;
      default:
        await _deleteGroup(row);
    }
    _refreshAll();
  }

  Future<void> _deleteGroup(Map<String, Object?> row) async {
    final group = (row['transfer_group'] as num?)?.toInt();
    final db = await _db;
    if (group == null) return;
    final rows = await db.query('transactions', where: 'transfer_group = ?', whereArgs: [group]);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final x in rows) {
        final cents = (x['amount'] as num).toInt();
        final signed = x['type'] == 'revenu' ? cents : -cents;
        await txn.rawUpdate(
          'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
          [signed, now, x['account_id']],
        );
      }
      await txn.delete('transactions', where: 'transfer_group = ?', whereArgs: [group]);
    });
  }

  void _refreshAll() {
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(filteredTransactionsProvider);
    _ref.invalidate(monthlyIncomeProvider);
    _ref.invalidate(monthlyExpenseProvider);
    _ref.invalidate(accountsListProvider);
    _ref.invalidate(allAccountsIncludingArchivedProvider);
    _ref.invalidate(globalBalanceProvider);
    _ref.invalidate(debtsListProvider);
    _ref.invalidate(creditsListProvider);
    _ref.invalidate(savingsListProvider);
  }
}
