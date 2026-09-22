import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_file_utils.dart';
import '../../../core/utils/app_logger.dart';
import 'database_merge_service.dart';
import 'dart:convert';

class SyncClientService {
  static const int port = 8085;

  /// Vérifie qu'un appareil à cette adresse IP répond bien et qu'il s'agit
  /// de la bonne application, avant de lancer le vrai transfert.
  Future<bool> checkConnection(String ipAddress) async {
    try {
      final uri = Uri.parse('http://$ipAddress:$port/ping');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 && response.body.contains('gestion_financiere');
    } catch (e) {
      // Cas fréquent et attendu (mauvais réseau, appareil éteint...),
      // pas une vraie erreur applicative : log en debug uniquement.
      AppLogger.debug('Connexion au serveur de sync impossible : $e', name: 'sync_client');
      return false;
    }
  }

  /// Date de dernière modification de la base de l'appareil distant
  /// (null si indisponible : ancienne version de l'app, réseau...).
  Future<DateTime?> fetchRemoteModified(String ipAddress) async {
    try {
      final uri = Uri.parse('http://$ipAddress:$port/ping');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final value = data is Map ? data['modified'] : null;
      return value is String ? DateTime.tryParse(value)?.toLocal() : null;
    } catch (_) {
      return null;
    }
  }

  /// Date de dernière modification de la base locale.
  Future<DateTime?> localModified() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(join(directory.path, 'gestion_financiere.db'));
      return file.existsSync() ? file.lastModifiedSync() : null;
    } catch (_) {
      return null;
    }
  }

  /// Télécharge la base de données de l'appareil serveur, la VÉRIFIE, puis
  /// remplace le fichier local (après en avoir fait une copie de sécurité).
  ///
  /// Ordre volontaire : téléchargement et vérification AVANT toute
  /// modification locale. Si quoi que ce soit échoue (mauvais code, réponse
  /// qui n'est pas une base SQLite, version trop récente...), la base locale
  /// n'a pas été touchée et reste ouverte.
  ///
  /// [pin] doit correspondre au code affiché sur l'appareil qui partage ;
  /// sans lui (ou s'il est faux), le serveur refuse la requête (401).
  Future<void> downloadAndReplace(String ipAddress, String pin, AppDatabase appDatabase) async {
    final uri = Uri.parse('http://$ipAddress:$port/database?pin=${Uri.encodeQueryComponent(pin)}');
    final response = await http.get(uri).timeout(const Duration(minutes: 2));

    if (response.statusCode == 401) {
      throw Exception('Code PIN incorrect. Vérifie le code affiché sur l\'appareil qui partage.');
    }
    if (response.statusCode != 200) {
      throw Exception('L\'appareil distant n\'a pas pu envoyer la base de données (code ${response.statusCode})');
    }

    // 1) Vérification du contenu reçu.
    final remoteVersion = DatabaseFileUtils.userVersionFromBytes(response.bodyBytes);
    if (remoteVersion == null || remoteVersion < 1) {
      throw Exception('Les données reçues ne sont pas une base de données valide. Rien n\'a été modifié.');
    }
    if (remoteVersion > AppDatabase.schemaVersion) {
      throw Exception(
        'L\'autre appareil utilise une version plus récente de l\'application. '
        'Mets d\'abord à jour cet appareil, puis recommence. Rien n\'a été modifié.',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, 'gestion_financiere.db');

    // 2) Écriture dans un fichier temporaire (jamais directement sur la base).
    final tempFile = File('$dbPath.tmp');
    await tempFile.writeAsBytes(response.bodyBytes, flush: true);

    // 3) Seulement maintenant : fermeture de la base locale, copie de
    //    sécurité, nettoyage des fichiers annexes, puis remplacement.
    await appDatabase.close();

    final finalFile = File(dbPath);
    if (finalFile.existsSync()) {
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      await finalFile.copy(join(directory.path, 'avant_synchronisation_$stamp.db'));
      finalFile.deleteSync();
    }
    DatabaseFileUtils.deleteSidecars(dbPath);
    await tempFile.rename(dbPath);
    DatabaseFileUtils.pruneSafetyCopies(directory);

    AppLogger.info('Base remplacée par la copie de $ipAddress (v$remoteVersion)', name: 'sync_client');
  }

  /// Comme [downloadAndReplace], mais FUSIONNE les données distantes dans la
  /// base locale au lieu de tout remplacer (voir DatabaseMergeService) :
  /// les opérations propres à chaque appareil depuis la dernière
  /// synchronisation sont conservées des deux côtés.
  ///
  /// La base locale n'est jamais fermée ni remplacée. Une copie de sécurité
  /// (`avant_fusion_...`) est prise juste avant, par précaution, même si la
  /// fusion elle-même n'écrase aucune donnée existante — seulement des
  /// nouveautés ajoutées ou des cases précises mises à jour (voir le détail
  /// des règles dans DatabaseMergeService).
  ///
  /// Retourne le nombre d'éléments ajoutés, par type, pour affichage.
  Future<Map<String, int>> downloadAndMerge(
      String ipAddress, String pin, AppDatabase appDatabase) async {
    final uri = Uri.parse('http://$ipAddress:$port/database?pin=${Uri.encodeQueryComponent(pin)}');
    final response = await http.get(uri).timeout(const Duration(minutes: 2));

    if (response.statusCode == 401) {
      throw Exception('Code PIN incorrect. Vérifie le code affiché sur l\'appareil qui partage.');
    }
    if (response.statusCode != 200) {
      throw Exception('L\'appareil distant n\'a pas pu envoyer la base de données (code ${response.statusCode})');
    }

    final remoteVersion = DatabaseFileUtils.userVersionFromBytes(response.bodyBytes);
    if (remoteVersion == null || remoteVersion < 1) {
      throw Exception('Les données reçues ne sont pas une base de données valide. Rien n\'a été modifié.');
    }
    if (remoteVersion != AppDatabase.schemaVersion) {
      throw Exception(
        'La fusion demande que les deux appareils utilisent exactement la même '
        'version de l\'application. Mets-les à jour, puis recommence. Rien n\'a été modifié.',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, 'gestion_financiere.db');
    final tempFile = File('$dbPath.merge_tmp');
    await tempFile.writeAsBytes(response.bodyBytes, flush: true);

    try {
      final db = await appDatabase.database;

      // Copie de sécurité de l'état AVANT fusion (jamais fermée, snapshot
      // cohérent même avec la base ouverte).
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      await db.rawQuery('VACUUM INTO ?', [join(directory.path, 'avant_fusion_$stamp.db')]);
      DatabaseFileUtils.pruneSafetyCopies(directory);

      final added = await DatabaseMergeService(db).mergeFrom(tempFile.path);
      AppLogger.info('Fusion avec $ipAddress terminée : $added', name: 'sync_client');
      return added;
    } finally {
      if (tempFile.existsSync()) await tempFile.delete();
    }
  }
}
