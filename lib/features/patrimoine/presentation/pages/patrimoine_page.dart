import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/patrimoine_item.dart';
import '../providers/patrimoine_providers.dart';
import '../widgets/patrimoine_form_sheet.dart';

class PatrimoinePage extends ConsumerWidget {
  const PatrimoinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(patrimoineListProvider);
    final totalAsync = ref.watch(patrimoineTotalValueProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('Patrimoine'),
        actions: [
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
        onPressed: () => _showItemForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau bien'),
      ),
      body: Column(
        children: [
          _TotalHeader(totalAsync: totalAsync),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _PatrimoineCard(item: items[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showItemForm(BuildContext context, {PatrimoineItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PatrimoineFormSheet(existing: existing),
    );
  }
}

class _TotalHeader extends StatelessWidget {
  final AsyncValue<double> totalAsync;

  const _TotalHeader({required this.totalAsync});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Valeur totale du patrimoine',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          totalAsync.when(
            loading: () => const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (err, _) => const Text('Erreur'),
            data: (total) => Text(
              fmt.format(total),
              style: amountTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
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
            const Text(
              'Aucun bien enregistré',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoute un bien immobilier, un véhicule ou tout autre élément de ton patrimoine',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatrimoineCard extends ConsumerWidget {
  final PatrimoineItem item;

  const _PatrimoineCard({required this.item});

  String _categoryLabel(PatrimoineCategory category) {
    switch (category) {
      case PatrimoineCategory.immobilier:
        return 'Immobilier';
      case PatrimoineCategory.vehicule:
        return 'Véhicule';
      case PatrimoineCategory.materiel:
        return 'Matériel';
      case PatrimoineCategory.autre:
        return 'Autre';
    }
  }

  IconData _categoryIcon(PatrimoineCategory category) {
    switch (category) {
      case PatrimoineCategory.immobilier:
        return Icons.home_outlined;
      case PatrimoineCategory.vehicule:
        return Icons.directions_car_outlined;
      case PatrimoineCategory.materiel:
        return Icons.devices_other_outlined;
      case PatrimoineCategory.autre:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: item.devise, decimalDigits: 0);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => PatrimoineFormSheet(existing: item),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                child: Icon(_categoryIcon(item.categorie)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nom,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _categoryLabel(item.categorie),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (item.localisation != null && item.localisation!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text(
                            item.localisation!,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(item.valeurEstimee),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () => _confirmDelete(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce bien ?'),
        content: Text('Voulez-vous vraiment supprimer "${item.nom}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && item.id != null) {
        try {
          await ref.read(patrimoineActionsProvider).delete(item.id!);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bien supprimé')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur lors de la suppression : $e')),
            );
          }
        }
      }
    });
  }
}
