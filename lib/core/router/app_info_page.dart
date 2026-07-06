import 'package:flutter/material.dart';

class AppInfoPage extends StatelessWidget {
  const AppInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Infos application')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Les statistiques détaillées et l\'espace de stockage utilisé '
            'seront affichés ici prochainement.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
