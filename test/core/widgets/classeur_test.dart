import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/theme/app_theme.dart';
import 'package:gestion_financiere/core/widgets/classeur.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cats = [
    ClasseurCategory('maison', 'Maisons', Icons.home_outlined, Colors.blue),
    ClasseurCategory('auto', 'Autos', Icons.directions_car_outlined, Colors.orange),
    ClasseurCategory('autre', 'Autres', Icons.category_outlined, Colors.grey),
  ];

  ClasseurEntry entry(String id, String title, String cat, double amount, {double? progress}) => ClasseurEntry(
        id: id,
        title: title,
        categoryKey: cat,
        amount: amount,
        currency: 'XOF',
        progress: progress,
        onTap: () {},
      );

  Widget host(List<ClasseurEntry> entries, {String key = 't'}) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(AppThemePreset.values.first),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClasseurBoard(storageKey: key, entries: entries, categories: cats),
            ),
          ),
        ),
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final data = [
    entry('1', 'Villa Cotonou', 'maison', 50000000),
    entry('2', 'Appartement', 'maison', 20000000, progress: 0.5),
    entry('3', 'Toyota', 'auto', 6000000),
  ];

  testWidgets('les trois affichages montrent tous les éléments', (tester) async {
    await tester.pumpWidget(host(data));
    await tester.pumpAndSettle();
    expect(find.text('Villa Cotonou'), findsOneWidget); // grille (défaut)

    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    expect(find.text('Toyota'), findsOneWidget);

    await tester.tap(find.text('Colonnes'));
    await tester.pumpAndSettle();
    expect(find.text('Appartement'), findsOneWidget);
    expect(find.text('Autos'), findsWidgets);
  });

  testWidgets('un intercalaire filtre sur sa catégorie', (tester) async {
    await tester.pumpWidget(host(data));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autos').first);
    await tester.pumpAndSettle();
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Villa Cotonou'), findsNothing);
  });

  testWidgets('la recherche retrouve un élément', (tester) async {
    await tester.pumpWidget(host(data));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'toyo');
    await tester.pumpAndSettle();
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Villa Cotonou'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun résultat'), findsOneWidget);
  });
}
