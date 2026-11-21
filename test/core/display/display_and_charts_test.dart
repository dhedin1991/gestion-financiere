import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/display/display_prefs.dart';
import 'package:gestion_financiere/core/theme/app_theme.dart';
import 'package:gestion_financiere/core/utils/app_format.dart';
import 'package:gestion_financiere/core/widgets/charts.dart';
import 'package:gestion_financiere/features/dashboard/presentation/providers/insights_providers.dart';
import 'package:gestion_financiere/features/transactions/domain/entities/transaction.dart';

void main() {
  group('Zoom', () {
    test('les paliers vont de 75 à 150 par pas de 5', () {
      final steps = kZoomSteps;
      expect(steps.first, 75);
      expect(steps.last, 150);
      expect(steps.length, 16);
      expect(steps.contains(80), isTrue);
      expect(steps.contains(85), isTrue);
    });

    test('clampZoom borne et aligne sur le pas de 5', () {
      expect(clampZoom(10), 75);
      expect(clampZoom(999), 150);
      expect(clampZoom(102), 100);
      expect(clampZoom(103), 105);
    });
  });

  group('Formatage des montants', () {
    tearDown(() => DisplayPrefs.current = const DisplayPrefs());

    test('séparateur configurable', () {
      DisplayPrefs.current = const DisplayPrefs(separator: ThousandsSeparator.dot);
      expect(AppFormat.currency(symbol: 'XOF').format(1234567), '1.234.567 XOF');
      DisplayPrefs.current = const DisplayPrefs(separator: ThousandsSeparator.comma);
      expect(AppFormat.amount(1000), '1,000');
    });

    test('mode confidentialité masque les montants', () {
      DisplayPrefs.current = const DisplayPrefs(hideAmounts: true);
      expect(AppFormat.currency(symbol: 'XOF').format(123456), '••••');
    });
  });

  group('Thèmes', () {
    test('les 8 thèmes se construisent avec chaque police', () {
      expect(AppThemePreset.values.length, 8);
      for (final p in AppThemePreset.values) {
        for (final f in AppFont.values) {
          final t = AppTheme.build(p, font: f);
          expect(t.colorScheme.brightness, p.isDark ? Brightness.dark : Brightness.light);
          expect(t.extension<AppColors>(), isNotNull);
        }
      }
    });
  });

  group('Historique de solde', () {
    FinancialTransaction tx(DateTime d, double amount, TransactionType type) => FinancialTransaction(
          accountId: 1,
          type: type,
          amount: amount,
          currency: 'XOF',
          transactionDate: d,
          createdAt: d,
          updatedAt: d,
        );

    test('reconstitue les soldes passés à partir des écritures', () {
      final end = DateTime(2026, 11, 20);
      final start = DateTime(2026, 11, 10);
      final txs = [
        tx(DateTime(2026, 11, 15), 500, TransactionType.revenu),
        tx(DateTime(2026, 11, 18), 200, TransactionType.depense),
      ];
      final v = reconstructBalances(currentBalance: 1000, txs: txs, start: start, end: end, points: 3);
      expect(v.length, 3);
      expect(v.last, 1000); // aujourd'hui : solde actuel
      expect(v.first, 1000 - 500 + 200); // avant les deux écritures
    });
  });

  group('Graphiques', () {
    testWidgets('RingGauge atteint la valeur demandée', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(AppThemePreset.nuitBancaire),
        home: const Scaffold(body: Center(child: RingGauge(value: 0.62, color: Colors.green))),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('62 %'), findsOneWidget);
    });

    testWidgets('courbes, anneau et barres s’affichent sans erreur', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(AppThemePreset.clairPro),
        home: Scaffold(
          body: ListView(children: [
            LineAreaChart(values: const [1, 3, 2, 5, 4], color: Colors.blue),
            MultiLineChart(series: const [[1, 2, 3], [3, 2, 1]], colors: const [Colors.red, Colors.blue]),
            const DonutChart(slices: [DonutSlice(1, Colors.red), DonutSlice(2, Colors.blue)]),
            PairBarChart(labels: const ['a', 'b'], a: const [1, 2], b: const [2, 1], colorA: Colors.green, colorB: Colors.red),
          ]),
        ),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  });
}
