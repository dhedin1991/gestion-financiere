import 'package:flutter/material.dart';

/// Logo simple de l'application : un bouclier (sécurité/stabilité) avec
/// une courbe de croissance à l'intérieur (finance/croissance). Composé
/// d'icônes Material superposées plutôt qu'une image, pour rester léger
/// et net à toutes les résolutions.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLogo({super.key, this.size = 72, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield, size: size, color: c),
          Icon(Icons.trending_up_rounded, size: size * 0.5, color: Colors.white),
        ],
      ),
    );
  }
}
