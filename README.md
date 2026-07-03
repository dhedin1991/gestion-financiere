# Ma Gestion Financière — Guide de démarrage (spécial connexion lente)

Ce guide t'explique comment obtenir ton application **sans télécharger le SDK Flutter (1 Go)** sur ton PC. La compilation se fera gratuitement sur les serveurs de GitHub.

## Ce dont tu as besoin
- Un compte GitHub (gratuit) → https://github.com/signup
- Une connexion internet, même lente (on ne télécharge presque rien de lourd)

---

## Étape 1 — Créer un dépôt GitHub

1. Connecte-toi sur https://github.com
2. Clique sur le **+** en haut à droite → **"New repository"**
3. Nom du dépôt : `gestion-financiere`
4. Laisse-le en **Public** (nécessaire pour la compilation gratuite)
5. Clique sur **"Create repository"**

## Étape 2 — Envoyer les fichiers (sans ligne de commande)

1. Sur la page de ton nouveau dépôt vide, clique sur le lien **"uploading an existing file"**
2. **Glisse-dépose tout le dossier** `gestion_financiere` que je t'ai donné (ou son contenu) dans la zone d'upload de GitHub
   - ⚠️ Assure-toi que le dossier `.github` (avec le fichier `build.yml` dedans) est bien inclus — c'est lui qui déclenche la compilation automatique
3. En bas de page, clique sur **"Commit changes"**

## Étape 3 — Laisser GitHub compiler l'application

1. Va dans l'onglet **"Actions"** en haut de la page de ton dépôt
2. Tu devrais voir un workflow **"Compiler l'application (cloud)"** en train de tourner (rond jaune/orange qui tourne)
3. Attends 3 à 8 minutes — c'est GitHub qui télécharge Flutter et compile, pas toi
4. Quand le rond devient **vert ✅**, clique dessus

## Étape 4 — Télécharger ton application (.apk)

1. Toujours sur la page du workflow terminé, descends jusqu'à la section **"Artifacts"**
2. Clique sur **"application-android"** — ça télécharge un fichier `.zip` léger (quelques dizaines de Mo, pas 1 Go)
3. Décompresse-le : tu obtiens un fichier `app-release.apk`
4. Transfère ce fichier sur ton téléphone Android (par câble USB, ou en te l'envoyant via WhatsApp/e-mail à toi-même)
5. Sur le téléphone, ouvre le fichier `.apk` pour l'installer
   - Android va peut-être demander d'autoriser "l'installation depuis une source inconnue" → accepte, c'est normal pour une app qui n'est pas encore sur le Play Store

---

## Et pour la version Windows ?

On l'ajoutera une fois que le cœur de l'application (les modules) sera plus avancé — la compilation Windows demande un peu plus de configuration. On y viendra ensemble.

## Et après ?

Reviens me voir avec :
- Une capture d'écran si quelque chose ne fonctionne pas (l'onglet Actions affiche les erreurs en détail)
- Ou simplement "ça marche !" pour qu'on passe au module suivant (Revenus & Dépenses)

Je continuerai à coder les modules un par un : à chaque fois, tu n'auras qu'à renvoyer les nouveaux fichiers sur GitHub (même méthode qu'à l'étape 2) et relancer une compilation.
