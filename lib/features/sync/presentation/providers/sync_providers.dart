import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/sync_client_service.dart';
import '../../data/sync_server_service.dart';

enum SyncStatus { idle, serverRunning, connecting, syncing, success, error }

enum SyncMode { merge, replace }

class SyncState {
  final SyncStatus status;
  final String? serverIpAddress;
  final String? serverPin;
  final String? errorMessage;
  final Map<String, int>? mergeSummary;

  const SyncState({
    this.status = SyncStatus.idle,
    this.serverIpAddress,
    this.serverPin,
    this.errorMessage,
    this.mergeSummary,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? serverIpAddress,
    String? serverPin,
    String? errorMessage,
    Map<String, int>? mergeSummary,
  }) {
    return SyncState(
      status: status ?? this.status,
      serverIpAddress: serverIpAddress ?? this.serverIpAddress,
      serverPin: serverPin ?? this.serverPin,
      errorMessage: errorMessage,
      mergeSummary: mergeSummary ?? this.mergeSummary,
    );
  }
}

final syncServerServiceProvider = Provider<SyncServerService>((ref) {
  final service = SyncServerService();
  ref.onDispose(() => service.stop());
  return service;
});

final syncClientServiceProvider = Provider<SyncClientService>((ref) {
  return SyncClientService();
});

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});

class SyncController extends StateNotifier<SyncState> {
  final Ref _ref;

  SyncController(this._ref) : super(const SyncState());

  /// Démarre ce téléphone/PC comme "serveur" : les autres appareils sur le
  /// même Wi-Fi pourront venir chercher une copie de ses données.
  Future<void> startServer() async {
    try {
      final server = _ref.read(syncServerServiceProvider);
      final ip = await server.start();
      state = state.copyWith(status: SyncStatus.serverRunning, serverIpAddress: ip, serverPin: server.pin);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> stopServer() async {
    final server = _ref.read(syncServerServiceProvider);
    await server.stop();
    state = const SyncState();
  }

  /// Se connecte à l'appareil serveur indiqué.
  ///
  /// [mode] `merge` (par défaut, recommandé) : combine les données des deux
  /// appareils — rien n'est perdu de part et d'autre, voir
  /// DatabaseMergeService. Demande que les deux appareils aient exactement
  /// la même version de l'app.
  /// [mode] `replace` : remplace TOUTES les données locales par celles de
  /// l'appareil distant (ancien comportement — à réserver au cas où l'un des
  /// deux appareils n'a aucune donnée utile à garder).
  Future<void> syncFromServer(String ipAddress, String pin, {SyncMode mode = SyncMode.merge}) async {
    state = state.copyWith(status: SyncStatus.connecting, errorMessage: null);

    final client = _ref.read(syncClientServiceProvider);

    final isReachable = await client.checkConnection(ipAddress);
    if (!isReachable) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Impossible de joindre l\'appareil à cette adresse. '
            'Vérifie que les deux appareils sont bien sur le même Wi-Fi et que '
            'le serveur est démarré sur l\'autre appareil.',
      );
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing);

    try {
      final appDatabase = _ref.read(appDatabaseProvider);

      if (mode == SyncMode.merge) {
        // La base locale reste ouverte pendant toute la fusion (voir
        // DatabaseMergeService) : en cas d'échec, elle n'a subi aucune
        // modification destructive.
        final added = await client.downloadAndMerge(ipAddress, pin, appDatabase);
        state = state.copyWith(status: SyncStatus.success, mergeSummary: added);
      } else {
        // Le téléchargement, la vérification et la fermeture propre de la
        // base locale (avant remplacement du fichier) sont gérés dans
        // downloadAndReplace : si le transfert échoue, la base locale reste
        // intacte et ouverte.
        await client.downloadAndReplace(ipAddress, pin, appDatabase);
        state = state.copyWith(status: SyncStatus.success);
      }

      // Force tous les providers de l'app à recréer une nouvelle connexion
      // (utile même après une fusion : les données ont changé sous leurs pieds).
      _ref.invalidate(appDatabaseProvider);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, errorMessage: e.toString());
    }
  }

  void reset() {
    state = const SyncState();
  }
}
