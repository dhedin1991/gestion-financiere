import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../providers/audit_log_providers.dart';

class AuditLogPage extends ConsumerWidget {
  const AuditLogPage({super.key});

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      default:
        return Icons.history;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create':
        return 'Création';
      case 'update':
        return 'Modification';
      case 'delete':
        return 'Suppression';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(auditLogEntriesProvider);
    final dateFmt = DateFormat('dd/MM/yyyy à HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Journal des actions')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              message: 'Aucune action enregistrée pour le moment',
              subtitle: 'Les créations, modifications et suppressions de transactions apparaîtront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final e = entries[index];
              final action = e['action'] as String;
              final entityType = e['entity_type'] as String;
              final date = '${e['date']}T${e['time']}';
              DateTime? parsed;
              try {
                parsed = DateTime.parse(date);
              } catch (_) {}

              final detail = action == 'delete' ? e['old_value'] : e['new_value'];

              return ListTile(
                leading: Icon(_actionIcon(action)),
                title: Text('${_actionLabel(action)} — $entityType'),
                subtitle: Text(
                  [
                    if (detail != null) detail as String,
                    if (parsed != null) dateFmt.format(parsed),
                  ].join(' · '),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
