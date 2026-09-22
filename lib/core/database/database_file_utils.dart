import 'dart:io';
import 'dart:typed_data';

/// Outils sur le *fichier* de la base SQLite (sans l'ouvrir) : validation
/// avant restauration/synchronisation, nettoyage des fichiers annexes et
/// des copies de sécurité.
class DatabaseFileUtils {
  DatabaseFileUtils._();

  static final Uint8List _magic = Uint8List.fromList('SQLite format 3\u0000'.codeUnits);

  /// Retourne la version de schéma (`user_version`) stockée dans l'en-tête
  /// du fichier, ou `null` si le fichier n'est pas une base SQLite.
  static Future<int?> readUserVersion(File file) async {
    try {
      final raf = await file.open();
      try {
        final header = await raf.read(100);
        if (header.length < 64) return null;
        for (var i = 0; i < _magic.length; i++) {
          if (header[i] != _magic[i]) return null;
        }
        return (header[60] << 24) | (header[61] << 16) | (header[62] << 8) | header[63];
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _head(Uint8List bytes) => bytes.length >= 64 ? bytes : null;

  /// Même contrôle que [readUserVersion], à partir d'octets déjà en mémoire
  /// (cas du téléchargement pendant la synchronisation Wi-Fi).
  static int? userVersionFromBytes(Uint8List bytes) {
    final header = _head(bytes);
    if (header == null) return null;
    for (var i = 0; i < _magic.length; i++) {
      if (header[i] != _magic[i]) return null;
    }
    return (header[60] << 24) | (header[61] << 16) | (header[62] << 8) | header[63];
  }

  /// Supprime les fichiers annexes SQLite (`-wal`, `-shm`, `-journal`) d'une
  /// base : après remplacement du fichier principal, des restes de l'ancienne
  /// base pourraient sinon être « rejoués » sur la nouvelle et la corrompre.
  static void deleteSidecars(String dbPath) {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      try {
        final f = File('$dbPath$suffix');
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  static final RegExp _safetyName =
      RegExp(r'^avant_(restauration|synchronisation|fusion|migration_centimes)_.*\.db$');

  /// Ne garde que les [keep] copies de sécurité les plus récentes de chaque
  /// type : sans cela elles s'accumulent indéfiniment (données financières
  /// non chiffrées qui traînent dans le dossier de l'app).
  static void pruneSafetyCopies(Directory dir, {int keep = 3}) {
    try {
      final groups = <String, List<File>>{};
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final m = _safetyName.firstMatch(name);
        if (m == null) continue;
        groups.putIfAbsent(m.group(1)!, () => []).add(entity);
      }
      for (final files in groups.values) {
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        for (final old in files.skip(keep)) {
          try {
            old.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
