import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/presentation/providers/budget_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../credits/domain/entities/credit.dart';
import '../../../credits/presentation/providers/credit_providers.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../../savings/presentation/providers/savings_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

/// Période d'analyse des graphiques (Accueil et Statistiques).
enum InsightRange { week, month, quarter, semester, year }

extension InsightRangeInfo on InsightRange {
  String get label => const ['1S', '1M', '3M', '6M', '1A'][index];
  int get days => const [7, 30, 90, 180, 365][index];
}

final insightRangeProvider = StateProvider<InsightRange>((ref) => InsightRange.semester);

/// Historique de solde d'un compte, reconstitué à partir de ses écritures.
class AccountHistory {
  final Account account;
  final List<double> values;
  const AccountHistory(this.account, this.values);

  double get first => values.isEmpty ? 0 : values.first;
  double get last => values.isEmpty ? 0 : values.last;
  double get changePct {
    if (values.length < 2 || first.abs() < 1e-9) return 0;
    return (last - first) / first.abs() * 100;
  }
}

const int kSeriesPoints = 24;

/// Reconstitue le solde d'un compte à `kSeriesPoints` dates régulières :
/// solde(t) = solde actuel − somme des écritures postérieures à t.
List<double> reconstructBalances({
  required double currentBalance,
  required List<FinancialTransaction> txs,
  required DateTime start,
  required DateTime end,
  int points = kSeriesPoints,
}) {
  final span = end.difference(start).inMilliseconds;
  final result = <double>[];
  for (var i = 0; i < points; i++) {
    final t = start.add(Duration(milliseconds: (span * i / (points - 1)).round()));
    var after = 0.0;
    for (final tx in txs) {
      if (tx.transactionDate.isAfter(t)) after += tx.signedAmount;
    }
    result.add(currentBalance - after);
  }
  return result;
}

final accountHistoriesProvider = FutureProvider.autoDispose<List<AccountHistory>>((ref) async {
  final accounts = await ref.watch(accountsListProvider.future);
  final range = ref.watch(insightRangeProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final end = DateTime.now();
  final start = end.subtract(Duration(days: range.days));
  final out = <AccountHistory>[];
  for (final a in accounts) {
    if (a.id == null) continue;
    final txs = await repo.getTransactions(accountId: a.id, from: start, limit: 20000);
    out.add(AccountHistory(
      a,
      reconstructBalances(currentBalance: a.currentBalance, txs: txs, start: start, end: end),
    ));
  }
  return out;
});

/// Courbe du patrimoine (somme des comptes de la devise principale).
final netWorthSeriesProvider = FutureProvider.autoDispose<List<double>>((ref) async {
  final hist = await ref.watch(accountHistoriesProvider.future);
  final main = await ref.watch(mainCurrencyProvider.future);
  final main1 = hist.where((h) => h.account.currency == main).toList();
  if (main1.isEmpty) return const [];
  return List<double>.generate(kSeriesPoints, (i) => main1.fold<double>(0, (s, h) => s + h.values[i]));
});

/// Un indicateur de suivi (cercle) : valeur 0..1 et texte explicatif.
class RingMetric {
  final String label;
  final double ratio;
  final String detail;
  const RingMetric(this.label, this.ratio, this.detail);
}

String _fmt(double v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

final ringMetricsProvider = FutureProvider.autoDispose<List<RingMetric>>((ref) async {
  final metrics = <RingMetric>[];

  // Budget du mois
  final budgets = await ref.watch(budgetsListProvider.future);
  double limit = 0, spent = 0;
  for (final b in budgets.where((b) => b.period == BudgetPeriod.mensuel && b.id != null)) {
    limit += b.amount;
    spent += await ref.watch(budgetSpentAmountProvider(b.id!).future);
  }
  metrics.add(RingMetric(
    'Budget du mois',
    limit > 0 ? spent / limit : 0,
    limit > 0 ? '${_fmt(spent)} / ${_fmt(limit)}' : 'Aucun budget mensuel',
  ));

  // Objectifs d'épargne
  final savings = await ref.watch(savingsListProvider.future);
  double sTarget = 0, sCur = 0;
  for (final s in savings.where((s) => s.hasTarget)) {
    sTarget += s.targetAmount!;
    sCur += s.currentBalance;
  }
  metrics.add(RingMetric(
    'Objectif d’épargne',
    sTarget > 0 ? sCur / sTarget : 0,
    sTarget > 0 ? '${_fmt(sCur)} / ${_fmt(sTarget)}' : 'Aucun objectif défini',
  ));

  // Crédits remboursés
  final credits = await ref.watch(creditsListProvider.future);
  var paid = 0, total = 0;
  for (final c in credits.where((c) => c.id != null && c.status == CreditStatus.actif)) {
    paid += await ref.watch(creditPaidCountProvider(c.id!).future);
    total += c.durationMonths;
  }
  metrics.add(RingMetric(
    'Crédit remboursé',
    total > 0 ? paid / total : 0,
    total > 0 ? '$paid échéances sur $total' : 'Aucun crédit actif',
  ));

  // Taux d'épargne du mois
  final income = await ref.watch(monthlyIncomeProvider.future);
  final expense = await ref.watch(monthlyExpenseProvider.future);
  metrics.add(RingMetric(
    'Taux d’épargne',
    income > 0 ? ((income - expense) / income).clamp(0.0, 1.0) : 0,
    income > 0 ? 'du revenu du mois' : 'Aucun revenu ce mois',
  ));

  // Dettes et créances réglées
  final debts = await ref.watch(debtsListProvider.future);
  double dTotal = 0, dPaid = 0;
  for (final d in debts) {
    dTotal += d.totalAmount;
    dPaid += d.paidAmount;
  }
  metrics.add(RingMetric(
    'Dettes & créances réglées',
    dTotal > 0 ? dPaid / dTotal : 0,
    dTotal > 0 ? '${_fmt(dPaid)} / ${_fmt(dTotal)}' : 'Aucune dette',
  ));
  return metrics;
});

/// Objectif mensuel par compte (cercle « suivi » de chaque compte).
/// Mémorisé localement ; à défaut, 110 % du plus haut solde de la période.
class AccountGoals {
  static String _key(int id) => 'account_goal_$id';

  static Future<double?> read(int accountId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getDouble(_key(accountId));
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int accountId, double? goal) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (goal == null) {
        await p.remove(_key(accountId));
      } else {
        await p.setDouble(_key(accountId), goal);
      }
    } catch (_) {}
  }
}

class AccountTracking {
  final AccountHistory history;
  final double goal;
  final bool customGoal;
  const AccountTracking(this.history, this.goal, this.customGoal);
  double get ratio => goal <= 0 ? 0 : (history.last / goal).clamp(0.0, 1.0);
}

final accountTrackingProvider = FutureProvider.autoDispose<List<AccountTracking>>((ref) async {
  final hist = await ref.watch(accountHistoriesProvider.future);
  final out = <AccountTracking>[];
  for (final h in hist) {
    final saved = await AccountGoals.read(h.account.id!);
    final peak = h.values.isEmpty ? 0.0 : h.values.reduce((a, b) => a > b ? a : b);
    final goal = saved ?? (peak > 0 ? peak * 1.1 : 0.0);
    out.add(AccountTracking(h, goal, saved != null));
  }
  return out;
});

/// Dépenses du mois par catégorie (devise principale).
class CategorySlice {
  final String name;
  final double amount;
  final int? color;
  const CategorySlice(this.name, this.amount, this.color);
}

final expenseByCategoryProvider = FutureProvider.autoDispose<List<CategorySlice>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final accounts = await ref.watch(accountsListProvider.future);
  final main = await ref.watch(mainCurrencyProvider.future);
  final cats = await ref.watch(allCategoriesProvider.future);
  final now = DateTime.now();
  final txs = await repo.getTransactions(
    type: TransactionType.depense,
    from: DateTime(now.year, now.month, 1),
    limit: 20000,
  );
  final ids = accounts.where((a) => a.currency == main).map((a) => a.id).toSet();
  final byCat = <int?, double>{};
  for (final t in txs) {
    if (t.isTransfer || !ids.contains(t.accountId)) continue;
    byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
  }
  final out = <CategorySlice>[];
  byCat.forEach((id, amount) {
    final c = cats.where((c) => c.id == id).toList();
    out.add(CategorySlice(c.isEmpty ? 'Sans catégorie' : c.first.name, amount, c.isEmpty ? null : c.first.color));
  });
  out.sort((a, b) => b.amount.compareTo(a.amount));
  return out;
});

/// Revenus / dépenses des 6 derniers mois (devise principale, hors virements).
class MonthlyFlow {
  final String label;
  final double income;
  final double expense;
  const MonthlyFlow(this.label, this.income, this.expense);
}

const _monthShort = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

final monthlyFlowsProvider = FutureProvider.autoDispose<List<MonthlyFlow>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final accounts = await ref.watch(accountsListProvider.future);
  final main = await ref.watch(mainCurrencyProvider.future);
  final ids = accounts.where((a) => a.id != null && a.currency == main).map((a) => a.id!).toList();
  final now = DateTime.now();
  final out = <MonthlyFlow>[];
  for (var i = 5; i >= 0; i--) {
    final start = DateTime(now.year, now.month - i, 1);
    final end = DateTime(now.year, now.month - i + 1, 1).subtract(const Duration(milliseconds: 1));
    final inc = await repo.getTotalByType(TransactionType.revenu, from: start, to: end, accountIds: ids, currency: main);
    final exp = await repo.getTotalByType(TransactionType.depense, from: start, to: end, accountIds: ids, currency: main);
    out.add(MonthlyFlow(_monthShort[start.month - 1], inc, exp));
  }
  return out;
});
