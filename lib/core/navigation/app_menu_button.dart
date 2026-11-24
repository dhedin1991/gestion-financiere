import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calculator/presentation/calculator_view.dart';
import 'scaffold_key_provider.dart';
import '../shell/app_shell.dart';

/// Bouton ☰ à placer dans le `leading` de l'AppBar de chaque page, pour
/// ouvrir le menu latéral principal (qui vit dans le Scaffold englobant,
/// pas dans le Scaffold propre à chaque page).
class AppMenuButton extends ConsumerWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sur le poste de travail, le Navigateur remplace le menu latéral.
    if (isDesktopWidth(context)) return const SizedBox.shrink();
    final scaffoldKey = ref.watch(scaffoldKeyProvider);
    // La calculatrice est à portée de main sur toutes les pages (mobile).
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.calculate_outlined),
          tooltip: 'Calculatrice',
          onPressed: () => showCalculator(context),
        ),
        IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
      ],
    );
  }
}
