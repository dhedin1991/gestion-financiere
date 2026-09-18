import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prépare le bon "moteur" SQLite selon la plateforme.
///
/// - Sur Android/iOS : sqflite fonctionne nativement, rien à faire.
/// - Sur Windows/Linux/macOS (desktop) : il faut activer `sqflite_common_ffi`,
///   sinon l'application plante au premier accès à la base de données.
class DatabaseInitializer {
  static Future<void> initialize() async {
    if (kIsWeb) {
      // Le Web n'est pas dans le périmètre V1 (prévu pour plus tard).
      return;
    }

    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (isDesktop) {
      // Active l'implémentation FFI de sqflite pour desktop.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Sur Android, databaseFactory par défaut de sqflite suffit.
  }
}
