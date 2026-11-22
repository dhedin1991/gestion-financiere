import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_message.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/panel.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../data/invoice_repository.dart';
import '../../domain/invoice.dart';
import 'company_profile_page.dart';
import 'invoice_form_page.dart';
import 'invoice_preview_page.dart';

class InvoicingPage extends ConsumerStatefulWidget {
  const InvoicingPage({super.key});

  @override
  ConsumerState<InvoicingPage> createState() => _InvoicingPageState();
}

class _InvoicingPageState extends ConsumerState<InvoicingPage> {
  InvoiceStatus? _filter;

  Future<void> _newInvoice() async {
    final profile = ref.read(companyProfileProvider);
    if (profile.name.trim().isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Profil de l’entreprise'),
          content: const Text('Renseigne d’abord le nom et les coordonnées de ton entreprise : ils seront imprimés sur chaque facture.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Renseigner')),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompanyProfilePage()));
      }
      if (!mounted) return;
    }
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const InvoiceFormPage()));
    ref.invalidate(invoicesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoicesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Facturation'),
        actions: [
          const AppMenuButton(),
          IconButton(
            tooltip: 'Profil de l’entreprise',
            icon: const Icon(Icons.business_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompanyProfilePage())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newInvoice,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle facture'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppErrorMessage.friendly(e))),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Aucune facture',
              subtitle: 'Crée ta première facture avec le bouton ci-dessous.',
            );
          }
          final shown = _filter == null ? all : all.where((i) => i.status == _filter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              _Indicators(invoices: all),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: const Text('Toutes'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                  ),
                  for (final s in InvoiceStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(s.label), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune facture dans ce statut.')))
              else
                for (final inv in shown) _InvoiceTile(invoice: inv),
            ],
          );
        },
      ),
    );
  }
}

class _Indicators extends ConsumerWidget {
  final List<Invoice> invoices;
  const _Indicators({required this.invoices});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final main = ref.watch(mainCurrencyProvider).valueOrNull ?? 'XOF';
    final live = invoices.where((i) => i.currency == main && i.status != InvoiceStatus.annulee && i.status != InvoiceStatus.brouillon);
    final billed = live.fold<double>(0, (s, i) => s + i.total);
    final collected = live.fold<double>(0, (s, i) => s + i.paidAmount);
    final pending = live.where((i) => i.status == InvoiceStatus.envoyee).fold<double>(0, (s, i) => s + i.remaining);
    final late = invoices.where((i) => i.currency == main && i.isOverdue);
    final lateSum = late.fold<double>(0, (s, i) => s + i.remaining);
    final fmt = AppFormat.currency(symbol: main);
    final c = context.appColors;

    Widget kpi(String label, String value, Color color) => Expanded(
          child: Panel(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ),
        );

    return Column(children: [
      Row(children: [
        kpi('Facturé', fmt.format(billed), Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 8),
        kpi('Encaissé', fmt.format(collected), c.positive),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        kpi('À encaisser', fmt.format(pending), c.warning),
        const SizedBox(width: 8),
        kpi('En retard (${late.length})', fmt.format(lateSum), lateSum > 0 ? c.negative : c.muted),
      ]),
    ]);
  }
}

class _InvoiceTile extends ConsumerWidget {
  final Invoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final inv = invoice;
    final fmt = AppFormat.currency(symbol: inv.currency);
    final Color color;
    final String label;
    if (inv.isOverdue) {
      color = c.negative;
      label = 'En retard';
    } else {
      label = inv.status.label;
      color = switch (inv.status) {
        InvoiceStatus.payee => c.positive,
        InvoiceStatus.envoyee => c.warning,
        InvoiceStatus.annulee => c.muted,
        InvoiceStatus.brouillon => c.info,
      };
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => InvoicePreviewPage(invoiceId: inv.id!)));
          ref.invalidate(invoicesProvider);
        },
        leading: CircleAvatar(backgroundColor: Color(inv.template.accent), child: const Icon(Icons.receipt_long, color: Colors.white, size: 20)),
        title: Text('${inv.number} — ${inv.clientName}', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Émise le ${DateFormat('dd/MM/yyyy').format(inv.issueDate)}'
          '${inv.dueDate != null ? ' · échéance ${DateFormat('dd/MM/yyyy').format(inv.dueDate!)}' : ''}',
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(inv.total), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
