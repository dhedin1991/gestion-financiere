import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';

class SyncClientService {
  static const int port = 8085;

  /// Vérifie qu'un appareil à cette adresse IP répond bien et qu'il s'agit
  /// de la bonne application, avant de lancer le vrai transfert.
  Future<bool> checkConnection(String ipAddress) async {
    try {
      final uri = Uri.parse('http://$ipAddress:$port/ping');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 && response.body.contains('gestion_financiere');
    } catch (_) {
      return false;
    }
  }

  /// Télécharge le fichier de base de données de l'appareil serveur, et
  /// remplace le fichier local par cette copie. La base de données locale
  /// doit avoir été fermée (via AppDatabase.close()) AVANT d'appeler cette
  /// méthode, sinon le remplacement du fichier peut échouer ou corrompre
  /// les données.
  Future<void> downloadAndReplace(String ipAddress, AppDatabase appDatabase) async {
    final uri = Uri.parse('http://$ipAddress:$port/database');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('L\'appareil distant n\'a pas pu envoyer la base de données (code ${response.statusCode})');
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, 'gestion_financiere.db');

    // Écrit d'abord dans un fichier temporaire, puis remplace le fichier
    // final seulement si le téléchargement complet a réussi. Cela évite
    // de se retrouver avec une base de données à moitié écrite en cas
    // de coupure réseau en plein transfert.
    final tempPath = '$dbPath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(response.bodyBytes);

    final finalFile = File(dbPath);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await tempFile.rename(dbPath);
  }
}
