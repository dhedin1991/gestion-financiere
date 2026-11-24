import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/chart_style.dart';
import '../../../../core/theme/theme_providers.dart';
import '../../../../core/widgets/charts.dart';
import '../../../../core/widgets/panel.dart';
import '../../../dashboard/presentation/pages/home_page.dart' show seriesColor;

/// Personnalisation des graphiques : couleurs (revenus, dépenses, alertes,
/// courbes), palettes prêtes à l'emploi et styles d'affichage. Les changements
/// s'appliquent immédiatement à tous les graphiques de l'application.
class ChartSettingsPage extends ConsumerWidget {
  const ChartSettingsPage({super.key});

  static const _sample = <double>[3, 4, 3.6, 5, 6.2, 5.8, 7.4, 8.1, 7.7, 9.3];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(chartStyleProvider);
    final ctrl = ref.read(chartStyleProvider.notifier);
    final colors = context.appColors;

    Widget colorRow(String label, String hint, Color current, bool custom, void Function(Color) onPick, VoidCallback onClear) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: GestureDetector(
          onTap: () async {
            final c = await showChartColorPicker(context, current);
            if (c != null) onPick(c);
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: current,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border, width: 2),
            ),
          ),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(custom ? 'Couleur personnalisée' : hint),
        trailing: custom ? TextButton(onPressed: onClear, child: const Text('Thème')) : null,
        onTap: () async {
          final c = await showChartColorPicker(context, current);
          if (c != null) onPick(c);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Graphiques')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Aperçu en direct ──
          Panel(
            title: 'Aperçu en direct',
            child: Column(children: [
              LineAreaChart(values: _sample, color: colors.info, height: 110),
              const SizedBox(height: 16),
              Row(children: [
                DonutChart(
                  size: 96,
                  stroke: 14,
                  slices: [for (var i = 0; i < 4; i++) DonutSlice([40.0, 25.0, 20.0, 15.0][i], seriesColor(context, i))],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PairBarChart(
                    labels: const ['Août', 'Sept', 'Oct', 'Nov'],
                    a: const [8, 10, 9, 12],
                    b: const [6, 7, 10, 8],
                    colorA: colors.positive,
                    colorB: colors.negative,
                    height: 110,
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                RingGauge(value: 0.82, color: colors.positive, size: 64, stroke: 8),
                RingGauge(value: 0.45, color: colors.warning, size: 64, stroke: 8),
                RingGauge(value: 0.15, color: colors.negative, size: 64, stroke: 8),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Palettes ──
          Panel(
            title: 'Palettes prêtes à l’emploi',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in kChartPresets)
                ChoiceChip(
                  selected: style.presetId == p.id,
                  onSelected: (_) => ctrl.set(style.withPreset(p)),
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final c in (p.palette ?? [colors.info, colors.positive, colors.negative]).take(4))
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      ),
                    const SizedBox(width: 4),
                    Text(p.label),
                  ]),
                ),
              if (style.presetId == 'perso') const Chip(label: Text('Personnalisée')),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Couleurs ──
          Panel(
            title: 'Couleurs',
            child: Column(children: [
              colorRow('Revenus et progrès', 'Couleur du thème', colors.positive, style.positive != null,
                  (c) => ctrl.set(style.withColors(positive: c)), () => ctrl.set(style.withColors(clearPositive: true))),
              colorRow('Dépenses et retards', 'Couleur du thème', colors.negative, style.negative != null,
                  (c) => ctrl.set(style.withColors(negative: c)), () => ctrl.set(style.withColors(clearNegative: true))),
              colorRow('Alertes et vigilance', 'Couleur du thème', colors.warning, style.warning != null,
                  (c) => ctrl.set(style.withColors(warning: c)), () => ctrl.set(style.withColors(clearWarning: true))),
              colorRow('Courbes et indicateurs', 'Couleur du thème', colors.info, style.line != null,
                  (c) => ctrl.set(style.withColors(line: c)), () => ctrl.set(style.withColors(clearLine: true))),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Styles ──
          Panel(
            title: 'Style d’affichage',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Courbes', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SegmentedButton<ChartLineMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ChartLineMode.smooth, label: Text('Lissée'), icon: Icon(Icons.show_chart)),
                  ButtonSegment(value: ChartLineMode.straight, label: Text('Droite'), icon: Icon(Icons.timeline)),
                  ButtonSegment(value: ChartLineMode.step, label: Text('Escalier'), icon: Icon(Icons.stairs_outlined)),
                ],
                selected: {style.lineMode},
                onSelectionChanged: (v) => ctrl.set(style.copyWith(lineMode: v.first)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aire dégradée sous la courbe'),
                value: style.fillArea,
                onChanged: (v) => ctrl.set(style.copyWith(fillArea: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Quadrillage'),
                value: style.showGrid,
                onChanged: (v) => ctrl.set(style.copyWith(showGrid: v)),
              ),
              Text('Épaisseur du trait : ${style.lineWidth.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                min: 1,
                max: 5,
                divisions: 8,
                value: style.lineWidth.clamp(1.0, 5.0),
                onChanged: (v) => ctrl.set(style.copyWith(lineWidth: v)),
              ),
              const SizedBox(height: 6),
              const Text('Barres', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SegmentedButton<ChartBarShape>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ChartBarShape.rounded, label: Text('Arrondies')),
                  ButtonSegment(value: ChartBarShape.square, label: Text('Carrées')),
                  ButtonSegment(value: ChartBarShape.pill, label: Text('Capsules')),
                ],
                selected: {style.barShape},
                onSelectionChanged: (v) => ctrl.set(style.copyWith(barShape: v.first)),
              ),
              const SizedBox(height: 14),
              Text('Épaisseur des anneaux : ${(style.thickness * 100).round()} %', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                min: 0.6,
                max: 1.6,
                divisions: 10,
                value: style.thickness.clamp(0.6, 1.6),
                onChanged: (v) => ctrl.set(style.copyWith(thickness: v)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: ctrl.reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Rétablir les réglages d’origine'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

const List<Color> _swatches = [
  Color(0xFF2EBD85), Color(0xFF22C55E), Color(0xFF84CC16), Color(0xFF14B8A6), Color(0xFF06B6D4), Color(0xFF0EA5E9),
  Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD946EF), Color(0xFFEC4899), Color(0xFFF43F5E),
  Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFF59E0B), Color(0xFFEAB308), Color(0xFFA16207), Color(0xFF78716C),
  Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF334155), Color(0xFFFFFFFF), Color(0xFF111827), Color(0xFF000000),
];

/// Sélecteur de couleur : nuancier + saisie d'un code (#RRGGBB).
Future<Color?> showChartColorPicker(BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color = widget.initial;
  late final TextEditingController _hex = TextEditingController(text: _toHex(widget.initial));
  String? _error;

  static String _toHex(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _pick(Color c) {
    setState(() {
      _color = c;
      _error = null;
      _hex.text = _toHex(c);
    });
  }

  void _onHex(String v) {
    final t = v.replaceAll('#', '').trim();
    if (t.length == 6 && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(t)) {
      setState(() {
        _color = Color(int.parse('FF$t', radix: 16));
        _error = null;
      });
    } else {
      setState(() => _error = 'Code à 6 caractères, ex. 2EBD85');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir une couleur'),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _swatches)
              GestureDetector(
                onTap: () => _pick(c),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.toARGB32() == _color.toARGB32() ? Theme.of(context).colorScheme.primary : context.appColors.border,
                      width: c.toARGB32() == _color.toARGB32() ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.appColors.border)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hex,
                onChanged: _onHex,
                maxLength: 7,
                decoration: InputDecoration(labelText: 'Code couleur', prefixText: '#', counterText: '', errorText: _error),
              ),
            ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _error == null ? () => Navigator.of(context).pop(_color) : null, child: const Text('Choisir')),
      ],
    );
  }
}
