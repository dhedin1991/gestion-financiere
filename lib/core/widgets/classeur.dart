import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../utils/app_format.dart';
import 'panel.dart';

/// Les trois façons de consulter une collection (Patrimoine, Épargne...).
enum ViewMode { grille, liste, colonnes }

/// Mode d'affichage mémorisé par rubrique (clé : « patrimoine », « epargne »…).
class ViewModeController extends StateNotifier<ViewMode> {
  final String id;
  ViewModeController(this.id) : super(ViewMode.grille) {
    _load();
  }

  String get _key => 'view_mode_$id';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && mounted) {
        state = ViewMode.values.firstWhere((m) => m.name == saved, orElse: () => ViewMode.grille);
      }
    } catch (_) {}
  }

  Future<void> set(ViewMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}

final viewModeProvider = StateNotifierProvider.family<ViewModeController, ViewMode, String>((ref, id) {
  return ViewModeController(id);
});

/// Une catégorie du classeur (un « intercalaire »).
class ClasseurCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const ClasseurCategory(this.key, this.label, this.icon, this.color);
}

/// Un élément à classer, indépendant du métier (bien, épargne…).
class ClasseurEntry {
  final String id;
  final String title;
  final String? subtitle;
  final String categoryKey;
  final double amount;
  final String currency;
  final double? progress; // 0..1, null si sans objectif
  final String? footnote;
  final DateTime? date;
  final VoidCallback onTap;

  const ClasseurEntry({
    required this.id,
    required this.title,
    this.subtitle,
    required this.categoryKey,
    required this.amount,
    required this.currency,
    this.progress,
    this.footnote,
    this.date,
    required this.onTap,
  });
}

enum ClasseurSort { valeur, nom, recent }

/// Classeur à intercalaires : recherche, tri, catégories et trois
/// présentations (grille, liste, colonnes). À placer dans un ListView.
class ClasseurBoard extends ConsumerStatefulWidget {
  final String storageKey;
  final List<ClasseurEntry> entries;
  final List<ClasseurCategory> categories;
  final String searchHint;

  const ClasseurBoard({
    super.key,
    required this.storageKey,
    required this.entries,
    required this.categories,
    this.searchHint = 'Rechercher…',
  });

  @override
  ConsumerState<ClasseurBoard> createState() => _ClasseurBoardState();
}

class _ClasseurBoardState extends ConsumerState<ClasseurBoard> {
  String? _selected; // null = Tous
  String _query = '';
  ClasseurSort _sort = ClasseurSort.valeur;

  ClasseurCategory _cat(String key) => widget.categories.firstWhere(
        (c) => c.key == key,
        orElse: () => widget.categories.last,
      );

  List<ClasseurEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    final list = widget.entries.where((e) {
      if (_selected != null && e.categoryKey != _selected) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          (e.subtitle ?? '').toLowerCase().contains(q) ||
          _cat(e.categoryKey).label.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case ClasseurSort.valeur:
        list.sort((a, b) => b.amount.compareTo(a.amount));
      case ClasseurSort.nom:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case ClasseurSort.recent:
        list.sort((a, b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
    }
    return list;
  }

  String _money(double v, String currency) => AppFormat.currency(symbol: currency, decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(viewModeProvider(widget.storageKey));
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final countByCat = <String, int>{};
    for (final e in widget.entries) {
      countByCat[e.categoryKey] = (countByCat[e.categoryKey] ?? 0) + 1;
    }
    // Si la catégorie sélectionnée n'a plus d'éléments, retour à « Tous ».
    if (_selected != null && (countByCat[_selected] ?? 0) == 0) _selected = null;

    final shown = _filtered;
    final selectedCat = _selected == null ? null : _cat(_selected!);
    final accent = selectedCat?.color ?? scheme.primary;
    final currency = shown.isNotEmpty ? shown.first.currency : (widget.entries.isNotEmpty ? widget.entries.first.currency : 'XOF');
    final total = shown.fold<double>(0, (a, e) => a + e.amount);

    // ── barre d'outils : recherche, tri, mode ──
    final toolbar = Row(children: [
      Expanded(
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: widget.searchHint,
          ),
        ),
      ),
      const SizedBox(width: 8),
      PopupMenuButton<ClasseurSort>(
        tooltip: 'Trier',
        icon: const Icon(Icons.sort),
        initialValue: _sort,
        onSelected: (v) => setState(() => _sort = v),
        itemBuilder: (_) => const [
          PopupMenuItem(value: ClasseurSort.valeur, child: Text('Du plus élevé au plus bas')),
          PopupMenuItem(value: ClasseurSort.nom, child: Text('Par nom (A → Z)')),
          PopupMenuItem(value: ClasseurSort.recent, child: Text('Les plus récents')),
        ],
      ),
    ]);

    final modeSwitch = SegmentedButton<ViewMode>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: ViewMode.grille, icon: Icon(Icons.grid_view_rounded, size: 18), label: Text('Grille')),
        ButtonSegment(value: ViewMode.liste, icon: Icon(Icons.view_list_rounded, size: 18), label: Text('Liste')),
        ButtonSegment(value: ViewMode.colonnes, icon: Icon(Icons.view_column_rounded, size: 18), label: Text('Colonnes')),
      ],
      selected: {mode},
      onSelectionChanged: (v) => ref.read(viewModeProvider(widget.storageKey).notifier).set(v.first),
    );

    // ── intercalaires ──
    final tabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _FolderTab(
          label: 'Tous',
          icon: Icons.folder_open_outlined,
          count: widget.entries.length,
          color: scheme.primary,
          selected: _selected == null,
          onTap: () => setState(() => _selected = null),
        ),
        for (final c in widget.categories)
          if ((countByCat[c.key] ?? 0) > 0)
            _FolderTab(
              label: c.label,
              icon: c.icon,
              count: countByCat[c.key]!,
              color: c.color,
              selected: _selected == c.key,
              onTap: () => setState(() => _selected = c.key),
            ),
      ]),
    );

    Widget content;
    if (shown.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            _query.isEmpty ? 'Aucun élément dans cet intercalaire.' : 'Aucun résultat pour « $_query ».',
            style: TextStyle(color: colors.muted),
          ),
        ),
      );
    } else {
      // Groupes par catégorie (dans l'ordre du classeur).
      final groups = <ClasseurCategory, List<ClasseurEntry>>{};
      for (final c in widget.categories) {
        final items = shown.where((e) => e.categoryKey == c.key).toList();
        if (items.isNotEmpty) groups[c] = items;
      }
      switch (mode) {
        case ViewMode.liste:
          content = _ListView(groups: groups, showHeaders: _selected == null && groups.length > 1, money: _money);
        case ViewMode.grille:
          content = _GridView(groups: groups, showHeaders: _selected == null && groups.length > 1, money: _money);
        case ViewMode.colonnes:
          content = _ColumnsView(groups: groups, money: _money);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: modeSwitch),
        const SizedBox(height: 12),
        tabs,
        // Corps du classeur, relié à l'intercalaire sélectionné.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(color: accent, width: 3),
              left: BorderSide(color: colors.border),
              right: BorderSide(color: colors.border),
              bottom: BorderSide(color: colors.border),
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${shown.length} élément${shown.length > 1 ? 's' : ''} · ${_money(total, currency)}',
                style: TextStyle(color: colors.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            content,
          ]),
        ),
      ],
    );
  }
}

class _FolderTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FolderTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: selected ? 10 : 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : colors.panel2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(
              top: BorderSide(color: selected ? color : colors.border, width: selected ? 3 : 1),
              left: BorderSide(color: colors.border),
              right: BorderSide(color: colors.border),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: selected ? color : colors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.onSurface : colors.muted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

typedef _Money = String Function(double, String);

class _GroupHeader extends StatelessWidget {
  final ClasseurCategory category;
  final List<ClasseurEntry> items;
  final _Money money;
  const _GroupHeader({required this.category, required this.items, required this.money});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (a, e) => a + e.amount);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(children: [
        Icon(category.icon, size: 16, color: category.color),
        const SizedBox(width: 6),
        Expanded(child: Text(category.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        Text(money(total, items.first.currency), style: amountTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: category.color)),
      ]),
    );
  }
}

/// Barre de progression fine (objectifs d'épargne).
class _Progress extends StatelessWidget {
  final double value;
  final Color color;
  const _Progress(this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 6,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }
}

// ─────────────────────────── LISTE ───────────────────────────

class _ListView extends StatelessWidget {
  final Map<ClasseurCategory, List<ClasseurEntry>> groups;
  final bool showHeaders;
  final _Money money;
  const _ListView({required this.groups, required this.showHeaders, required this.money});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(children: [
      for (final g in groups.entries) ...[
        if (showHeaders) _GroupHeader(category: g.key, items: g.value, money: money),
        for (final e in g.value)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: e.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: g.key.color.withValues(alpha: 0.16),
                  child: Icon(g.key.icon, size: 18, color: g.key.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (e.subtitle != null && e.subtitle!.isNotEmpty)
                      Text(e.subtitle!, style: TextStyle(color: colors.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (e.progress != null) ...[
                      const SizedBox(height: 5),
                      _Progress(e.progress!, g.key.color),
                    ],
                  ]),
                ),
                const SizedBox(width: 12),
                Text(money(e.amount, e.currency), style: amountTextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                Icon(Icons.chevron_right, size: 18, color: colors.muted),
              ]),
            ),
          ),
        if (g.value.isNotEmpty) Divider(height: 1, color: colors.border),
      ],
    ]);
  }
}

// ─────────────────────────── GRILLE ───────────────────────────

class _GridView extends StatelessWidget {
  final Map<ClasseurCategory, List<ClasseurEntry>> groups;
  final bool showHeaders;
  final _Money money;
  const _GridView({required this.groups, required this.showHeaders, required this.money});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 190).floor().clamp(1, 6);
      const gap = 10.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final g in groups.entries) ...[
          if (showHeaders) _GroupHeader(category: g.key, items: g.value, money: money),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final e in g.value) SizedBox(width: w, child: _GridCard(entry: e, category: g.key, money: money))],
          ),
          const SizedBox(height: 10),
        ],
      ]);
    });
  }
}

class _GridCard extends StatelessWidget {
  final ClasseurEntry entry;
  final ClasseurCategory category;
  final _Money money;
  const _GridCard({required this.entry, required this.category, required this.money});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.panel2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: entry.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: category.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9)),
                child: Icon(category.icon, size: 18, color: category.color),
              ),
              const Spacer(),
              if (entry.progress != null)
                Text('${(entry.progress! * 100).round()} %', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: category.color)),
            ]),
            const SizedBox(height: 10),
            Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(entry.subtitle!, style: TextStyle(color: colors.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(money(entry.amount, entry.currency), style: amountTextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: category.color)),
            ),
            if (entry.progress != null) ...[
              const SizedBox(height: 8),
              _Progress(entry.progress!, category.color),
            ],
            if (entry.footnote != null) ...[
              const SizedBox(height: 6),
              Text(entry.footnote!, style: TextStyle(color: colors.muted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────── COLONNES ───────────────────────────

class _ColumnsView extends StatelessWidget {
  final Map<ClasseurCategory, List<ClasseurEntry>> groups;
  final _Money money;
  const _ColumnsView({required this.groups, required this.money});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final g in groups.entries)
          Container(
            width: 250,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.panel2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(g.key.icon, size: 18, color: g.key.color),
                const SizedBox(width: 6),
                Expanded(child: Text(g.key.label, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: g.key.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text('${g.value.length}', style: TextStyle(fontSize: 11, color: g.key.color, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                money(g.value.fold<double>(0, (a, e) => a + e.amount), g.value.first.currency),
                style: amountTextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: g.key.color),
              ),
              Divider(height: 18, color: colors.border),
              for (final e in g.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: e.onTap,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border(left: BorderSide(color: g.key.color, width: 3), top: BorderSide(color: colors.border), right: BorderSide(color: colors.border), bottom: BorderSide(color: colors.border)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (e.subtitle != null && e.subtitle!.isNotEmpty)
                            Text(e.subtitle!, style: TextStyle(color: colors.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(money(e.amount, e.currency), style: amountTextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                          if (e.progress != null) ...[
                            const SizedBox(height: 6),
                            _Progress(e.progress!, g.key.color),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// Ligne d'information d'une fiche (libellé à gauche, valeur à droite).
class FicheRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const FicheRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: colors.muted),
        const SizedBox(width: 10),
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: colors.muted, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}

/// Fiche détaillée d'un élément du classeur (feuille du bas).
Future<T?> showFicheSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: builder,
  );
}

/// Bandeau récapitulatif (Panel) réutilisable : total + répartition.
class ClasseurSummary extends StatelessWidget {
  final String title;
  final String totalText;
  final String caption;
  final Widget? chart;
  final Widget? legend;
  const ClasseurSummary({super.key, required this.title, required this.totalText, required this.caption, this.chart, this.legend});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Panel(
      title: title,
      child: LayoutBuilder(builder: (context, c) {
        final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(totalText, style: amountTextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          ),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(color: colors.muted, fontSize: 12)),
          if (legend != null) ...[const SizedBox(height: 10), legend!],
        ]);
        if (chart == null) return info;
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          chart!,
          const SizedBox(width: 16),
          Expanded(child: info),
        ]);
      }),
    );
  }
}
