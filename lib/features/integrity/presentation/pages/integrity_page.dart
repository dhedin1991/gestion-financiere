import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/ledger/ledger.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../accounts/presentation/providers/account_providers.dart';

class _Gap {
  final int id;
  final String name;
  final String currency;
  final int balanceCents;
  final int expectedCents;
  const _Gap(this.id, this.name, this.currency, this.balanceCents, this.expectedCents);
  int get diffCents => balanceCents - expectedCents;
}

/// Compare, pour chaque compte, le solde affiché à « solde initial + écritures ».
/// Un écart vient en général de données antérieures au grand livre (v18).
final _gapsProvider = FutureProvider.autoDispose<List<_Gap>>((ref) async {
  final db = await ref.watch(appDatabaseProvider).database;
  final rows = await db.rawQuery('''
    SELECT a.id, a.name, a.currency, a.current_balance, a.initial_balance,
      COALESCE((SELECT SUM(CASE WHEN t.type = 'revenu' THEN t.amount ELSE -t.amount END)
                FROM transactions t WHERE t.account_id = a.id), 0) AS ledger
    FROM accounts a ORDER BY a.name
  ''');
  return [
    for (final r in rows)
      _Gap(
        r['id'] as int,
        r['name'] as String,
        (r['currency'] as String?) ?? 'XOF',
        (r['current_balance'] as num).round(),
        (r['initial_balance'] as num).round() + (r['ledger'] as num).round(),
      ),
  ];
});

class IntegrityPage extends ConsumerWidget {
  const IntegrityPage({super.key});

  /// Ajoute une écriture « Correction d'historique » égale à l'écart, SANS toucher
  /// au solde affiché : le grand livre redevient cohérent, les statistiques ne
  /// bougent pas (écriture neutre).
  Future<void> _fix(BuildContext context, WidgetRef ref, _Gap g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Corriger ${g.name} ?'),
        content: const Text('Le solde affiché ne change pas. Une écriture neutre « Correction d’historique » est ajoutée pour que le grand livre corresponde au solde.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Corriger')),
        ],
      ),
    );
    if (ok != true) return;
    final db = await ref.read(appDatabaseProvider).database;
    final diff = g.diffCents;
    if (diff == 0) return;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final id = await txn.insert('transactions', {
        'account_id': g.id,
        'type': diff > 0 ? 'revenu' : 'depense',
        'amount': diff.abs(),
        'currency': g.currency,
        'description': 'Correction d’historique',
        'transaction_date': now,
        'kind': LedgerKind.correction,
        'created_at': now,
        'updated_at': now,
      });
      await txn.update('transactions', {'transfer_group': id}, where: 'id = ?', whereArgs: [id]);
    });
    ref.invalidate(_gapsProvider);
    ref.invalidate(accountsListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_gapsProvider);
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Contrôle d’intégrité'),
        actions: [
          const AppMenuButton(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(_gapsProvider)),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (gaps) {
          final bad = gaps.where((g) => g.diffCents != 0).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: ListTile(
                leading: Icon(bad.isEmpty ? Icons.verified_outlined : Icons.warning_amber_rounded, color: bad.isEmpty ? c.positive : c.warning),
                title: Text(bad.isEmpty ? 'Tous les soldes sont cohérents' : '${bad.length} compte${bad.length > 1 ? 's' : ''} avec un écart'),
                subtitle: const Text('Solde affiché comparé à : solde initial + toutes les écritures.'),
              ),
            ),
            const SizedBox(height: 8),
            for (final g in bad)
              Card(
                child: ListTile(
                  title: Text(g.name),
                  subtitle: Text(
                    'Affiché : ${AppFormat.currency(symbol: g.currency).format(g.balanceCents / 100)}\n'
                    'Attendu : ${AppFormat.currency(symbol: g.currency).format(g.expectedCents / 100)}\n'
                    'Écart : ${AppFormat.currency(symbol: g.currency).format(g.diffCents / 100)}',
                  ),
                  isThreeLine: true,
                  trailing: FilledButton(onPressed: () => _fix(context, ref, g), child: const Text('Corriger')),
                ),
              ),
            if (bad.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Les écarts viennent le plus souvent de données saisies avant la mise à jour v18 (sans écriture au grand livre).', style: TextStyle(fontSize: 12)),
              ),
          ]);
        },
      ),
    );
  }
}
