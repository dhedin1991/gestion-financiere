import '../../features/calculator/presentation/calculator_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/providers/account_providers.dart';
import '../../features/app_lock/presentation/providers/app_lock_providers.dart';
import '../../features/backup/presentation/providers/backup_providers.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../branding/app_logo.dart';
import '../constants/app_constants.dart';
import '../display/display_prefs.dart';
import '../navigation/app_drawer.dart';
import '../navigation/favorites.dart';
import '../navigation/modules.dart';
import '../navigation/scaffold_key_provider.dart';
import '../theme/app_theme.dart';
import 'global_search.dart';
import 'workspace.dart';

/// Largeur (après zoom) à partir de laquelle l'interface « poste de travail »
/// (Navigateur, onglets, fenêtres) remplace l'interface mobile.
const double kDesktopBreakpoint = 900;

bool isDesktopWidth(BuildContext context) => MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Coque commune de l'application : mobile (barre du bas + menu) ou
/// poste de travail (barre de menus, recherche, onglets, Navigateur,
/// fenêtres, barre d'état).
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(workspaceProvider.notifier).syncLocation(location);
    });
    return isDesktopWidth(context)
        ? _DesktopShell(location: location, child: widget.child)
        : _MobileShell(location: location, child: widget.child);
  }
}

// ───────────────────────────── Mobile ─────────────────────────────────────

class _MobileShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const _MobileShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = ref.watch(scaffoldKeyProvider);
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    Widget item(IconData icon, IconData activeIcon, String label, String route) {
      final active = location == route;
      return Expanded(
        child: InkWell(
          onTap: () {
            if (!active) context.go(route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 24,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: active ? scheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(2)),
              ),
              Icon(active ? activeIcon : icon, size: 22, color: active ? scheme.primary : colors.muted),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: active ? scheme.onSurface : colors.muted)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: AppDrawer(currentLocation: location),
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(color: scheme.surfaceContainerLow, border: Border(top: BorderSide(color: colors.border))),
          child: Row(children: [
            item(Icons.dashboard_outlined, Icons.dashboard, 'Accueil', '/'),
            item(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Comptes', '/accounts'),
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Nouvelle écriture',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => showTransactionFormSheet(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      child: Icon(Icons.add, color: scheme.onPrimary, size: 28),
                    ),
                  ),
                ),
              ),
            ),
            item(Icons.swap_vert, Icons.swap_vert_circle, 'Écritures', '/transactions'),
            Expanded(
              child: InkWell(
                onTap: () => scaffoldKey.currentState?.openDrawer(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(height: 7),
                    Icon(Icons.menu, size: 22, color: colors.muted),
                    const SizedBox(height: 2),
                    Text('Plus', style: TextStyle(fontSize: 11, color: colors.muted)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────── Windows ────────────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const _DesktopShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = ref.watch(scaffoldKeyProvider);
    final prefs = ref.watch(displayPrefsProvider);
    final ctrl = ref.read(displayPrefsProvider.notifier);
    final ws = ref.read(workspaceProvider.notifier);

    void nextTab() {
      final s = ref.read(workspaceProvider);
      if (s.tabs.length < 2) return;
      final i = s.tabs.indexOf(s.active ?? '');
      context.go(s.tabs[(i + 1) % s.tabs.length]);
    }

    void closeTab() {
      final s = ref.read(workspaceProvider);
      final cur = s.active;
      if (cur == null) return;
      final next = ws.close(cur);
      context.go(next ?? '/');
    }

    final bindings = <ShortcutActivator, VoidCallback>{
      if (prefs.searchShortcut) const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showGlobalSearch(context),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => showTransactionFormSheet(context),
      const SingleActivator(LogicalKeyboardKey.equal, control: true): ctrl.zoomIn,
      const SingleActivator(LogicalKeyboardKey.add, control: true): ctrl.zoomIn,
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): ctrl.zoomIn,
      const SingleActivator(LogicalKeyboardKey.minus, control: true): ctrl.zoomOut,
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): ctrl.zoomOut,
      const SingleActivator(LogicalKeyboardKey.digit0, control: true): () => ctrl.setZoom(100),
      const SingleActivator(LogicalKeyboardKey.tab, control: true): nextTab,
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): closeTab,
    };

    return Scaffold(
      key: scaffoldKey,
      drawer: AppDrawer(currentLocation: location),
      body: CallbackShortcuts(
        bindings: bindings,
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              const _TopBar(),
              const _TabStrip(),
              Expanded(
                child: Row(
                  children: [
                    _NavigatorTree(location: location),
                    Expanded(child: _Workspace(child: child)),
                  ],
                ),
              ),
              const _StatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final prefs = ref.watch(displayPrefsProvider);
    final ctrl = ref.read(displayPrefsProvider.notifier);
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';

    MenuItemButton mi(String label, VoidCallback onTap, {SingleActivator? key}) =>
        MenuItemButton(onPressed: onTap, shortcut: key, child: Text(label));

    final menu = MenuBar(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      children: [
        SubmenuButton(menuChildren: [
          mi('Nouvelle écriture', () => showTransactionFormSheet(context), key: const SingleActivator(LogicalKeyboardKey.keyN, control: true)),
          mi('Nouveau virement', () => showTransferFormSheet(context)),
          mi('Exporter mes données', () => context.go('/export')),
          mi('Sauvegarde & restauration', () => context.go('/backup')),
          mi('Calculatrice', () => showCalculator(context), key: const SingleActivator(LogicalKeyboardKey.f8)),
          mi('Verrouiller', () => ref.read(appLockControllerProvider.notifier).lockAgain()),
        ], child: const Text('Fichier')),
        SubmenuButton(menuChildren: [
          mi('Zoom +', ctrl.zoomIn, key: const SingleActivator(LogicalKeyboardKey.equal, control: true)),
          mi('Zoom −', ctrl.zoomOut, key: const SingleActivator(LogicalKeyboardKey.minus, control: true)),
          mi('Zoom 100 %', () => ctrl.setZoom(100), key: const SingleActivator(LogicalKeyboardKey.digit0, control: true)),
          mi(prefs.hideAmounts ? 'Afficher les montants' : 'Masquer les montants', ctrl.toggleHideAmounts),
          mi('Réglages d’affichage…', () => context.go('/display-settings')),
        ], child: const Text('Affichage')),
        SubmenuButton(menuChildren: [
          for (final l in WindowLayout.values)
            mi('${prefs.windowLayout == l ? '✓ ' : '   '}${l.label}', () => ctrl.update(prefs.copyWith(windowLayout: l))),
          mi('Fermer les autres onglets', () {
            final s = ref.read(workspaceProvider);
            if (s.active != null) ref.read(workspaceProvider.notifier).closeAllExcept(s.active!);
          }),
        ], child: const Text('Fenêtre')),
        SubmenuButton(menuChildren: [
          mi('Taux de change', () => context.go('/exchange-rates')),
          mi('Synchronisation Wi-Fi', () => context.go('/sync')),
          mi('Archives', () => context.go('/archives')),
          mi('Historique des mouvements', () => context.go('/audit-log')),
        ], child: const Text('Outils')),
        SubmenuButton(menuChildren: [
          mi('Mode d’emploi', () => context.go('/help')),
          mi('Infos application', () => context.go('/app-info')),
        ], child: const Text('Aide')),
      ],
    );

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(
        children: [
          AppLogoMark(logo: ref.watch(appLogoProvider), size: 32, tile: true),
          const SizedBox(width: 10),
          Text(kAppNameShort, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 12),
          menu,
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, minWidth: 220),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showGlobalSearch(context),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Row(children: [
                  Icon(Icons.search, size: 18, color: colors.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Rechercher un compte, une écriture, un budget…', style: TextStyle(color: colors.muted, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  if (prefs.searchShortcut)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(4)),
                      child: Text('Ctrl K', style: TextStyle(fontSize: 11, color: colors.muted)),
                    ),
                ]),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: prefs.hideAmounts ? 'Afficher les montants' : 'Masquer les montants',
            icon: Icon(prefs.hideAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: ctrl.toggleHideAmounts,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(6)),
            child: Text(main, style: amountTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
          ),
          IconButton(
            tooltip: 'Calculatrice (F8)',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => showCalculator(context),
          ),
          IconButton(
            tooltip: 'Verrouiller',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => ref.read(appLockControllerProvider.notifier).lockAgain(),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends ConsumerWidget {
  const _TabStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final ws = ref.watch(workspaceProvider);
    final prefs = ref.watch(displayPrefsProvider);
    final wsCtrl = ref.read(workspaceProvider.notifier);

    void closeTab(String route) {
      final next = wsCtrl.close(route);
      if (ws.active == route) context.go(next ?? '/');
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(color: scheme.surfaceContainerLowest, border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final route in ws.tabs)
                  Builder(builder: (context) {
                    final m = moduleForRoute(route);
                    if (m == null) return const SizedBox.shrink();
                    final active = ws.active == route;
                    return GestureDetector(
                      onSecondaryTapUp: (d) async {
                        final choice = await showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(d.globalPosition.dx, d.globalPosition.dy, d.globalPosition.dx, 0),
                          items: [
                            if (prefs.allowDetach) const PopupMenuItem(value: 'detach', child: Text('Détacher en fenêtre')),
                            const PopupMenuItem(value: 'close', child: Text('Fermer l’onglet')),
                            const PopupMenuItem(value: 'others', child: Text('Fermer les autres onglets')),
                          ],
                        );
                        if (choice == 'detach') {
                          wsCtrl.focus(route);
                          ref.read(displayPrefsProvider.notifier).update(prefs.copyWith(windowLayout: WindowLayout.cascade));
                        } else if (choice == 'close') {
                          closeTab(route);
                        } else if (choice == 'others') {
                          wsCtrl.closeAllExcept(route);
                          context.go(route);
                        }
                      },
                      child: InkWell(
                        onTap: () => context.go(route),
                        child: Container(
                          margin: const EdgeInsets.only(right: 2, top: 6),
                          padding: const EdgeInsets.only(left: 12, right: 4),
                          decoration: BoxDecoration(
                            color: active ? scheme.surface : scheme.surfaceContainerLow,
                            border: Border(
                              top: BorderSide(color: active ? scheme.primary : Colors.transparent, width: 2),
                              left: BorderSide(color: colors.border),
                              right: BorderSide(color: colors.border),
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(active ? m.selectedIcon : m.icon, size: 15, color: active ? scheme.primary : colors.muted),
                            const SizedBox(width: 6),
                            Text(m.label, style: TextStyle(fontSize: 13, color: active ? scheme.onSurface : colors.muted)),
                            if (ws.tabs.length > 1)
                              IconButton(
                                tooltip: 'Fermer l’onglet',
                                visualDensity: VisualDensity.compact,
                                iconSize: 15,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close),
                                onPressed: () => closeTab(route),
                              )
                            else
                              const SizedBox(width: 10),
                          ]),
                        ),
                      ),
                    );
                  }),
                PopupMenuButton<String>(
                  tooltip: 'Nouvel onglet',
                  icon: Icon(Icons.add, color: colors.muted),
                  onSelected: (route) => context.go(route),
                  itemBuilder: (_) => [
                    for (final m in kModules.where((m) => m.inNav))
                      PopupMenuItem(value: m.route, child: Row(children: [Icon(m.icon, size: 18), const SizedBox(width: 10), Text(m.label)])),
                  ],
                ),
              ],
            ),
          ),
          if (prefs.allowDetach && prefs.windowLayout == WindowLayout.tabs)
            IconButton(
              tooltip: 'Détacher les onglets en fenêtres',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () => ref.read(displayPrefsProvider.notifier).update(prefs.copyWith(windowLayout: WindowLayout.cascade)),
            ),
          if (prefs.windowLayout != WindowLayout.tabs)
            TextButton.icon(
              onPressed: () => ref.read(displayPrefsProvider.notifier).update(prefs.copyWith(windowLayout: WindowLayout.tabs)),
              icon: const Icon(Icons.tab, size: 16),
              label: const Text('Rattacher'),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _NavigatorTree extends ConsumerWidget {
  final String location;
  const _NavigatorTree({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final favorites = ref.watch(favoritesProvider).map(moduleForRoute).whereType<AppModule>().toList();
    return Container(
      width: 232,
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, border: Border(right: BorderSide(color: colors.border))),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text('NAVIGATEUR', style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)),
          ),
          if (favorites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Text('FAVORIS', style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: colors.muted, fontWeight: FontWeight.w600)),
            ),
            for (final m in favorites) _NavItem(module: m, selected: location == m.route),
          ],
          for (final section in kSections) ...[
            if (section != 'Général')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(section.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: colors.muted, fontWeight: FontWeight.w600)),
              ),
            for (final m in kModules.where((m) => m.inNav && m.section == section))
              _NavItem(module: m, selected: location == m.route),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final AppModule module;
  final bool selected;
  const _NavItem({required this.module, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(module.route);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return InkWell(
      onTap: () => context.go(module.route),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.10) : null,
          border: Border(left: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2)),
        ),
        child: Row(children: [
          Icon(selected ? module.selectedIcon : module.icon, size: 18, color: selected ? scheme.primary : colors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(module.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? scheme.onSurface : null)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(favoritesProvider.notifier).toggle(module.route),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(isFav ? Icons.star : Icons.star_border, size: 16, color: isFav ? scheme.primary : colors.muted.withValues(alpha: 0.6)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final prefs = ref.watch(displayPrefsProvider);
    final ws = ref.watch(workspaceProvider);
    final lastExport = ref.watch(lastExportDateProvider);

    Widget? alert;
    lastExport.whenData((d) {
      final days = d == null ? null : DateTime.now().difference(d).inDays;
      if (days == null || days >= 30) {
        alert = InkWell(
          onTap: () => context.go('/backup'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: colors.warning),
            const SizedBox(width: 4),
            Text(days == null ? 'Aucune sauvegarde exportée' : 'Dernier export il y a $days jours', style: TextStyle(color: colors.warning, fontSize: 12)),
          ]),
        );
      }
    });

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, border: Border(top: BorderSide(color: colors.border))),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 12, color: colors.muted, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
        child: Row(children: [
          Icon(Icons.circle, size: 8, color: colors.positive),
          const SizedBox(width: 6),
          const Text('Hors ligne — données stockées sur cet appareil'),
          if (alert != null) ...[const SizedBox(width: 16), alert!],
          const Spacer(),
          Text('${ws.tabs.length} fenêtre(s)'),
          const SizedBox(width: 16),
          Text('Zoom ${prefs.zoom} %'),
        ]),
      ),
    );
  }
}

// ───────────────────────────── Fenêtres ───────────────────────────────────

class _Workspace extends ConsumerWidget {
  final Widget child;
  const _Workspace({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(displayPrefsProvider);
    final ws = ref.watch(workspaceProvider);
    if (prefs.windowLayout == WindowLayout.tabs || ws.tabs.length < 2) {
      return child;
    }
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      switch (prefs.windowLayout) {
        case WindowLayout.columns:
          return Row(children: [for (final r in ws.tabs) Expanded(child: _Frame(route: r, tiled: true))]);
        case WindowLayout.tiles:
          final n = ws.tabs.length;
          final cols = n <= 2 ? n : (n <= 4 ? 2 : 3);
          final rows = (n / cols).ceil();
          return Column(children: [
            for (var row = 0; row < rows; row++)
              Expanded(
                child: Row(children: [
                  for (var c = 0; c < cols; c++)
                    Expanded(child: (row * cols + c) < n ? _Frame(route: ws.tabs[row * cols + c], tiled: true) : const SizedBox.shrink()),
                ]),
              ),
          ]);
        case WindowLayout.cascade:
        case WindowLayout.tabs:
          return _CascadeArea(size: size);
      }
    });
  }
}

class _CascadeArea extends ConsumerWidget {
  final Size size;
  const _CascadeArea({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(workspaceProvider);
    final ctrl = ref.read(workspaceProvider.notifier);
    Rect rectFor(String route) {
      final saved = ws.rects[route];
      if (saved != null) return saved;
      final i = ws.tabs.indexOf(route);
      return Rect.fromLTWH(16.0 + 34 * i, 14.0 + 30 * i, size.width * 0.62, size.height * 0.72);
    }

    return Stack(
      children: [
        for (final route in ws.zOrder)
          if (ws.tabs.contains(route))
            Builder(builder: (context) {
              final r = rectFor(route);
              return Positioned(
                key: ValueKey('win$route'),
                left: r.left,
                top: r.top,
                width: r.width,
                height: r.height,
                child: _Frame(
                  route: route,
                  onDrag: (d) {
                    final cur = rectFor(route);
                    final nl = (cur.left + d.dx).clamp(-cur.width + 80, size.width - 80);
                    final nt = (cur.top + d.dy).clamp(0.0, size.height - 40);
                    ctrl.setRect(route, Rect.fromLTWH(nl.toDouble(), nt.toDouble(), cur.width, cur.height));
                  },
                  onResize: (d) {
                    final cur = rectFor(route);
                    ctrl.setRect(route, Rect.fromLTWH(cur.left, cur.top, (cur.width + d.dx).clamp(360.0, 4000.0), (cur.height + d.dy).clamp(260.0, 4000.0)));
                  },
                ),
              );
            }),
      ],
    );
  }
}

/// Cadre d'une fenêtre : barre de titre (déplaçable en cascade), bouton
/// fermer, contenu de la page.
class _Frame extends ConsumerWidget {
  final String route;
  final bool tiled;
  final void Function(Offset delta)? onDrag;
  final void Function(Offset delta)? onResize;
  const _Frame({required this.route, this.tiled = false, this.onDrag, this.onResize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = moduleForRoute(route);
    if (m == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final ws = ref.watch(workspaceProvider);
    final focused = ws.active == route;
    final ctrl = ref.read(workspaceProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => ctrl.focus(route),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: focused ? scheme.primary : colors.border, width: focused ? 1.5 : 1),
          borderRadius: tiled ? null : BorderRadius.circular(8),
          boxShadow: tiled ? null : const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                GestureDetector(
                  onPanUpdate: onDrag == null ? null : (d) => onDrag!(d.delta),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    color: focused ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
                    child: Row(children: [
                      Icon(m.icon, size: 15, color: colors.muted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                      IconButton(
                        tooltip: 'Ouvrir seule',
                        iconSize: 15,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.open_in_full),
                        onPressed: () {
                          ctrl.focus(route);
                          context.go(route);
                          final prefs = ref.read(displayPrefsProvider);
                          ref.read(displayPrefsProvider.notifier).update(prefs.copyWith(windowLayout: WindowLayout.tabs));
                        },
                      ),
                      IconButton(
                        tooltip: 'Fermer la fenêtre',
                        iconSize: 15,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          final next = ctrl.close(route);
                          if (ws.active == route) context.go(next ?? '/');
                        },
                      ),
                    ]),
                  ),
                ),
                Divider(height: 1, color: colors.border),
                Expanded(child: ClipRect(child: KeyedSubtree(key: ValueKey('page$route'), child: m.builder()))),
              ],
            ),
            if (onResize != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (d) => onResize!(d.delta),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: Container(width: 18, height: 18, alignment: Alignment.bottomRight, child: Icon(Icons.drag_handle, size: 12, color: colors.muted)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
