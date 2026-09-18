import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/database_initializer.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';
import 'features/app_lock/presentation/pages/login_page.dart';
import 'features/app_lock/presentation/pages/password_setup_page.dart';
import 'features/app_lock/presentation/providers/app_lock_providers.dart';
import 'features/app_lock/presentation/providers/auto_lock_delay_provider.dart';
import 'features/reminders/presentation/providers/reminder_providers.dart';
import 'features/recurring/presentation/providers/recurring_providers.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/onboarding/presentation/providers/onboarding_providers.dart';

Future<void> main() async {
  // Nécessaire avant tout appel asynchrone au démarrage.
  WidgetsFlutterBinding.ensureInitialized();

  // Charge les formats de date/montant en français (obligatoire pour
  // que NumberFormat/DateFormat locale 'fr_FR' fonctionnent, sinon crash).
  await initializeDateFormatting('fr_FR', null);

  // Initialise SQLite correctement selon la plateforme
  // (mobile natif vs Windows/desktop qui a besoin de sqflite_common_ffi).
  await DatabaseInitializer.initialize();

  runApp(
    // ProviderScope = racine Riverpod, indispensable pour que
    // tous les providers de l'app fonctionnent.
    const ProviderScope(
      child: GestionFinanciereApp(),
    ),
  );
}

class GestionFinanciereApp extends ConsumerStatefulWidget {
  const GestionFinanciereApp({super.key});

  @override
  ConsumerState<GestionFinanciereApp> createState() => _GestionFinanciereAppState();
}

class _GestionFinanciereAppState extends ConsumerState<GestionFinanciereApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Corrige l'anomalie relevée dans l'audit : `lockAgain()` existait
    // déjà mais n'était appelé nulle part, donc l'app ne se reverrouillait
    // jamais automatiquement en arrière-plan.
    final lockPhase = ref.read(appLockControllerProvider).phase;
    if (lockPhase != AppLockPhase.unlocked) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt == null) return;

      final delay = ref.read(autoLockDelayProvider).duration;
      final elapsed = DateTime.now().difference(backgroundedAt);
      if (elapsed >= delay) {
        ref.read(appLockControllerProvider.notifier).lockAgain();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final lockPhase = ref.watch(appLockControllerProvider).phase;

    // Tant que le verrouillage n'a pas tranché (chargement, code à saisir,
    // ou création du premier code), on affiche un MaterialApp minimal
    // dédié à cet écran — le vrai contenu financier (router, dashboard...)
    // n'est jamais construit avant que l'utilisateur soit authentifié.
    if (lockPhase == AppLockPhase.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (lockPhase == AppLockPhase.locked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        home: const LoginPage(),
      );
    }

    if (lockPhase == AppLockPhase.needsSetup) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        home: const PasswordSetupPage(),
      );
    }

    final onboardingSeen = ref.watch(onboardingSeenProvider);
    if (onboardingSeen.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (onboardingSeen.valueOrNull == false) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        home: OnboardingPage(onDone: () => ref.invalidate(onboardingSeenProvider)),
      );
    }

    final router = ref.watch(appRouterProvider);
    ref.watch(reminderBootstrapProvider);
    ref.watch(recurringGenerationBootstrapProvider);

    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(themePreset),
      darkTheme: AppTheme.dark(themePreset),
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
