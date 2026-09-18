# Guide de contribution

## Prérequis
- Flutter SDK ≥ 3.32 (voir `.github/workflows/build.yml` pour la version
  exacte utilisée en CI).
- Dart ≥ 3.3 (`environment.sdk` dans `pubspec.yaml`).

## Mise en route locale
```bash
flutter pub get
flutter analyze        # doit être sans erreur avant toute PR
flutter test            # tests unitaires (logique métier pure)
flutter run              # lance l'app sur un appareil/émulateur connecté
```

## Structure du projet
Le code suit une architecture **feature-first** inspirée de la Clean
Architecture. Chaque module dans `lib/features/<nom>/` est organisé en
trois couches :

```
<nom>/
├── domain/        # Entités métier + interfaces de repository (aucune
│                  # dépendance à Flutter, SQLite ou Riverpod)
├── data/          # Implémentation concrète : DAO (SQL), modèles,
│                  # repository qui implémente l'interface du domain
└── presentation/  # Pages, widgets, providers Riverpod
```

Le code partagé entre modules vit dans `lib/core/` (base de données,
thème, navigation, utilitaires).

## Règles avant une Pull Request
1. `flutter analyze` ne doit remonter aucune erreur.
2. Toute nouvelle logique métier (calculs financiers, règles de gestion)
   doit être accompagnée d'un test dans `test/`.
3. Toute page doit utiliser `AppBackButton` en `leading` de son `AppBar`
   (voir `lib/core/navigation/app_back_button.dart`) — pas de page sans
   moyen de revenir en arrière.
4. Aucune donnée sensible (montants, identifiants, mots de passe) ne doit
   apparaître dans un `print`/log en clair — utiliser le logger du projet.
5. Toute migration de schéma (`AppDatabase._onUpgrade`) doit être
   **non destructive** : vérifier l'existence d'une colonne/table avant
   de la créer, ne jamais supprimer de données silencieusement.

## Style de commit
Préfixes recommandés : `feat:`, `fix:`, `security:`, `docs:`, `test:`,
`refactor:`, `chore:`. Exemple : `security: ajoute le verrouillage auto`.
