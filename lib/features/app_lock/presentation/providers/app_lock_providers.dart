import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pin_storage_service.dart';
import '../../data/recovery_code_service.dart';

final pinStorageServiceProvider = Provider<PinStorageService>((ref) {
  return PinStorageService();
});

final recoveryCodeServiceProvider = Provider<RecoveryCodeService>((ref) {
  return RecoveryCodeService();
});

enum AppLockPhase {
  /// Chargement initial : on vérifie si un mot de passe existe déjà.
  loading,

  /// Aucun mot de passe configuré : premier lancement, l'utilisateur
  /// doit en créer un avant d'accéder à l'app (connexion obligatoire).
  needsSetup,

  /// Un mot de passe existe et n'a pas encore été saisi lors de cette
  /// ouverture.
  locked,

  /// Mot de passe vérifié avec succès pour cette session.
  unlocked,
}

class AppLockState {
  final AppLockPhase phase;

  const AppLockState({this.phase = AppLockPhase.loading});

  AppLockState copyWith({AppLockPhase? phase}) {
    return AppLockState(phase: phase ?? this.phase);
  }
}

class AppLockController extends StateNotifier<AppLockState> {
  final PinStorageService _pinStorage;

  AppLockController(this._pinStorage) : super(const AppLockState()) {
    _init();
  }

  Future<void> _init() async {
    final hasPassword = await _pinStorage.hasPin();
    state = state.copyWith(
      phase: hasPassword ? AppLockPhase.locked : AppLockPhase.needsSetup,
    );
  }

  /// Appelé après une saisie réussie (création ou connexion).
  void unlock() {
    state = state.copyWith(phase: AppLockPhase.unlocked);
  }

  /// Définit le mot de passe (création initiale ou modification).
  Future<void> setPassword(String password) async {
    await _pinStorage.setPin(password);
    state = state.copyWith(phase: AppLockPhase.unlocked);
  }

  Future<bool> verify(String password) async {
    final ok = await _pinStorage.verifyPin(password);
    if (ok) unlock();
    return ok;
  }

  /// Reverrouille l'app (retour à l'écran de connexion) sans toucher au
  /// mot de passe.
  void lockAgain() {
    state = state.copyWith(phase: AppLockPhase.locked);
  }
}

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(ref.read(pinStorageServiceProvider));
});
