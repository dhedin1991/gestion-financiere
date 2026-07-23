import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingSeenKey = 'onboarding_seen';

/// true si l'utilisateur a déjà vu l'écran d'accueil (à ne montrer
/// qu'une seule fois, au tout premier lancement de l'app).
final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingSeenKey) ?? false;
});

class OnboardingController {
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeenKey, true);
  }
}

final onboardingControllerProvider = Provider<OnboardingController>((ref) {
  return OnboardingController();
});
