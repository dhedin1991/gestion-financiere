import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/external_activity_guard.dart';

/// En-tête binaire présent en début de tout fichier SQLite valide
/// ("SQLite format 3\0"), utilisé pour vérifier qu'un fichier choisi par
/// l'utilisateur est bien une base de données avant de l'utiliser pour
/// écraser les données actuelles.
final Uint8List _sqliteMagicHeader = Uint8List.fromList(
  'SQLite format 3\u0000'.codeUnits,
);

class InvalidBackupFileException implements Exception {
  final String message;
  const InvalidBackupFileException(this.message);
  @override
  String toString() => message;
}

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

    await ExternalActivityGuard.run(() => Share.shareXFiles(
      [XFile(backupFile.path)],
      subject: 'Sauvegarde $kAppName',
      text: 'Sauvegarde de tes données — garde ce fichier en lieu sûr, il n\'est pas chiffré.',
    ));
  }

  /// Ouvre le sélecteur de fichier, valide qu'il s'agit bien d'une base
  /// SQLite, fait une copie de sécurité de la base actuelle, puis
  /// remplace la base de données actuelle par le fichier choisi.
  /// L'appelant doit avoir fermé la base (`AppDatabase.close()`) avant
  /// d'appeler cette méthode.
  ///
  /// Retourne `false` si l'utilisateur a annulé la sélection.
  /// Lève [InvalidBackupFileException] si le fichier choisi n'est pas une
  /// base de données SQLite valide — dans ce cas, rien n'est modifié.
  Future<bool> restoreBackup() async {
    final result = await ExternalActivityGuard.run(() => FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      dialogTitle: 'Choisir un fichier de sauvegarde (.db)',
    ));
    if (result == null || result.files.single.path == null) return false;

    final pickedFile = File(result.files.single.path!);

    if (!await _looksLikeSqliteDatabase(pickedFile)) {
      AppLogger.warning(
        'Restauration refusée : fichier choisi non reconnu comme base SQLite (${pickedFile.path})',
        name: 'backup',
      );
      throw const InvalidBackupFileException(
        'Ce fichier ne ressemble pas à une sauvegarde valide de $kAppName. '
        'Aucune donnée n\'a été modifiée.',
      );
    }

    // Copie de sécurité de la base actuelle avant de l'écraser : en cas
    // de mauvaise sélection (fichier de sauvegarde trop ancien, par
    // exemple), les données d'avant restauration restent récupérables
    // manuellement dans le dossier de l'app.
    try {
      final currentDbFile = File(await _dbPath());
      if (await currentDbFile.exists()) {
        final directory = await getApplicationDocumentsDirectory();
        final safetyName =
            'avant_restauration_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db';
        await currentDbFile.copy(p.join(directory.path, safetyName));
      }
    } catch (e, stackTrace) {
      // On ne bloque pas la restauration si la copie de sécurité échoue
      // (ex : espace disque insuffisant), mais on le journalise : c'est
      // une dégradation du filet de sécurité, pas une erreur bloquante.
      AppLogger.error(
        'Échec de la copie de sécurité avant restauration',
        name: 'backup',
        error: e,
        stackTrace: stackTrace,
      );
    }

    await pickedFile.copy(await _dbPath());
    return true;
  }

  Future<bool> _looksLikeSqliteDatabase(File file) async {
    try {
      final raf = await file.open();
      try {
        final header = await raf.read(_sqliteMagicHeader.length);
        if (header.length != _sqliteMagicHeader.length) return false;
        for (var i = 0; i < header.length; i++) {
          if (header[i] != _sqliteMagicHeader[i]) return false;
        }
        return true;
      } finally {
        await raf.close();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Impossible de lire l\'en-tête du fichier choisi', name: 'backup', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
