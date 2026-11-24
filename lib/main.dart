import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/database_initializer.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/external_activity_guard.dart';
import 'core/router/app_router.dart';
import 'features/backup/presentation/providers/backup_providers.dart';
import 'core/constants/app_constants.dart';
import 'core/display/display_prefs.dart';
import 'core/display/display_scope.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/chart_style.dart';
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

  // Journal d'erreurs persistant + capture de toutes les erreurs non
  // gérées : sans cela, une erreur en version release donne un écran
  // blanc/gris sans aucune trace exploitable.
  await AppLogger.initFileLogging();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Erreur Flutter : ${details.exceptionAsString()}',
      name: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLogger.error('Erreur non interceptée', name: 'platform', error: error, stackTrace: stack);
    return true;
  };
  ErrorWidget.builder = (details) => const _ErrorFallback();

  try {
    // Charge les formats de date/montant en français (obligatoire pour
    // que NumberFormat/DateFormat locale 'fr_FR' fonctionnent, sinon crash).
    await initializeDateFormatting('fr_FR', null);

    // Initialise SQLite correctement selon la plateforme
    // (mobile natif vs Windows/desktop qui a besoin de sqflite_common_ffi).
    await DatabaseInitializer.initialize();
  } catch (e, st) {
    AppLogger.error('Échec de l\'initialisation au démarrage', name: 'main', error: e, stackTrace: st);
  }

  runApp(
    // ProviderScope = racine Riverpod, indispensable pour que
    // tous les providers de l'app fonctionnent.
    const ProviderScope(
      child: GestionFinanciereApp(),
    ),
  );
}

/// Remplace l'écran gris/blanc par défaut de Flutter quand un widget plante
/// à l'affichage : message lisible, et le reste de l'écran reste utilisable.
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFFFF3E0),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cette zone n\'a pas pu s\'afficher. Reviens en arrière ou relance l\'app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5D4037), fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
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

    // `inactive` = simple perte de focus (clic hors de la fenêtre sous
    // Windows, barre de notifications, boîte de dialogue système sous
    // Android) : ce n'est PAS une sortie de l'app. Seuls `paused` et
    // `hidden` (app réellement passée en arrière-plan / réduite) comptent.
    // Les sélecteurs de fichier et feuilles de partage de l'app elle-même
    // sont aussi ignorés (voir ExternalActivityGuard).
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (ExternalActivityGuard.isActive) return;
      _backgroundedAt ??= DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;

      if (backgroundedAt != null) {
        final delay = ref.read(autoLockDelayProvider).duration;
        final elapsed = DateTime.now().difference(backgroundedAt);
        if (elapsed >= delay) {
          ref.read(appLockControllerProvider.notifier).lockAgain();
          return;
        }
      }

      // Retour au premier plan sans reverrouillage : rattrape les
      // transactions récurrentes devenues échues pendant que l'app restait
      // ouverte en arrière-plan (sinon elles n'étaient générées qu'au
      // prochain démarrage complet).
      if (!ExternalActivityGuard.isActive) {
        ref.invalidate(recurringGenerationBootstrapProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePreset = ref.watch(themePresetProvider);
    final display = ref.watch(displayPrefsProvider);
    final chart = ref.watch(chartStyleProvider);
    final themes = _resolveThemes(themePreset, display, chart);
    final lockPhase = ref.watch(appLockControllerProvider).phase;

    // Tant que le verrouillage n'a pas tranché (chargement, code à saisir,
    // ou création du premier code), on affiche un MaterialApp minimal
    // dédié à cet écran — le vrai contenu financier (router, dashboard...)
    // n'est jamais construit avant que l'utilisateur soit authentifié.
    if (lockPhase == AppLockPhase.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        builder: displayBuilder,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (lockPhase == AppLockPhase.locked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        builder: displayBuilder,
        home: const LoginPage(),
      );
    }

    if (lockPhase == AppLockPhase.needsSetup) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        builder: displayBuilder,
        home: const PasswordSetupPage(),
      );
    }

    final onboardingSeen = ref.watch(onboardingSeenProvider);
    if (onboardingSeen.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        builder: displayBuilder,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (onboardingSeen.valueOrNull == false) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        builder: displayBuilder,
        home: OnboardingPage(onDone: () => ref.invalidate(onboardingSeenProvider)),
      );
    }

    final router = ref.watch(appRouterProvider);
    ref.watch(reminderBootstrapProvider);
    ref.watch(recurringGenerationBootstrapProvider);
    ref.watch(autoBackupBootstrapProvider);

    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: themes.mode,
      builder: displayBuilder,
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


class _ResolvedThemes {
  final ThemeData light;
  final ThemeData dark;
  final ThemeMode mode;
  const _ResolvedThemes(this.light, this.dark, this.mode);
}

_ResolvedThemes _resolveThemes(AppThemePreset preset, DisplayPrefs d, ChartStyle chart) {
  ThemeData build(AppThemePreset p) => AppTheme.build(p, font: d.font, density: d.density, chart: chart);
  if (d.followSystemTheme) {
    final light = build(preset.isDark ? AppThemePreset.clairPro : preset);
    final dark = build(preset.isDark ? preset : AppThemePreset.nuitBancaire);
    return _ResolvedThemes(light, dark, ThemeMode.system);
  }
  final t = build(preset);
  return _ResolvedThemes(t, t, preset.isDark ? ThemeMode.dark : ThemeMode.light);
}
