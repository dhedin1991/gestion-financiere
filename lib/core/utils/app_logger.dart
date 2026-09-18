import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logger minimal, sans dépendance externe (repose uniquement sur
/// `dart:developer`, déjà inclus dans le SDK Flutter).
///
/// Corrige une anomalie relevée dans l'audit : le code ne contenait
/// aucune trace d'erreur (`print`/logger), et plusieurs `catch (_) {}`
/// avalaient silencieusement les exceptions — impossible de diagnostiquer
/// un problème remonté par un utilisateur.
///
/// Pour une vraie mise en production à grande échelle, l'étape suivante
/// recommandée est de brancher un outil de collecte d'erreurs (Sentry ou
/// Firebase Crashlytics) sur [AppLogger.error] afin de recevoir les
/// rapports de plantage à distance — non fait ici pour ne pas ajouter de
/// dépendance/service externe non validé.
class AppLogger {
  AppLogger._();

  static void debug(String message, {String name = 'app'}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: 500);
    }
  }

  static void info(String message, {String name = 'app'}) {
    developer.log(message, name: name, level: 800);
  }

  static void warning(String message, {String name = 'app'}) {
    developer.log(message, name: name, level: 900);
  }

  static void error(
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
