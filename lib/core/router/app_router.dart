import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../navigation/modules.dart';
import '../shell/app_shell.dart';

/// Provider unique du routeur : toutes les routes viennent du registre
/// des modules (`kModules`), enveloppées dans la coque [AppShell].
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          for (final m in kModules)
            GoRoute(
              path: m.route,
              builder: (context, state) => m.builder(),
            ),
        ],
      ),
    ],
  );
});
