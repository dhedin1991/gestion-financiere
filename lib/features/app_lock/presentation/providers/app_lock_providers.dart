import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pin_storage_service.dart';

final pinStorageServiceProvider = Provider<PinStorageService>((ref) {
  return PinStorageService();
});

enum AppLockPhase {
  /// Chargement initial : on vérifie si un PIN existe déjà.
  loading,

  /// Aucun PIN configuré : on laisse l'app accessible directement (le
  /// verrouillage est une option, pas une obligation).
  noLockConfigured,

  /// Un PIN existe et n'a pas encore été saisi lors de cette ouverture.
  locked,

  /// PIN vérifié avec succès pour cette session.
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
    final hasPin = await _pinStorage.hasPin();
    state = state.copyWith(
      phase: hasPin ? AppLockPhase.locked : AppLockPhase.noLockConfigured,
    );
  }

  /// Appelé après une saisie de PIN réussie (création ou déverrouillage).
  void unlock() {
    state = state.copyWith(phase: AppLockPhase.unlocked);
  }

  /// Active le verrouillage en définissant un nouveau PIN.
  Future<void> enableLock(String pin) async {
    await _pinStorage.setPin(pin);
    state = state.copyWith(phase: AppLockPhase.unlocked);
  }

  /// Désactive le verrouillage (supprime le PIN).
  Future<void> disableLock() async {
    await _pinStorage.clearPin();
    state = state.copyWith(phase: AppLockPhase.noLockConfigured);
  }

  Future<bool> verify(String pin) async {
    final ok = await _pinStorage.verifyPin(pin);
    if (ok) unlock();
    return ok;
  }
}

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(ref.read(pinStorageServiceProvider));
});
