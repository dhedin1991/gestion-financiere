import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/datasources/bilan_dao.dart';
import '../../data/repositories/bilan_repository_impl.dart';
import '../../domain/entities/net_worth_snapshot.dart';
import '../../domain/repositories/bilan_repository.dart';

/// Périodes disponibles pour regrouper les revenus/dépenses.
enum BilanPeriod { journalier, hebdomadaire, mensuel, trimestriel, semestriel, annuel }

/// Résumé agrégé des revenus/dépenses pour une période donnée (ex: un mois précis).
class PeriodSummary {
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalRevenue;
  final double totalExpense;

  const PeriodSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalRevenue,
    required this.totalExpense,
  });

  double get balance => totalRevenue - totalExpense;
}

final bilanDaoProvider = Provider<BilanDao>((ref) {
  final appDatabase = ref.watch(appDatabaseProvider);
  return BilanDao(appDatabase);
});

final bilanRepositoryProvider = Provider<BilanRepository>((ref) {
  final dao = ref.watch(bilanDaoProvider);
  return BilanRepositoryImpl(dao);
});

/// Historique du patrimoine net. À chaque consultation de cet écran, une
/// nouvelle photo du jour est calculée et enregistrée automatiquement
/// (remplace celle du jour si elle existe déjà).
final netWorthHistoryProvider = FutureProvider.autoDispose<List<NetWorthSnapshot>>((ref) async {
  final repository = ref.watch(bilanRepositoryProvider);
  await repository.refreshTodaySnapshot();
  return repository.getNetWorthHistory();
});

/// Détermine la date de début pour une période donnée, à partir d'une date de référence.
DateTime _periodStartFor(BilanPeriod period, DateTime reference) {
  switch (period) {
    case BilanPeriod.journalier:
      return DateTime(reference.year, reference.month, reference.day);
    case BilanPeriod.hebdomadaire:
      final weekday = reference.weekday; // 1 = lundi
      return DateTime(reference.year, reference.month, reference.day - (weekday - 1));
    case BilanPeriod.mensuel:
      return DateTime(reference.year, reference.month, 1);
    case BilanPeriod.trimestriel:
      final quarterStartMonth = ((reference.month - 1) ~/ 3) * 3 + 1;
      return DateTime(reference.year, quarterStartMonth, 1);
    case BilanPeriod.semestriel:
      final semesterStartMonth = reference.month <= 6 ? 1 : 7;
      return DateTime(reference.year, semesterStartMonth, 1);
    case BilanPeriod.annuel:
      return DateTime(reference.year, 1, 1);
  }
}

DateTime _nextPeriodStart(BilanPeriod period, DateTime periodStart) {
  switch (period) {
    case BilanPeriod.journalier:
      return periodStart.add(const Duration(days: 1));
    case BilanPeriod.hebdomadaire:
      return periodStart.add(const Duration(days: 7));
    case BilanPeriod.mensuel:
      return DateTime(periodStart.year, periodStart.month + 1, 1);
    case BilanPeriod.trimestriel:
      return DateTime(periodStart.year, periodStart.month + 3, 1);
    case BilanPeriod.semestriel:
      return DateTime(periodStart.year, periodStart.month + 6, 1);
    case BilanPeriod.annuel:
      return DateTime(periodStart.year + 1, 1, 1);
  }
}

/// Paramètres pour demander un résumé Revenus/Dépenses : la période choisie,
/// et le nombre de périodes précédentes à afficher (ex: les 6 derniers mois).
class BilanQuery {
  final BilanPeriod period;
  final int periodsCount;

  const BilanQuery({required this.period, this.periodsCount = 6});

  @override
  bool operator ==(Object other) =>
      other is BilanQuery && other.period == period && other.periodsCount == periodsCount;

  @override
  int get hashCode => Object.hash(period, periodsCount);
}

/// Liste des résumés par période (revenus/dépenses), du plus ancien au plus récent.
final revenueExpenseSummaryProvider =
    FutureProvider.autoDispose.family<List<PeriodSummary>, BilanQuery>((ref, query) async {
  final repository = ref.watch(bilanRepositoryProvider);
  final now = DateTime.now();

  // Détermine la borne de début de la période la plus ancienne à afficher.
  var earliestStart = _periodStartFor(query.period, now);
  for (int i = 1; i < query.periodsCount; i++) {
    earliestStart = _periodStartFor(
      query.period,
      earliestStart.subtract(const Duration(days: 1)),
    );
  }

  final latestEnd = _nextPeriodStart(query.period, _periodStartFor(query.period, now));

  final transactions = await repository.getTransactionsBetween(earliestStart, latestEnd);

  // Construit la liste des périodes (bornes de début/fin), dans l'ordre chronologique.
  final periods = <PeriodSummary>[];
  var cursor = earliestStart;
  while (cursor.isBefore(latestEnd)) {
    final periodEnd = _nextPeriodStart(query.period, cursor);
    double revenue = 0;
    double expense = 0;

    for (final tx in transactions) {
      final txDate = DateTime.parse(tx['transaction_date'] as String);
      if (!txDate.isBefore(cursor) && txDate.isBefore(periodEnd)) {
        final amount = (tx['amount'] as num).toDouble();
        if (tx['type'] == 'revenu') {
          revenue += amount;
        } else if (tx['type'] == 'depense') {
          expense += amount;
        }
      }
    }

    periods.add(PeriodSummary(
      periodStart: cursor,
      periodEnd: periodEnd,
      totalRevenue: revenue,
      totalExpense: expense,
    ));

    cursor = periodEnd;
  }

  return periods;
});
