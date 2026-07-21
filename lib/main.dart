import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/database_initializer.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';

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

class GestionFinanciereApp extends ConsumerWidget {
  const GestionFinanciereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);

    return MaterialApp.router(
      title: 'Ma Gestion Financière',
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
