import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Provider unique et global de la base de données.
///
/// Toute la chaîne de dépendances (DAO -> Repository -> UseCase -> ViewModel)
/// remonte jusqu'à ce provider. C'est le seul endroit de toute l'app où
/// `AppDatabase()` est instancié — respecte le principe d'injection de
/// dépendances (aucune couche ne crée sa propre instance de base).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
