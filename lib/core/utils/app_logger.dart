import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

  static File? _logFile;
  static const int _maxLogBytes = 200 * 1024;

  /// Chemin du journal d'erreurs (null tant que [initFileLogging] n'a pas
  /// réussi). Les avertissements et erreurs y sont conservés pour pouvoir
  /// diagnostiquer un plantage après coup, même en version release.
  static String? get logFilePath => _logFile?.path;

  static Future<void> initFileLogging() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}journal_erreurs.log');
      if (file.existsSync() && file.lengthSync() > _maxLogBytes) {
        final content = file.readAsStringSync();
        file.writeAsStringSync(content.substring(content.length - _maxLogBytes ~/ 2));
      }
      _logFile = file;
      _write('INFO', 'Démarrage de l\'app', null, null);
    } catch (_) {
      // Le journal est un confort : jamais bloquant.
    }
  }

  static void _write(String level, String message, Object? error, StackTrace? stackTrace) {
    final file = _logFile;
    if (file == null) return;
    try {
      final buffer = StringBuffer()
        ..write(DateTime.now().toIso8601String())
        ..write(' [$level] ')
        ..write(message);
      if (error != null) buffer.write(' | $error');
      if (stackTrace != null) {
        buffer
          ..write('\n')
          ..write(stackTrace.toString().split('\n').take(15).join('\n'));
      }
      buffer.write('\n');
      file.writeAsStringSync(buffer.toString(), mode: FileMode.append, flush: true);
    } catch (_) {}
  }

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
    _write('WARN', '[$name] $message', null, null);
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
    _write('ERREUR', '[$name] $message', error, stackTrace);
  }
}
