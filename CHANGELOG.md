# Journal des modifications

Ce fichier documente les changements notables du projet.
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Moteur d'interconnexion] — 2026-11-22 (branche `moteur`, non fusionné)

### Nouveau
- **Une seule saisie, synchronisation partout** : grand livre (chaque variation de solde laisse une écriture), service d'opérations (dépôt, retrait Moov/MTN vers la caisse, transfert, épargne, crédit, dette, créance, achat à crédit, remboursements), base de données v18 (migration non destructive).
- **Comptes** : vues Cartes / Tableau / Évolution, rôles « Caisse principale » et « Épargne immédiate », alertes de solde orange puis rouge (seuils 15 000 / 10 000 modifiables, surchargeables par compte).
- **Facturation** : liste avec indicateurs, formulaire, aperçu et PDF en 4 modèles, profil de l'entreprise, encaissement qui crédite un compte (revenu compté), annulation d'encaissement.
- **Accueil** : bloc « Position financière » (trésorerie, épargne, créances, crédits, dettes, factures, position nette) et dernières transactions.
- **Épargne, Crédits, Dettes** : bandeau de synthèse avec cercle de suivi et chiffres clés (courbe d'évolution pour l'épargne).
- 10 tests de cohérence des soldes sur SQLite.
- **Outils > Contrôle d'intégrité** : compare chaque solde à « solde initial + écritures » et ajoute, au besoin, une écriture neutre « Correction d'historique » (le solde affiché ne change pas).
- Position financière : les versements d'épargne faits via « Nouvelle opération » ne sont plus comptés deux fois (compte d'épargne + enveloppe).

### Corrigé
- **Icône Android** : icône carrée pleine + premier plan adaptatif dédié (fond #0B1220), contrôle automatique des fichiers générés dans la CI. Désinstaller puis réinstaller l'APK pour vider le cache d'icône.

## [Interface professionnelle] — 2026-11-21

- **Comptes** : « Ajuster le solde » crée une transaction « Correction de solde » tracée dans l'historique et le journal (plus d'écrasement silencieux).
- Guide de compilation mis à jour (téléchargement via Releases).

- Logo « Barres et courbe » (8 logos au choix dans Paramètres > Affichage), icône de l'application Android/Windows.
- Favoris dans le navigateur (étoile), saisie rapide dans la recherche (« loyer 120000 », « + salaire 650000 »), annulation après suppression, menu clic droit / appui long sur les transactions.

### Nouveau
- **Nouvelle interface « terminal bancaire »** (inspirée de MetaTrader 5 et TradingView) : 8 thèmes (Nuit bancaire, Clair professionnel, Océan, Émeraude, Graphite, Violet nuit, Sépia confort, Contraste élevé) et 8 polices embarquées (IBM Plex Sans, Inter, Roboto, Open Sans, Source Sans, Lato, Atkinson, Segoe UI), hors ligne.
- **Poste de travail Windows** : barre de menus, recherche globale (Ctrl K), onglets façon navigateur, Navigateur (arborescence) à gauche, barre d'état avec alertes. Dispositions de fenêtres : Onglets, Cascade (déplaçables et redimensionnables), Colonnes, Mosaïque.
- **Mobile** : barre de navigation du bas avec bouton « + » central.
- **Accueil** et **Statistiques** : courbe du patrimoine, répartition par compte, cercles de suivi animés (budget, épargne, crédit, taux d'épargne, dettes), un graphe d'évolution par compte avec cercle d'objectif modifiable, dépenses par catégorie, revenus vs dépenses.
- **Paramètres > Affichage** : zoom 75–150 % par pas de 5, thème, police, fenêtres, recherche, taille du texte, densité, séparateur des milliers, police des montants, mode confidentialité (œil).
- Raccourcis Windows : Ctrl K (recherche), Ctrl N (nouvelle écriture), Ctrl + / − / 0 (zoom), Ctrl Tab, Ctrl W.

### Modifié
- Les anciens réglages « style » et « mode clair/sombre » sont convertis automatiquement vers le nouveau thème le plus proche.

## [Non publié]

### Pagination des transactions
- La liste Revenus & Dépenses charge par pages de 50 (bouton « Charger
  plus ») au lieu d'un plafond fixe à 300 qui masquait silencieusement les
  transactions plus anciennes sans le signaler.

### Taux de change manuels
- Nouvel écran Paramètres > Taux de change : saisis à la main combien vaut
  1 unité de chaque devise en XOF (aucun appel réseau, l'app reste 100%
  hors ligne). Le Tableau de bord affiche alors une estimation du solde
  toutes devises confondues, en plus du solde par devise principale déjà
  affiché. Schéma v17 (table `exchange_rates`).

### Virements entre comptes
- Nouveau bouton (icône ⇄) sur l'écran Revenus & Dépenses : crée deux
  écritures liées (dépense + revenu) entre deux comptes de MÊME devise,
  jamais comptées dans les totaux Revenus/Dépenses ni dans les budgets.
  Supprimer un virement supprime toujours ses deux écritures ensemble.
  Fonctionne aussi correctement à travers la fusion de synchronisation
  Wi-Fi (le lien entre les deux écritures est reconstruit proprement).
  Schéma v16 (colonne `transfer_group`).

### Export et sauvegarde protégés par mot de passe
- Case « Protéger par mot de passe » sur l'export CSV/PDF et sur la
  sauvegarde complète : produit un fichier chiffré (AES-256-GCM, clé
  dérivée par PBKDF2) au lieu du fichier en clair.
- Nouvel écran « Déchiffrer un fichier » (Sauvegarde) : ouvre un export
  chiffré avec son mot de passe ; pour une sauvegarde de base, propose de
  la restaurer directement.

### Fusion des données pour la synchronisation Wi-Fi
- La sync propose maintenant deux modes : **Fusionner** (par défaut,
  recommandé) combine les données des deux appareils sans rien perdre ni
  dupliquer de part et d'autre ; **Remplacer** garde l'ancien comportement
  (tout écraser).
- La fusion rapproche comptes, catégories, entités, épargnes, dettes,
  crédits, biens, budgets et récurrences par une clé naturelle (nom, pas
  l'id, qui peut différer entre appareils) ; les transactions, versements
  d'épargne et paiements de dette sont ajoutés de façon additive, sans
  doublons ; une échéance de crédit marquée payée sur un appareil le reste
  après fusion, même si l'autre appareil ne l'avait pas encore payée.
- Les soldes des comptes et de l'épargne sont recalculés à partir des
  mouvements réels après fusion, pour rester exacts.
- Une copie de sécurité (`avant_fusion_...`) est prise avant, par précaution.
- Testé avec de vraies bases SQLite (deux fichiers distincts simulant deux
  appareils), pas seulement en théorie.

### Sauvegarde automatique périodique
- Une copie de sécurité de la base est prise automatiquement toutes les
  7 jours (silencieuse, 3 dernières copies conservées) : protège contre un
  bug interne entre deux exports manuels. Elle ne remplace PAS l'export
  manuel (Sauvegarde > Exporter) : elle reste dans le dossier de l'app et
  disparaît si l'app est désinstallée.
- L'écran Sauvegarde affiche un rappel si aucun export manuel n'a été fait
  depuis plus de 30 jours.

### Bilans par entité (schéma v15)
- Le patrimoine net et les graphiques Revenus/Dépenses sont désormais calculés
  pour l'**entité active** uniquement (comptes, épargne, biens, dettes,
  crédits), dans sa devise principale. Une photo du patrimoine par jour et par
  entité ; les anciennes photos sont rattachées à l'entité « Personnel ».

### Windows / dettes
- **Windows** : l'app retombe sur la bibliothèque SQLite intégrée à Windows
  (`winsqlite3.dll`) si aucun `sqlite3.dll` n'est fourni à côté de l'exécutable
  (sinon plantage à la première lecture de la base, juste après la connexion).
- **Dettes** : un paiement ne peut plus dépasser le reste dû.

### 🛠️ Correctifs de stabilité (audit général de septembre 2026)
- **Plantages / écrans blancs au démarrage** : l'ouverture de la base de
  données n'est plus lancée en double au démarrage (une connexion « de test »
  pouvait fermer la vraie base) ; la version de la base est lue directement
  dans l'en-tête du fichier.
- **Reverrouillage intempestif** : l'app ne se reverrouille plus à une simple
  perte de focus (clic hors de la fenêtre, notification, boîte système) mais
  seulement quand elle passe réellement en arrière-plan. Les sélecteurs de
  fichier et feuilles de partage de l'app sont ignorés.
- **Journal d'erreurs** (`journal_erreurs.log`, dossier de l'app) et capture
  globale des erreurs ; écran de repli lisible à la place de l'écran gris.
- **Polices natives** : plus de téléchargement de police au démarrage
  (`google_fonts` retiré) — texte net, indépendant du réseau.
- **Rappels** : manifest Android complet (receivers, redémarrage), mode
  d'alarme sans permission exacte, rappels J-3 à 9 h (et non minuit), rappel
  le jour même pour les dettes, horizon de 90 jours, alerte budget à 80 %,
  désactivés proprement sur Windows (non pris en charge).
- **Signature APK permanente** (clé chiffrée + secret
  `ANDROID_KEYSTORE_PASSPHRASE`) : permet d'installer une nouvelle version
  par-dessus l'ancienne sans perdre les données. Build sans R8.
- **Sync Wi-Fi / restauration** : fichier vérifié avant remplacement, copie
  de sécurité, nettoyage des fichiers annexes SQLite, refus d'une base d'une
  version plus récente, purge des anciennes copies de sécurité.
- **Dates de fin de mois** : plus de saut de mois (31 janv. -> 3 mars) pour les
  récurrences, l'échéancier des crédits et les périodes de budget
  (schéma v14 : colonne `anchor_day`).
- **Récurrences** : génération sérialisée, état enregistré après chaque
  occurrence, rattrapage aussi au retour au premier plan.
- **Crédits** : payer/annuler une échéance débite/recrédite le compte de
  remboursement ; migration de la table d'épargne pour les très anciennes bases.
- **Bilans** : comptes archivés exclus (comme le tableau de bord).
  **Budgets** : dépenses filtrées par devise et par entité.
  **Comptes** : les récurrences comptent comme données liées à la suppression.
- **Devises** : solde global, revenus/dépenses du mois et bilans n'additionnent
  plus que la devise principale (la plus utilisée par les comptes, XOF en cas
  d'égalité) ; une note signale les comptes d'autres devises non inclus.
  Revenus/dépenses du mois limités à l'entité active.
- **Import CSV** : lecture complète avant écriture, doublons ignorés (un fichier
  réimporté ne double plus les données), CRLF/BOM/Latin-1 et montants de type
  « 1 500,50 » ou « 1.500,50 » acceptés.
- **Sync Wi-Fi** : avertissement explicite si les données de l'appareil qui
  reçoit sont plus récentes que celles de l'appareil source.
- **Journal d'audit** étendu aux comptes, dettes, épargne, budgets et crédits.
- **Tests d'intégration des migrations SQLite** (installation neuve, v13 -> v14,
  v12 -> v14 avec conversion en centimes et sauvegarde, ouvertures
  simultanées) exécutés à chaque compilation.
- Dépendances verrouillées (`pubspec.lock`), `.gitignore`, analyse CI non
  bloquante sur les simples suggestions de style.

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
