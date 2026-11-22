import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../credits/domain/entities/credit.dart';
import '../../../credits/domain/entities/credit_installment.dart';
import '../../../credits/presentation/providers/credit_providers.dart';
import '../../../debts/domain/entities/debt.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../savings/domain/entities/savings.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import 'insights_providers.dart';
import '../../../savings/presentation/providers/savings_providers.dart';

class SavingsSummary {
  final String currency;
  final double total;
  final double targets; // somme des objectifs des enveloppes avec objectif
  final double targetedSaved; // épargné dans ces enveloppes
  final int count;
  final List<double> evolution; // total cumulé après chaque mouvement
  const SavingsSummary(this.currency, this.total, this.targets, this.targetedSaved, this.count, this.evolution);

  double get ratio => targets <= 0 ? 0 : (targetedSaved / targets).clamp(0.0, 1.0).toDouble();
}

final savingsSummaryProvider = FutureProvider.autoDispose<SavingsSummary>((ref) async {
  final main = await ref.watch(mainCurrencyProvider.future);
  final list = (await ref.watch(savingsListProvider.future)).where((s) => s.currency == main).toList();
  final total = list.fold<double>(0, (a, s) => a + s.currentBalance);
  final targeted = list.where((s) => s.hasTarget);
  final targets = targeted.fold<double>(0, (a, s) => a + s.targetAmount!);
  final targetedSaved = targeted.fold<double>(0, (a, s) => a + s.currentBalance);

  final moves = <SavingsTransaction>[];
  for (final s in list) {
    if (s.id == null) continue;
    moves.addAll(await ref.watch(savingsTransactionsProvider(s.id!).future));
  }
  moves.sort((a, b) => a.date.compareTo(b.date));
  var run = 0.0;
  final evolution = <double>[];
  for (final m in moves) {
    run += m.signedAmount;
    evolution.add(run);
  }
  return SavingsSummary(main, total, targets, targetedSaved, list.length, evolution);
});

class CreditsSummary {
  final String currency;
  final double borrowed;
  final double repaid;
  final double owed;
  final double monthly;
  final int active;
  const CreditsSummary(this.currency, this.borrowed, this.repaid, this.owed, this.monthly, this.active);

  double get ratio => (repaid + owed) <= 0 ? 0 : (repaid / (repaid + owed)).clamp(0.0, 1.0).toDouble();
}

final creditsSummaryProvider = FutureProvider.autoDispose<CreditsSummary>((ref) async {
  final main = await ref.watch(mainCurrencyProvider.future);
  final repo = ref.watch(creditRepositoryProvider);
  final credits = (await ref.watch(creditsListProvider.future)).where((c) => c.currency == main).toList();
  var borrowed = 0.0, repaid = 0.0, owed = 0.0, monthly = 0.0;
  var active = 0;
  for (final Credit c in credits) {
    borrowed += c.principalAmount;
    if (c.id == null) continue;
    final inst = await repo.getInstallmentsForCredit(c.id!);
    repaid += inst.where((i) => i.status == InstallmentStatus.payee).fold<double>(0, (a, i) => a + i.amount);
    owed += inst.where((i) => i.status != InstallmentStatus.payee).fold<double>(0, (a, i) => a + i.amount);
    if (c.status == CreditStatus.actif) {
      active++;
      monthly += c.monthlyPayment;
    }
  }
  return CreditsSummary(main, borrowed, repaid, owed, monthly, active);
});

class DebtsSummary {
  final String currency;
  final double debtsTotal;
  final double debtsRemaining;
  final double receivablesTotal;
  final double receivablesRemaining;
  const DebtsSummary(this.currency, this.debtsTotal, this.debtsRemaining, this.receivablesTotal, this.receivablesRemaining);

  /// Part déjà réglée (dettes et créances confondues).
  double get ratio {
    final total = debtsTotal + receivablesTotal;
    if (total <= 0) return 0;
    return (1 - (debtsRemaining + receivablesRemaining) / total).clamp(0.0, 1.0).toDouble();
  }
}

final debtsSummaryProvider = FutureProvider.autoDispose<DebtsSummary>((ref) async {
  final main = await ref.watch(mainCurrencyProvider.future);
  final all = (await ref.watch(debtsListProvider.future)).where((d) => d.currency == main);
  double sum(Iterable<Debt> l, double Function(Debt) f) => l.fold<double>(0, (a, d) => a + f(d));
  final dettes = all.where((d) => d.type == DebtType.dette);
  final creances = all.where((d) => d.type == DebtType.creance);
  return DebtsSummary(
    main,
    sum(dettes, (d) => d.totalAmount),
    sum(dettes, (d) => d.remainingAmount < 0 ? 0 : d.remainingAmount),
    sum(creances, (d) => d.totalAmount),
    sum(creances, (d) => d.remainingAmount < 0 ? 0 : d.remainingAmount),
  );
});


/// Épargne immédiate : le compte au rôle « épargne » (ou, à défaut, « Moov »),
/// son évolution et ses dernières opérations.
class ImmediateSavings {
  final Account account;
  final List<double> evolution;
  final List<FinancialTransaction> operations;
  const ImmediateSavings(this.account, this.evolution, this.operations);
}

final immediateSavingsProvider = FutureProvider.autoDispose<ImmediateSavings?>((ref) async {
  final accounts = await ref.watch(accountsListProvider.future);
  Account? acc;
  for (final a in accounts) {
    if (a.role == 'epargne') {
      acc = a;
      break;
    }
  }
  acc ??= accounts.where((a) => a.name.trim().toLowerCase() == 'moov').cast<Account?>().firstOrNull;
  if (acc == null || acc.id == null) return null;
  final hist = await ref.watch(accountHistoriesProvider.future);
  final h = hist.where((x) => x.account.id == acc!.id).toList();
  final ops = await ref.watch(transactionRepositoryProvider).getTransactions(accountId: acc.id, limit: 12);
  return ImmediateSavings(acc, h.isEmpty ? const [] : h.first.values, ops);
});
