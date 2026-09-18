# Journal des modifications

Ce fichier documente les changements notables du projet.
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié]

### 🔒 Sécurité et intégrité des données
- **Migration complète des montants vers les centimes entiers** (schéma
  v13) : élimine définitivement le risque de dérive d'arrondi en virgule
  flottante sur les données financières. Migration automatique au premier
  lancement après mise à jour, avec **sauvegarde de sécurité automatique**
  du fichier de base avant toute conversion (visible dans le dossier de
  l'app, restaurable depuis la page Sauvegarde en cas de souci).
- En construisant cette migration, plusieurs **bugs de calcul silencieux
  ont été trouvés et corrigés** avant même d'affecter qui que ce soit :
  points où un montant lu directement d'une ligne SQL brute (sans passer
  par la conversion centralisée) aurait faussé un solde ou un total
  affiché — comptes, dettes, épargne, budgets, patrimoine, bilan/patrimoine
  net. Chacun a été audité et corrigé individuellement.
- Verrouillage automatique de l'application à la mise en arrière-plan
  (délai configurable dans Paramètres → Sécurité).
- Protection anti-brute-force sur l'écran de connexion et le code de
  récupération (verrouillage temporaire progressif après échecs répétés).
- Hachage du mot de passe et du code de récupération renforcé
  (PBKDF2-HMAC-SHA256, nombreuses itérations, au lieu d'un simple SHA-256).
- Synchronisation Wi-Fi : code d'appairage à 6 chiffres, expiration de
  session, verrouillage après plusieurs échecs, avertissement explicite
  dans l'UI sur les limites de sécurité (réseau local non chiffré).
- Restauration de sauvegarde : validation du format de fichier (en-tête
  SQLite), copie de sécurité automatique de la base actuelle avant tout
  remplacement, sélecteur de fichier restreint aux `.db`.

### ✨ Ajouté
- Page **Paramètres** unique, consolidant Sécurité, Apparence, Données
  (sauvegarde/synchro/export), Journal d'audit, Aide et À propos —
  remplace les entrées éparpillées du menu latéral.
- Bouton retour visible et cohérent sur **toutes** les pages de
  l'application (`AppBackButton`), avec confirmation de sortie sur
  l'écran d'accueil.
- `AppErrorMessage` : messages d'erreur compréhensibles pour
  l'utilisateur (ex : « des données sont encore liées ») au lieu du texte
  brut d'une exception Dart/SQLite (ex : « Exception: FOREIGN KEY
  constraint failed (code 787) »). Le détail technique reste journalisé.
- `analysis_options.yaml` : le linter `flutter_lints`, déclaré mais
  jamais activé, fonctionne enfin.
- `.gitignore`, `LICENSE`, `CONTRIBUTING.md` dédiés au projet.
- CI : étape `flutter analyze` bloquante, mesure de couverture de tests.

### 🐛 Corrigé
- Pages « Sauvegarde », « Synchronisation », « Archives », « Journal des
  actions » et « Exporter mes données » étaient des impasses de
  navigation (ni bouton retour, ni accès au menu) une fois ouvertes.
- Le verrouillage de session (`lockAgain()`) existait mais n'était jamais
  appelé : l'app ne se reverrouillait jamais automatiquement.
- Suppression d'une **transaction** ou d'une **transaction récurrente** :
  un seul tap sur « Supprimer » effaçait définitivement la donnée, sans
  aucune confirmation (à la différence des comptes, dettes, crédits,
  budgets et épargnes, qui demandaient déjà confirmation). Une boîte de
  dialogue de confirmation a été ajoutée aux deux, par cohérence avec le
  reste de l'app.

## [0.1.0] — Version initiale
- Comptes, transactions, transactions récurrentes, budgets.
- Épargne, crédits, dettes & créances, patrimoine, bilans.
- Verrouillage par mot de passe, code de récupération local.
- Sauvegarde/restauration manuelle, export CSV/PDF, synchronisation
  Wi-Fi locale entre appareils.
- Journal d'audit des actions, multi-entités (personnel/pro).
