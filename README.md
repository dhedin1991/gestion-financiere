# Ma Gestion Financière

Application Flutter de gestion financière personnelle et professionnelle
(comptes, transactions, budgets, épargne, crédits, dettes & créances,
patrimoine, bilans), pensée pour fonctionner **100 % hors-ligne** — aucune
donnée n'est envoyée à un serveur.

[![Build](https://github.com/dhedin1991/gestion-financiere/actions/workflows/build.yml/badge.svg)](../../actions/workflows/build.yml)

## Fonctionnalités
- **Comptabilité** : comptes multiples, transactions, transactions
  récurrentes, budgets par catégorie.
- **Patrimoine** : épargne (avec objectifs), crédits (échéancier),
  dettes & créances, biens (patrimoine), bilans (revenus/dépenses,
  patrimoine net dans le temps).
- **Multi-entités** : sépare les données personnelles et professionnelles.
- **Sécurité** : verrouillage par mot de passe (PBKDF2), verrouillage
  automatique, code de récupération local.
- **Données** : export CSV/PDF, sauvegarde/restauration manuelle,
  synchronisation Wi-Fi locale entre deux appareils (sans serveur).
- **Journal d'audit** : trace des créations/modifications/suppressions.

## Stack technique
- **Flutter** (Dart), architecture **feature-first / Clean Architecture**
  (voir [CONTRIBUTING.md](CONTRIBUTING.md) pour le détail des couches).
- **Riverpod** pour la gestion d'état.
- **sqflite** (SQLite) pour le stockage local.
- **go_router** pour la navigation.

## Démarrer en local
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
Prérequis et détails d'architecture : voir [CONTRIBUTING.md](CONTRIBUTING.md).

## Compiler sans installer Flutter (via GitHub Actions)
Si tu ne veux pas installer le SDK Flutter sur ton PC, un guide pas-à-pas
pour compiler l'APK directement depuis le navigateur (via GitHub Actions)
est disponible dans
[docs/GUIDE_COMPILATION_GITHUB.md](docs/GUIDE_COMPILATION_GITHUB.md).

## Sécurité et confidentialité
- Toutes les données restent **en local** sur l'appareil (fichier SQLite),
  aucun compte ni serveur externe.
- Le mot de passe est haché (PBKDF2-HMAC-SHA256) et stocké via le
  Keystore Android / Keychain iOS (`flutter_secure_storage`), jamais en
  clair.
- La base de données elle-même n'est **pas chiffrée au repos** — c'est un
  choix technique assumé et documenté, voir [CHANGELOG.md](CHANGELOG.md)
  pour le contexte et la recommandation de migration vers SQLCipher.
- La synchronisation Wi-Fi entre appareils utilise HTTP local (non
  chiffré), protégé par un code à 6 chiffres à usage limité dans le temps
  — à réserver à un réseau Wi-Fi de confiance.

## Licence
Voir [LICENSE](LICENSE) — usage personnel, tous droits réservés par défaut.

## Contribuer
Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour la structure du projet et les
règles avant une Pull Request. Historique des changements :
[CHANGELOG.md](CHANGELOG.md).
