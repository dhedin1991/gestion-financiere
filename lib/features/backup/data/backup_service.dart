import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';

/// Sauvegarde/restauration manuelle, indépendante du sync Wi-Fi : exporte
/// une copie du fichier de base de données vers un emplacement choisi par
/// l'utilisateur (Drive, clé USB...), et permet de la réimporter plus
/// tard.
///
/// Contrairement au sync, ce fichier n'est PAS chiffré (le chiffrement de
/// la base a été écarté — voir la conversation) : l'utilisateur est donc
/// responsable de la sécurité de l'endroit où il stocke sa sauvegarde.
class BackupService {
  Future<String> _dbPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'gestion_financiere.db');
  }

  Future<void> exportBackup() async {
    final dbFile = File(await _dbPath());
    if (!await dbFile.exists()) {
      throw Exception('Base de données introuvable.');
    }

    final tempDir = await getTemporaryDirectory();
    final backupName =
        'sauvegarde_gestion_financiere_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.db';
    final backupFile = await dbFile.copy(p.join(tempDir.path, backupName));

    await Share.shareXFiles(
      [XFile(backupFile.path)],
      subject: 'Sauvegarde $kAppName',
      text: 'Sauvegarde de tes données — garde ce fichier en lieu sûr, il n\'est pas chiffré.',
    );
  }

  /// Ouvre le sélecteur de fichier, puis remplace la base de données
  /// actuelle par le fichier choisi. L'appelant doit avoir fermé la base
  /// (AppDatabase.close()) avant d'appeler cette méthode.
  ///
  /// Retourne false si l'utilisateur a annulé la sélection.
  Future<bool> restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Choisir un fichier de sauvegarde (.db)',
    );
    if (result == null || result.files.single.path == null) return false;

    final pickedFile = File(result.files.single.path!);
    await pickedFile.copy(await _dbPath());
    return true;
  }
}
