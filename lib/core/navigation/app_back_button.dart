import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';

/// Bouton retour à placer en `leading` de l'AppBar de **chaque page** de
/// l'application (voir demande explicite : cohérence de navigation).
///
/// Beaucoup de pages du menu latéral sont ouvertes via `context.go(...)`,
/// qui remplace la page courante dans la pile de navigation plutôt que de
/// l'empiler : Flutter n'affiche alors aucune flèche retour automatique.
/// Avant ce correctif, les pages "Sauvegarde", "Synchronisation",
/// "Archives", "Journal des actions" et "Exporter mes données" étaient de
/// véritables impasses de navigation (ni bouton retour, ni menu).
///
/// Ce bouton gère les trois cas de figure possibles :
///   1. Une page a été empilée normalement (`Navigator.push`, ex : détail
///      d'un crédit) → comportement standard, on dépile.
///   2. Une page de premier niveau atteinte via `context.go(...)` → on
///      retourne au tableau de bord (page d'accueil).
///   3. On est déjà sur le tableau de bord, rien "avant" → on propose de
///      quitter l'application (comportement standard d'un écran d'accueil).
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Sur le poste de travail, les onglets remplacent le retour (sauf page empilée).
    if (isDesktopWidth(context) && !Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Retour',
      onPressed: () => _handleBack(context),
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    final location = GoRouterState.of(context).uri.toString();
    if (location != '/') {
      context.go('/');
      return;
    }

    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter l\'application ?'),
        content: const Text('Tu es sur le tableau de bord. Veux-tu fermer l\'application ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (shouldQuit == true) {
      SystemNavigator.pop();
    }
  }
}
