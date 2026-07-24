import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/business_entity.dart';
import '../providers/entity_providers.dart';

/// Barre compacte affichant l'entité active, avec possibilité d'en
/// changer ou d'en créer une nouvelle (Personnel / Société A / Société
/// B...). À placer en haut des écrans dont les données doivent être
/// filtrées par entité.
class EntitySelectorBar extends ConsumerWidget {
  const EntitySelectorBar({super.key});

  Future<void> _createEntity(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    var type = BusinessEntityType.professionnel;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Nouvelle entité'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom (ex: Société A)'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<BusinessEntityType>(
                segments: const [
                  ButtonSegment(value: BusinessEntityType.personnel, label: Text('Personnel')),
                  ButtonSegment(value: BusinessEntityType.professionnel, label: Text('Professionnel')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (created == true && nameController.text.trim().isNotEmpty) {
      final newId = await ref.read(entityDaoProvider).insert(nameController.text.trim(), type);
      ref.invalidate(entitiesListProvider);
      await ref.read(currentEntityIdProvider.notifier).select(newId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitiesAsync = ref.watch(entitiesListProvider);
    final currentId = ref.watch(currentEntityIdProvider);

    return entitiesAsync.when(
      loading: () => const SizedBox(height: 40),
      error: (e, _) => const SizedBox.shrink(),
      data: (entities) {
        if (entities.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Icon(Icons.apartment_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: entities.length > 1
                    ? DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: currentId,
                          isExpanded: true,
                          items: entities
                              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                              .toList(),
                          onChanged: (id) {
                            if (id != null) ref.read(currentEntityIdProvider.notifier).select(id);
                          },
                        ),
                      )
                    : Text(entities.first.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              IconButton(
                icon: const Icon(Icons.add_business_outlined),
                tooltip: 'Nouvelle entité',
                onPressed: () => _createEntity(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }
}
