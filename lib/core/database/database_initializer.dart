import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

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
      if (Platform.isWindows) {
        // Sans cette règle, l'app exige un fichier `sqlite3.dll` posé à côté
        // de l'exécutable : s'il manque (nouveau dossier, nouvelle copie),
        // l'app plante au premier accès à la base, juste après la connexion.
        open.overrideFor(OperatingSystem.windows, _openSqliteOnWindows);
      }
      // Active l'implémentation FFI de sqflite pour desktop.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Sur Android, databaseFactory par défaut de sqflite suffit.
  }
}

/// Cherche d'abord un `sqlite3.dll` fourni avec l'app ; à défaut, utilise la
/// bibliothèque SQLite intégrée à Windows 10/11 (`winsqlite3.dll`).
DynamicLibrary _openSqliteOnWindows() {
  try {
    return DynamicLibrary.open('sqlite3.dll');
  } catch (_) {
    return DynamicLibrary.open('winsqlite3.dll');
  }
}
