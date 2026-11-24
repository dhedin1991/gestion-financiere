import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/charts.dart';
import '../../../../core/widgets/classeur.dart';
import '../../domain/entities/patrimoine_item.dart';
import '../providers/patrimoine_providers.dart';
import '../widgets/patrimoine_category_ui.dart';
import '../widgets/patrimoine_form_sheet.dart';

/// Patrimoine : un classeur à intercalaires (immobilier, véhicules,
/// matériel…) consultable en grille, en liste ou en colonnes. Chaque bien
/// a une fiche détaillée (modifier, supprimer).
class PatrimoinePage extends ConsumerWidget {
  const PatrimoinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(patrimoineListProvider);
    final totalAsync = ref.watch(patrimoineTotalValueProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Patrimoine'),
        actions: [
          const AppMenuButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(patrimoineListProvider);
              ref.invalidate(patrimoineTotalValueProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPatrimoineForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau bien'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(AppErrorMessage.friendly(err))),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          final dateFmt = DateFormat('dd/MM/yyyy');
          final entries = [
            for (final it in items)
              ClasseurEntry(
                id: 'p${it.id}',
                title: it.nom,
                subtitle: (it.localisation != null && it.localisation!.isNotEmpty) ? it.localisation : it.categorie.label,
                categoryKey: it.categorie.name,
                amount: it.valeurEstimee,
                currency: it.devise,
                footnote: it.dateAcquisition == null ? null : 'Acquis le ${dateFmt.format(it.dateAcquisition!)}',
                date: it.dateAcquisition ?? it.createdAt,
                onTap: () => _showFiche(context, it),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              _Summary(items: items, totalAsync: totalAsync),
              const SizedBox(height: 14),
              ClasseurBoard(
                storageKey: 'patrimoine',
                entries: entries,
                categories: kPatrimoineClasseur,
                searchHint: 'Rechercher un bien, un lieu, une catégorie…',
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFiche(BuildContext context, PatrimoineItem item) {
    showFicheSheet<void>(context, builder: (_) => _Fiche(item: item));
  }
}

void showPatrimoineForm(BuildContext context, {PatrimoineItem? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => PatrimoineFormSheet(existing: existing),
  );
}

class _Summary extends StatelessWidget {
  final List<PatrimoineItem> items;
  final AsyncValue<double> totalAsync;
  const _Summary({required this.items, required this.totalAsync});

  @override
  Widget build(BuildContext context) {
    final fmt = AppFormat.currency(symbol: 'XOF');
    final byCat = <PatrimoineCategory, double>{};
    for (final it in items) {
      byCat[it.categorie] = (byCat[it.categorie] ?? 0) + it.valeurEstimee;
    }
    final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = totalAsync.valueOrNull ?? byCat.values.fold<double>(0, (a, b) => a + b);

    return ClasseurSummary(
      title: 'Valeur totale du patrimoine',
      totalText: totalAsync.isLoading && totalAsync.valueOrNull == null ? '…' : fmt.format(total),
      caption: '${items.length} bien${items.length > 1 ? 's' : ''} · ${byCat.length} catégorie${byCat.length > 1 ? 's' : ''}',
      chart: DonutChart(
        size: 104,
        stroke: 14,
        slices: [for (final e in sorted) DonutSlice(e.value < 0 ? 0 : e.value, e.key.color)],
      ),
      legend: Wrap(spacing: 10, runSpacing: 4, children: [
        for (final e in sorted.take(5))
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: e.key.color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(
              '${e.key.label.split(' ').first} ${total > 0 ? '${(e.value / total * 100).round()} %' : ''}',
              style: TextStyle(fontSize: 11, color: context.appColors.muted),
            ),
          ]),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_work_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucun bien enregistré', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Ajoute un bien immobilier, un terrain, un véhicule ou tout autre élément de ton patrimoine : '
              'ils seront classés par catégorie.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fiche d'un bien : toutes ses informations, de façon structurée.
class _Fiche extends ConsumerWidget {
  final PatrimoineItem item;
  const _Fiche({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final fmt = AppFormat.currency(symbol: item.devise);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final cat = item.categorie;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cat.color.withValues(alpha: 0.16),
              child: Icon(cat.icon, color: cat.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(cat.label, style: TextStyle(color: cat.color, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Valeur estimée', style: TextStyle(color: colors.muted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(fmt.format(item.valeurEstimee), style: amountTextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cat.color)),
            ]),
          ),
          const SizedBox(height: 10),
          FicheRow(icon: Icons.category_outlined, label: 'Catégorie', value: cat.label),
          if (item.dateAcquisition != null)
            FicheRow(icon: Icons.event_outlined, label: 'Date d\'acquisition', value: dateFmt.format(item.dateAcquisition!)),
          if (item.localisation != null && item.localisation!.isNotEmpty)
            FicheRow(icon: Icons.location_on_outlined, label: 'Localisation', value: item.localisation!),
          if (item.description != null && item.description!.isNotEmpty)
            FicheRow(icon: Icons.notes_outlined, label: 'Description', value: item.description!),
          FicheRow(icon: Icons.add_circle_outline, label: 'Ajouté le', value: dateFmt.format(item.createdAt)),
          FicheRow(icon: Icons.update, label: 'Dernière mise à jour', value: dateFmt.format(item.updatedAt)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showPatrimoineForm(context, existing: item);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                style: OutlinedButton.styleFrom(foregroundColor: colors.negative),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce bien ?'),
        content: Text('Voulez-vous vraiment supprimer "${item.nom}" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || item.id == null) return;
    try {
      await ref.read(patrimoineActionsProvider).delete(item.id!);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bien supprimé')));
      }
    } catch (e) {
      if (context.mounted) AppErrorMessage.showSnackBar(context, e);
    }
  }
}
