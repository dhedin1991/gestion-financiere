import 'package:flutter/material.dart';

import 'app_logger.dart';

/// Convertit une exception technique en message compréhensible pour
/// l'utilisateur, sans jamais afficher le texte brut d'une `Exception`
/// Dart/SQLite (ex: "Exception: FOREIGN KEY constraint failed (code 787)"),
/// qui n'a de sens que pour un développeur et donne une image peu
/// professionnelle de l'application.
///
/// Le détail technique n'est pas perdu pour autant : il est systématiquement
/// journalisé via [AppLogger.error] pour rester diagnosticable.
class AppErrorMessage {
  AppErrorMessage._();

  static String friendly(Object error) {
    final text = error.toString();
    if (text.contains('FOREIGN KEY constraint failed')) {
      return 'Impossible d\'effectuer cette action : des données sont encore liées '
          '(transactions, échéances...). Essaie de les supprimer ou de les déplacer d\'abord.';
    }
    if (text.contains('UNIQUE constraint failed')) {
      return 'Cette valeur existe déjà. Choisis-en une autre.';
    }
    if (text.toLowerCase().contains('socketexception') ||
        text.toLowerCase().contains('connection') ||
        text.toLowerCase().contains('network')) {
      return 'Connexion impossible. Vérifie le réseau Wi-Fi et réessaie.';
    }
    return 'Une erreur inattendue est survenue. Réessaie, et si le problème persiste, '
        'consulte le journal des actions ou contacte le support.';
  }

  /// Journalise l'erreur technique et affiche un message clair à
  /// l'utilisateur dans un `SnackBar`.
  static void showSnackBar(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    String logTag = 'ui',
  }) {
    AppLogger.error('Erreur affichée à l\'utilisateur', name: logTag, error: error, stackTrace: stackTrace);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendly(error)), backgroundColor: Colors.red),
    );
  }
}
