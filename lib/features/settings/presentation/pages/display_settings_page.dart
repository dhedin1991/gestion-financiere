import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/display/display_prefs.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_providers.dart';
import '../../../../core/widgets/panel.dart';

/// Paramètres > Affichage : zoom, thème, police, fenêtres, recherche,
/// lisibilité des écritures.
class DisplaySettingsPage extends ConsumerWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(displayPrefsProvider);
    final ctrl = ref.read(displayPrefsProvider.notifier);
    final preset = ref.watch(themePresetProvider);
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Affichage')),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        final left = <Widget>[
          _zoomPanel(context, prefs, ctrl),
          _windowsPanel(context, prefs, ctrl),
          _searchPanel(prefs, ctrl),
        ];
        final right = <Widget>[
          _themePanel(context, ref, preset, prefs, ctrl, colors, scheme),
          _fontPanel(context, prefs, ctrl),
          _readabilityPanel(prefs, ctrl),
        ];
        Widget col(List<Widget> items) => Column(
              children: [for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 14), child: w)],
            );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: col(left)), const SizedBox(width: 14), Expanded(child: col(right))],
              )
            else ...[col(left), col(right)],
          ],
        );
      }),
    );
  }

  // ── Zoom ────────────────────────────────────────────────────────────────
  Widget _zoomPanel(BuildContext context, DisplayPrefs prefs, DisplayPrefsController ctrl) {
    final colors = context.appColors;
    return Panel(
      title: 'Zoom de l’interface',
      trailing: Text('${prefs.zoom} %',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('S’applique à toute l’application, de $kZoomMin % à $kZoomMax %, par pas de $kZoomStep %.',
              style: TextStyle(color: colors.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final z in kZoomSteps)
                ChoiceChip(
                  label: Text('$z %'),
                  selected: prefs.zoom == z,
                  onSelected: (_) => ctrl.setZoom(z),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            OutlinedButton.icon(onPressed: prefs.zoom > kZoomMin ? ctrl.zoomOut : null, icon: const Icon(Icons.remove), label: const Text('Réduire')),
            OutlinedButton.icon(onPressed: prefs.zoom < kZoomMax ? ctrl.zoomIn : null, icon: const Icon(Icons.add), label: const Text('Agrandir')),
            TextButton(onPressed: () => ctrl.setZoom(100), child: const Text('Rétablir 100 %')),
          ]),
          const SizedBox(height: 6),
          Text('Sur Windows : Ctrl + / Ctrl − pour changer de 5 %, Ctrl 0 pour revenir à 100 %.',
              style: TextStyle(fontSize: 12, color: colors.muted)),
        ],
      ),
    );
  }

  // ── Fenêtres ────────────────────────────────────────────────────────────
  static const _layoutBoxes = <WindowLayout, List<Rect>>{
    WindowLayout.tabs: [Rect.fromLTWH(0.04, 0.06, 0.92, 0.88)],
    WindowLayout.cascade: [Rect.fromLTWH(0.04, 0.06, 0.6, 0.6), Rect.fromLTWH(0.2, 0.2, 0.6, 0.6), Rect.fromLTWH(0.36, 0.34, 0.6, 0.6)],
    WindowLayout.columns: [Rect.fromLTWH(0.03, 0.05, 0.3, 0.9), Rect.fromLTWH(0.35, 0.05, 0.3, 0.9), Rect.fromLTWH(0.67, 0.05, 0.3, 0.9)],
    WindowLayout.tiles: [Rect.fromLTWH(0.03, 0.05, 0.46, 0.43), Rect.fromLTWH(0.51, 0.05, 0.46, 0.43), Rect.fromLTWH(0.03, 0.52, 0.46, 0.43), Rect.fromLTWH(0.51, 0.52, 0.46, 0.43)],
  };

  Widget _windowsPanel(BuildContext context, DisplayPrefs prefs, DisplayPrefsController ctrl) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      title: 'Fenêtres (Windows)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fenêtre principale façon explorateur, avec onglets. Les onglets peuvent être détachés et disposés.',
              style: TextStyle(color: colors.muted)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 520 ? 4 : 2;
            final w = (box.maxWidth - 10 * (cols - 1)) / cols;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final l in WindowLayout.values)
                SizedBox(
                  width: w,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => ctrl.update(prefs.copyWith(windowLayout: l)),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: prefs.windowLayout == l ? scheme.primary : colors.border, width: prefs.windowLayout == l ? 1.6 : 1),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AspectRatio(
                          aspectRatio: 1.5,
                          child: LayoutBuilder(builder: (context, b) {
                            return Container(
                              decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.border)),
                              child: Stack(children: [
                                for (final r in _layoutBoxes[l]!)
                                  Positioned(
                                    left: r.left * b.maxWidth,
                                    top: r.top * b.maxHeight,
                                    width: r.width * b.maxWidth,
                                    height: r.height * b.maxHeight,
                                    child: Container(decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: colors.info), borderRadius: BorderRadius.circular(3))),
                                  ),
                              ]),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(l.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(l.hint, style: TextStyle(fontSize: 11, color: colors.muted)),
                      ]),
                    ),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 8),
          _toggle('Autoriser le détachement des onglets en fenêtres', prefs.allowDetach, (v) => ctrl.update(prefs.copyWith(allowDetach: v))),
          _toggle('Ouvrir l’Accueil au démarrage', prefs.openHomeAtStart, (v) => ctrl.update(prefs.copyWith(openHomeAtStart: v))),
          _toggle('Restaurer les fenêtres de la dernière session', prefs.restoreWindows, (v) => ctrl.update(prefs.copyWith(restoreWindows: v))),
        ],
      ),
    );
  }

  Widget _searchPanel(DisplayPrefs prefs, DisplayPrefsController ctrl) {
    return Panel(
      title: 'Recherche',
      child: Column(children: [
        _toggle('Activer la recherche rapide avec Ctrl + K', prefs.searchShortcut, (v) => ctrl.update(prefs.copyWith(searchShortcut: v))),
        _toggle('Inclure les comptes archivés dans les résultats', prefs.searchArchived, (v) => ctrl.update(prefs.copyWith(searchArchived: v))),
      ]),
    );
  }

  // ── Thème ───────────────────────────────────────────────────────────────
  Widget _themePanel(BuildContext context, WidgetRef ref, AppThemePreset current, DisplayPrefs prefs, DisplayPrefsController ctrl, AppColors colors, ColorScheme scheme) {
    return Panel(
      title: 'Thème',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Couleurs de toute l’application.', style: TextStyle(color: colors.muted)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 560 ? 4 : (box.maxWidth >= 360 ? 3 : 2);
          final w = (box.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in AppThemePreset.values)
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => ref.read(themePresetProvider.notifier).setPreset(p),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: current == p ? scheme.primary : colors.border, width: current == p ? 1.6 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        height: 62,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: p.previewBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: p.previewBorder)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(height: 7, width: 34, decoration: BoxDecoration(color: p.swatch, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 5),
                          Expanded(child: Container(decoration: BoxDecoration(color: p.previewPanel, borderRadius: BorderRadius.circular(4), border: Border.all(color: p.previewBorder)))),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Text(p.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 8),
        _toggle('Suivre le mode clair/sombre de l’appareil', prefs.followSystemTheme, (v) => ctrl.update(prefs.copyWith(followSystemTheme: v))),
      ]),
    );
  }

  // ── Police ──────────────────────────────────────────────────────────────
  Widget _fontPanel(BuildContext context, DisplayPrefs prefs, DisplayPrefsController ctrl) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      title: 'Police de l’interface',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Appliquée aux menus, listes et écritures. Les polices sont incluses dans l’application.', style: TextStyle(color: colors.muted)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 520 ? 4 : 2;
          final w = (box.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final f in AppFont.values)
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ctrl.update(prefs.copyWith(font: f)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: prefs.font == f ? scheme.primary : colors.border, width: prefs.font == f ? 1.6 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Aa 4 285 600', style: TextStyle(fontFamily: f.family, fontSize: 17, color: scheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(f.label, style: TextStyle(fontFamily: f.family, fontSize: 11, color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
      ]),
    );
  }

  // ── Écritures et lisibilité ─────────────────────────────────────────────
  Widget _readabilityPanel(DisplayPrefs prefs, DisplayPrefsController ctrl) {
    return Panel(
      title: 'Écritures et lisibilité',
      child: Column(children: [
        _seg<bool>('Police des montants', const [true, false], prefs.tabularAmounts, (v) => v ? 'Chiffres alignés' : 'Proportionnelle', (v) => ctrl.update(prefs.copyWith(tabularAmounts: v))),
        _seg<TextSizeChoice>('Taille du texte', TextSizeChoice.values, prefs.textSize, (v) => v.label, (v) => ctrl.update(prefs.copyWith(textSize: v))),
        _seg<ListDensity>('Densité des listes', ListDensity.values, prefs.density, (v) => v.label, (v) => ctrl.update(prefs.copyWith(density: v))),
        _seg<ThousandsSeparator>('Séparateur des milliers', ThousandsSeparator.values, prefs.separator, (v) => v.label, (v) => ctrl.update(prefs.copyWith(separator: v))),
        _toggle('Mode confidentialité (masquer tous les montants)', prefs.hideAmounts, (v) => ctrl.update(prefs.copyWith(hideAmounts: v))),
      ]),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _seg<T>(String label, List<T> values, T selected, String Function(T) labelOf, ValueChanged<T> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        spacing: 12,
        children: [
          Text(label),
          SegmentedChips<T>(values: values, selected: selected, labelOf: labelOf, onChanged: onChanged),
        ],
      ),
    );
  }
}
