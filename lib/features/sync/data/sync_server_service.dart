import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/app_logger.dart';

/// Serveur HTTP local très simple qui permet à un autre appareil, sur le
/// même réseau Wi-Fi, de télécharger une copie complète du fichier de
/// base de données de cet appareil.
///
/// ⚠️ Limite de sécurité connue et assumée : cette connexion se fait en
/// **HTTP non chiffré** (pas de TLS). Sur un réseau Wi-Fi de confiance
/// (domicile/bureau), le risque est faible ; sur un réseau public ou
/// partagé, le trafic pourrait théoriquement être intercepté par un tiers
/// sur le même réseau. Mettre en place un certificat TLS auto-signé avec
/// épinglage serait l'étape naturelle suivante (voir CHANGELOG). En
/// attendant, plusieurs mitigations réduisent fortement la fenêtre de
/// risque :
///   - code d'appairage à 6 chiffres (au lieu de 4) ;
///   - le serveur ne reste ouvert que 10 minutes puis se ferme seul ;
///   - blocage temporaire d'une IP après plusieurs codes erronés
///     (empêche un balayage automatique des 10 000 codes possibles).
class SyncServerService {
  static const int port = 8085;
  static const Duration sessionDuration = Duration(minutes: 10);
  static const int _maxAttemptsPerIp = 5;
  static const Duration _ipBlockDuration = Duration(minutes: 2);

  HttpServer? _server;
  String? _pin;
  DateTime? _startedAt;
  final Map<String, int> _failedAttemptsByIp = {};
  final Map<String, DateTime> _blockedUntilByIp = {};

  bool get isRunning => _server != null;

  /// Le code en cours pour cette session de partage (null si le serveur
  /// n'est pas démarré).
  String? get pin => _pin;

  /// Temps restant avant l'expiration automatique de la session, ou
  /// `null` si le serveur n'est pas démarré.
  Duration? get remainingSessionTime {
    final startedAt = _startedAt;
    if (startedAt == null) return null;
    final remaining = sessionDuration - DateTime.now().difference(startedAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String _generatePin() {
    final random = Random.secure();
    // 6 chiffres (1 000 000 de combinaisons, contre 10 000 pour 4
    // chiffres), y compris avec des zéros en tête (ex: "004217").
    return random.nextInt(1000000).toString().padLeft(6, '0');
  }

  /// Démarre le serveur et retourne l'adresse IP locale à communiquer à
  /// l'autre appareil (ex: 192.168.1.25). Retourne `null` si aucune
  /// adresse Wi-Fi n'a pu être trouvée. Un nouveau code est généré à
  /// chaque démarrage (accessible via [pin]), et la session expire
  /// automatiquement après [sessionDuration].
  Future<String?> start() async {
    if (_server != null) {
      return getLocalIpAddress();
    }

    _pin = _generatePin();
    _startedAt = DateTime.now();
    _failedAttemptsByIp.clear();
    _blockedUntilByIp.clear();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _handleRequests();
    return getLocalIpAddress();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _pin = null;
    _startedAt = null;
    _failedAttemptsByIp.clear();
    _blockedUntilByIp.clear();
  }

  bool get _sessionExpired {
    final startedAt = _startedAt;
    if (startedAt == null) return true;
    return DateTime.now().difference(startedAt) > sessionDuration;
  }

  void _handleRequests() async {
    final server = _server;
    if (server == null) return;

    await for (final request in server) {
      try {
        final remoteIp = request.connectionInfo?.remoteAddress.address ?? 'inconnu';

        if (_sessionExpired) {
          // La session a expiré : on ferme le serveur et on refuse toute
          // requête restante plutôt que de laisser le partage actif
          // indéfiniment.
          request.response.statusCode = 410; // Gone
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"error":"session_expiree"}');
          await request.response.close();
          await stop();
          continue;
        }

        if (request.uri.path == '/ping') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('{"app":"gestion_financiere"}');
          await request.response.close();
        } else if (request.uri.path == '/database') {
          final blockedUntil = _blockedUntilByIp[remoteIp];
          if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
            request.response.statusCode = 429; // Too Many Requests
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"error":"trop_de_tentatives"}');
            await request.response.close();
            continue;
          }

          final providedPin = request.uri.queryParameters['pin'];
          if (_pin == null || providedPin != _pin) {
            final attempts = (_failedAttemptsByIp[remoteIp] ?? 0) + 1;
            _failedAttemptsByIp[remoteIp] = attempts;
            if (attempts >= _maxAttemptsPerIp) {
              _blockedUntilByIp[remoteIp] = DateTime.now().add(_ipBlockDuration);
            }
            request.response.statusCode = 401;
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"error":"pin_invalide"}');
            await request.response.close();
          } else {
            _failedAttemptsByIp.remove(remoteIp);
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
          }
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      } catch (e, stackTrace) {
        AppLogger.error('Erreur lors du traitement d\'une requête de sync', name: 'sync_server', error: e, stackTrace: stackTrace);
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
