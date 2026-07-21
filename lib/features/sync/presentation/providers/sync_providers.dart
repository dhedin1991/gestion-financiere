import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/sync_client_service.dart';
import '../../data/sync_server_service.dart';

enum SyncStatus { idle, serverRunning, connecting, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? serverIpAddress;
  final String? serverPin;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.idle,
    this.serverIpAddress,
    this.serverPin,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? serverIpAddress,
    String? serverPin,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      serverIpAddress: serverIpAddress ?? this.serverIpAddress,
      serverPin: serverPin ?? this.serverPin,
      errorMessage: errorMessage,
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

  /// Se connecte à l'appareil serveur indiqué et remplace toutes les
  /// données locales par celles de cet appareil. [pin] doit être le code
  /// affiché sur l'appareil qui partage.
  Future<void> syncFromServer(String ipAddress, String pin) async {
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

      // Ferme proprement la base de données locale avant de remplacer
      // son fichier, pour éviter toute corruption.
      await appDatabase.close();

      await client.downloadAndReplace(ipAddress, pin, appDatabase);

      // Force tous les providers de l'app à recréer une nouvelle connexion
      // vers le fichier fraîchement remplacé.
      _ref.invalidate(appDatabaseProvider);

      state = state.copyWith(status: SyncStatus.success);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, errorMessage: e.toString());
    }
  }

  void reset() {
    state = const SyncState();
  }
}
