import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _autoLockPrefsKey = 'app_lock_auto_lock_delay_seconds';

/// Délai avant reverrouillage automatique de l'app après une mise en
/// arrière-plan. `0` = verrouillage immédiat (recommandé pour une app
/// financière). Les autres valeurs offrent un compromis confort/sécurité
/// pour l'utilisateur qui jongle entre plusieurs apps.
enum AutoLockDelay {
  immediate(Duration.zero, 'Immédiat'),
  seconds30(Duration(seconds: 30), '30 secondes'),
  minute1(Duration(minutes: 1), '1 minute'),
  minutes5(Duration(minutes: 5), '5 minutes');

  final Duration duration;
  final String label;
  const AutoLockDelay(this.duration, this.label);

  static AutoLockDelay fromSeconds(int seconds) {
    return AutoLockDelay.values.firstWhere(
      (d) => d.duration.inSeconds == seconds,
      orElse: () => AutoLockDelay.immediate,
    );
  }
}

class AutoLockDelayController extends StateNotifier<AutoLockDelay> {
  AutoLockDelayController() : super(AutoLockDelay.immediate) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_autoLockPrefsKey);
    if (seconds != null) {
      state = AutoLockDelay.fromSeconds(seconds);
    }
  }

  Future<void> setDelay(AutoLockDelay delay) async {
    state = delay;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockPrefsKey, delay.duration.inSeconds);
  }
}

final autoLockDelayProvider =
    StateNotifierProvider<AutoLockDelayController, AutoLockDelay>((ref) {
  return AutoLockDelayController();
});
