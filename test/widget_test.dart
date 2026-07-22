import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Remplace le test par défaut généré par `flutter create` (qui teste
// l'app modèle "compteur", inexistante dans ce projet réel).
//
// On ne pump pas GestionFinanciereApp() directement ici : elle initialise
// au démarrage des plugins natifs (base de données, stockage sécurisé)
// qui nécessitent l'environnement réel de l'appareil et ne sont pas
// disponibles tels quels dans `flutter test`. Les vrais tests de
// comportement sont dans test/core et test/features, sur la logique
// métier pure, indépendante de Flutter et des plugins.
void main() {
  testWidgets('Un widget simple s\'affiche sans erreur (sanity check)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Ma Gestion Financière'))),
    );
    expect(find.text('Ma Gestion Financière'), findsOneWidget);
  });
}
