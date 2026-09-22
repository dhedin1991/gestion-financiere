import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';

/// Copie de sécurité automatique et silencieuse de la base de données,
/// prise dans le dossier de l'app (le même que les copies « avant
/// migration »/« avant restauration »).
///
/// Ce n'est PAS un remplacement de l'export manuel (Sauvegarde > Exporter,
/// qui ouvre le partage vers Drive, une clé USB...) : ce dossier n'est pas
/// consultable facilement sur Android, et son contenu disparaît si l'app
/// est désinstallée. Son seul but est de protéger contre un bug interne
/// (données corrompues par l'app elle-même) entre deux exports manuels —
/// pas contre la perte du téléphone.
class AutoBackupService {
  static const _prefsKey = 'derniere_sauvegarde_auto';
  static const interval = Duration(days: 7);
  static const keep = 3;

  /// Vrai si la dernière sauvegarde automatique remonte à plus de
  /// [interval], ou n'a jamais eu lieu.
  static bool isDue(DateTime? lastRun, DateTime now) =>
      lastRun == null || now.difference(lastRun) >= interval;

  /// Prend une copie si nécessaire. Ne lève jamais d'exception : une
  /// sauvegarde silencieuse ne doit jamais faire planter l'app ni bloquer
  /// son démarrage.
  Future<void> runIfDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRunMillis = prefs.getInt(_prefsKey);
      final lastRun = lastRunMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastRunMillis);
      final now = DateTime.now();
      if (!isDue(lastRun, now)) return;

      final directory = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(directory.path, 'gestion_financiere.db'));
      if (!await dbFile.exists()) return;

      final stamp = now.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      await dbFile.copy(p.join(directory.path, 'sauvegarde_auto_$stamp.db'));

      _pruneOldCopies(directory);

      await prefs.setInt(_prefsKey, now.millisecondsSinceEpoch);
      AppLogger.info('Sauvegarde automatique effectuée', name: 'auto_backup');
    } catch (e, stackTrace) {
      // Best-effort : une sauvegarde silencieuse ratée ne doit jamais
      // remonter à l'utilisateur ni interrompre le démarrage de l'app.
      AppLogger.error('Sauvegarde automatique impossible', name: 'auto_backup', error: e, stackTrace: stackTrace);
    }
  }

  static final _pattern = RegExp(r'^sauvegarde_auto_.*\.db$');

  void _pruneOldCopies(Directory dir) {
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => _pattern.hasMatch(p.basename(f.path)))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (final old in files.skip(keep)) {
        try {
          old.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
