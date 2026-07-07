import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Serveur HTTP local très simple qui permet à un autre appareil, sur le
/// même réseau Wi-Fi, de télécharger une copie complète du fichier de
/// base de données de cet appareil.
class SyncServerService {
  static const int port = 8085;

  HttpServer? _server;

  bool get isRunning => _server != null;

  /// Démarre le serveur et retourne l'adresse IP locale à communiquer
  /// à l'autre appareil (ex: 192.168.1.25). Retourne null si aucune
  /// adresse Wi-Fi n'a pu être trouvée.
  Future<String?> start() async {
    if (_server != null) {
      return getLocalIpAddress();
    }

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _handleRequests();
    return getLocalIpAddress();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _handleRequests() async {
    final server = _server;
    if (server == null) return;

    await for (final request in server) {
      try {
        if (request.uri.path == '/ping') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('{"app":"gestion_financiere"}');
          await request.response.close();
        } else if (request.uri.path == '/database') {
          final directory = await getApplicationDocumentsDirectory();
          final dbPath = join(directory.path, 'gestion_financiere.db');
          final file = File(dbPath);

          if (await file.exists()) {
            request.response.headers.contentType = ContentType.binary;
            await request.response.addStream(file.openRead());
            await request.response.close();
          } else {
            request.response.statusCode = 404;
            await request.response.close();
          }
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      } catch (_) {
        try {
          request.response.statusCode = 500;
          await request.response.close();
        } catch (_) {
          // Le client a peut-être déjà fermé la connexion, on ignore.
        }
      }
    }
  }

  /// Cherche la première adresse IPv4 locale non-loopback (celle du Wi-Fi).
  Future<String?> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return null;
  }
}
