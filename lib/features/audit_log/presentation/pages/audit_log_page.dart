import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/summary_header.dart';
import '../providers/audit_log_providers.dart';

/// Historique des mouvements : toutes les créations, modifications et
/// suppressions, regroupées par jour, avec filtre par nature d'action.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  String? _filter; // create | update | delete

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

  Color _actionColor(BuildContext context, String action) {
    final c = context.appColors;
    switch (action) {
      case 'create':
        return c.positive;
      case 'delete':
        return c.negative;
      default:
        return c.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(auditLogEntriesProvider);
    final colors = context.appColors;
    final timeFmt = DateFormat('HH:mm');
    final dayFmt = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Historique des mouvements'),
        actions: [
          const AppMenuButton(),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: () => ref.invalidate(auditLogEntriesProvider)),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppErrorMessage.friendly(e))),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              message: 'Aucune action enregistrée pour le moment',
              subtitle: 'Chaque opération (saisie, transfert, remboursement, suppression…) apparaîtra ici.',
            );
          }
          int count(String a) => entries.where((e) => e['action'] == a).length;
          final shown = _filter == null ? entries : entries.where((e) => e['action'] == _filter).toList();

          final items = <Object>['summary', 'filters'];
          String? lastDay;
          for (final e in shown) {
            final d = '${e['date']}';
            if (d != lastDay) {
              items.add(d);
              lastDay = d;
            }
            items.add(e);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              if (it == 'summary') {
                final total = entries.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SummaryHeader(
                    title: 'Activité',
                    ratio: total == 0 ? 0 : count('create') / total,
                    ringColor: colors.positive,
                    ringText: '$total',
                    stats: [
                      SummaryStat('Créations', '${count('create')}', color: colors.positive),
                      SummaryStat('Modifications', '${count('update')}', color: colors.info),
                      SummaryStat('Suppressions', '${count('delete')}', color: colors.negative),
                    ],
                  ),
                );
              }
              if (it == 'filters') {
                return SizedBox(
                  height: 44,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final f in const [null, 'create', 'update', 'delete'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f == null ? 'Tout' : _actionLabel(f)),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ]),
                );
              }
              if (it is String) {
                String label = it;
                try {
                  label = dayFmt.format(DateTime.parse(it));
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                  child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.muted)),
                );
              }
              final e = it as Map<String, Object?>;
              final action = e['action'] as String;
              final entityType = e['entity_type'] as String;
              DateTime? parsed;
              try {
                parsed = DateTime.parse('${e['date']}T${e['time']}');
              } catch (_) {}
              final detail = action == 'delete' ? e['old_value'] : e['new_value'];
              final col = _actionColor(context, action);
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: col.withValues(alpha: 0.15),
                    child: Icon(_actionIcon(action), color: col, size: 20),
                  ),
                  title: Text('${_actionLabel(action)} — $entityType'),
                  subtitle: detail == null ? null : Text('$detail'),
                  trailing: parsed == null ? null : Text(timeFmt.format(parsed), style: TextStyle(color: colors.muted, fontSize: 12)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
