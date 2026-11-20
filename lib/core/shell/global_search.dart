import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/providers/account_providers.dart';
import '../../features/budgets/presentation/providers/budget_providers.dart';
import '../../features/credits/presentation/providers/credit_providers.dart';
import '../../features/debts/presentation/providers/debt_providers.dart';
import '../../features/savings/presentation/providers/savings_providers.dart';
import '../../features/transactions/presentation/providers/transaction_providers.dart';
import '../display/display_prefs.dart';
import '../navigation/modules.dart';
import '../theme/app_theme.dart';
import '../utils/app_format.dart';

class _Hit {
  final IconData icon;
  final String title;
  final String subtitle;
  final String kind;
  final VoidCallback onTap;
  const _Hit(this.icon, this.title, this.subtitle, this.kind, this.onTap);
}

/// Ouvre la recherche globale (palette de commandes, Ctrl + K).
Future<void> showGlobalSearch(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _SearchDialog(),
  );
}

class _SearchDialog extends ConsumerStatefulWidget {
  const _SearchDialog();

  @override
  ConsumerState<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<_SearchDialog> {
  final _controller = TextEditingController();
  List<_Hit> _hits = const [];
  int _token = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(String route, {String? transactionSearch}) {
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).pop();
    router.go(route);
    if (transactionSearch != null) {
      Future.delayed(const Duration(milliseconds: 350), () {
        container.read(transactionFiltersProvider.notifier).update((f) => TransactionFilters(search: transactionSearch));
      });
    }
  }

  Future<void> _run(String raw) async {
    final q = raw.trim().toLowerCase();
    final token = ++_token;
    setState(() => _busy = q.isNotEmpty);
    final hits = <_Hit>[];

    for (final m in kModules) {
      if (q.isEmpty ? m.inNav && ['Général', 'Comptabilité'].contains(m.section) : m.label.toLowerCase().contains(q)) {
        hits.add(_Hit(m.icon, m.label, m.section, 'Écran', () => _go(m.route)));
      }
    }
    if (q.isNotEmpty) {
      try {
        final prefs = DisplayPrefs.current;
        final accounts = prefs.searchArchived
            ? await ref.read(allAccountsIncludingArchivedProvider.future)
            : await ref.read(accountsListProvider.future);
        for (final a in accounts.where((a) => a.name.toLowerCase().contains(q) || (a.bankName ?? '').toLowerCase().contains(q))) {
          hits.add(_Hit(Icons.account_balance_wallet_outlined, a.name,
              AppFormat.currency(symbol: a.currency).format(a.currentBalance), 'Compte', () => _go('/accounts')));
        }
        final budgets = await ref.read(budgetsListProvider.future);
        for (final b in budgets.where((b) => (b.name ?? '').toLowerCase().contains(q))) {
          hits.add(_Hit(Icons.pie_chart_outline, b.name ?? 'Budget', AppFormat.currency(symbol: b.currency).format(b.amount), 'Budget', () => _go('/budgets')));
        }
        final savings = await ref.read(savingsListProvider.future);
        for (final s in savings.where((s) => s.name.toLowerCase().contains(q))) {
          hits.add(_Hit(Icons.savings_outlined, s.name, AppFormat.currency(symbol: s.currency).format(s.currentBalance), 'Épargne', () => _go('/savings')));
        }
        final credits = await ref.read(creditsListProvider.future);
        for (final c in credits.where((c) => c.name.toLowerCase().contains(q))) {
          hits.add(_Hit(Icons.request_quote_outlined, c.name, AppFormat.currency(symbol: c.currency).format(c.principalAmount), 'Crédit', () => _go('/credits')));
        }
        final debts = await ref.read(debtsListProvider.future);
        for (final d in debts.where((d) => d.personName.toLowerCase().contains(q) || (d.description ?? '').toLowerCase().contains(q))) {
          hits.add(_Hit(Icons.handshake_outlined, d.personName, AppFormat.currency(symbol: d.currency).format(d.totalAmount), 'Dette / créance', () => _go('/debts')));
        }
        final txs = await ref.read(transactionRepositoryProvider).getTransactions(searchText: raw.trim(), limit: 8);
        for (final t in txs) {
          final sign = t.signedAmount >= 0 ? '+' : '−';
          hits.add(_Hit(Icons.swap_vert, t.description ?? '(sans libellé)',
              '${t.transactionDate.day.toString().padLeft(2, '0')}/${t.transactionDate.month.toString().padLeft(2, '0')}/${t.transactionDate.year} · $sign ${AppFormat.currency(symbol: t.currency).format(t.amount)}',
              'Écriture', () => _go('/transactions', transactionSearch: raw.trim())));
        }
      } catch (_) {
        // Une source illisible ne doit jamais bloquer la recherche.
      }
    }
    if (!mounted || token != _token) return;
    setState(() {
      _hits = hits;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _run,
                decoration: InputDecoration(
                  hintText: 'Rechercher un compte, une écriture, un budget, un écran…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _hits.isEmpty
                  ? Padding(padding: const EdgeInsets.all(24), child: Text('Aucun résultat', style: TextStyle(color: colors.muted)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _hits.length,
                      itemBuilder: (context, i) {
                        final h = _hits[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(h.icon),
                          title: Text(h.title, overflow: TextOverflow.ellipsis),
                          subtitle: Text(h.subtitle, overflow: TextOverflow.ellipsis),
                          trailing: Text(h.kind, style: TextStyle(fontSize: 11, color: colors.muted)),
                          onTap: h.onTap,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
