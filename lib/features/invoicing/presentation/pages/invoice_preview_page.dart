import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_format.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../data/invoice_pdf.dart';
import '../../data/invoice_repository.dart';
import '../../domain/invoice.dart';
import 'invoice_form_page.dart';

/// Aperçu fidèle d'une facture (4 modèles) + actions : partager en PDF,
/// marquer envoyée, encaisser sur un compte, modifier, supprimer.
class InvoicePreviewPage extends ConsumerStatefulWidget {
  final int invoiceId;
  const InvoicePreviewPage({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoicePreviewPage> createState() => _InvoicePreviewPageState();
}

class _InvoicePreviewPageState extends ConsumerState<InvoicePreviewPage> {
  Invoice? _invoice;
  InvoiceTemplate? _tplOverride;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final inv = await ref.read(invoiceRepositoryProvider).get(widget.invoiceId);
    if (!mounted) return;
    setState(() {
      _invoice = inv;
      _loading = false;
    });
    ref.invalidate(invoicesProvider);
    ref.invalidate(accountsListProvider);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (e) {
      if (mounted) _snack('Action impossible : $e');
    }
  }

  Future<void> _collect(Invoice inv) async {
    final accounts = await ref.read(accountsListProvider.future);
    final usable = accounts.where((a) => a.currency == inv.currency).toList();
    if (!mounted) return;
    if (usable.isEmpty) {
      _snack('Aucun compte en ${inv.currency} pour encaisser cette facture.');
      return;
    }
    final amountCtrl = TextEditingController(text: inv.remaining.round().toString());
    int? selected = inv.accountId != null && usable.any((a) => a.id == inv.accountId) ? inv.accountId : usable.first.id;
    final fmt = AppFormat.currency(symbol: inv.currency);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Encaisser la facture'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reste à payer : ${fmt.format(inv.remaining)}. Le montant encaissé est crédité sur le compte choisi et compté comme revenu.'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant encaissé (acompte possible)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: selected,
              decoration: const InputDecoration(labelText: 'Compte', border: OutlineInputBorder()),
              items: [for (final a in usable) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (v) => setS(() => selected = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encaisser')),
          ],
        ),
      ),
    );
    final typed = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.').replaceAll(' ', ''));
    amountCtrl.dispose();
    if (ok == true && selected != null) {
      if (typed == null || typed <= 0) {
        if (mounted) _snack('Montant invalide.');
        return;
      }
      await _run(() => ref.read(invoiceRepositoryProvider).collect(inv, selected!, amount: typed));
      if (mounted) _snack(typed >= inv.remaining ? 'Facture soldée.' : 'Acompte enregistré.');
    }
  }

  Future<void> _confirm(String title, String body, Future<void> Function() onYes, {bool pop = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;
    if (pop) {
      try {
        await onYes();
        ref.invalidate(invoicesProvider);
        ref.invalidate(accountsListProvider);
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) _snack('Action impossible : $e');
      }
    } else {
      await _run(onYes);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final inv = _invoice;
    if (inv == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Facture introuvable.')));
    }
    final co = ref.watch(companyProfileProvider);
    final shown = inv.copyWith(template: _tplOverride ?? inv.template);
    final repo = ref.read(invoiceRepositoryProvider);
    final paid = inv.status == InvoiceStatus.payee;

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.number),
        actions: [
          IconButton(
            tooltip: 'Partager en PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              try {
                await shareInvoicePdf(shown, co);
              } catch (e) {
                if (mounted) _snack('PDF impossible : $e');
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => InvoiceFormPage(existing: inv)),
                  );
                  if (saved == true) await _reload();
                case 'dup':
                  final repo2 = ref.read(invoiceRepositoryProvider);
                  final newNumber = await repo2.nextNumber();
                  final now = DateTime.now();
                  await repo2.save(Invoice(
                    number: newNumber,
                    template: inv.template,
                    clientName: inv.clientName,
                    clientAddress: inv.clientAddress,
                    clientPhone: inv.clientPhone,
                    clientEmail: inv.clientEmail,
                    issueDate: now,
                    dueDate: now.add(const Duration(days: 30)),
                    currency: inv.currency,
                    taxRate: inv.taxRate,
                    discount: inv.discount,
                    notes: inv.notes,
                    items: inv.items,
                    createdAt: now,
                    updatedAt: now,
                  ));
                  ref.invalidate(invoicesProvider);
                  if (mounted) {
                    _snack('Facture $newNumber créée en brouillon.');
                    Navigator.of(context).pop(true);
                  }
                case 'sent':
                  await _run(() => repo.setStatus(inv.id!, InvoiceStatus.envoyee));
                case 'cancel':
                  await _confirm('Annuler la facture ?', 'Elle ne sera plus comptée comme à encaisser.',
                      () => repo.setStatus(inv.id!, InvoiceStatus.annulee));
                case 'uncollect':
                  await _confirm('Annuler l’encaissement ?', 'Le montant sera retiré du compte et la facture rouverte.',
                      () => repo.uncollect(inv.id!));
                case 'delete':
                  await _confirm('Supprimer la facture ?', 'Définitif. Un éventuel encaissement est aussi annulé sur le compte.',
                      () => repo.delete(inv.id!), pop: true);
              }
            },
            itemBuilder: (_) => [
              if (!paid) const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              if (inv.status == InvoiceStatus.brouillon) const PopupMenuItem(value: 'sent', child: Text('Marquer comme envoyée')),
              if (!paid && inv.status != InvoiceStatus.annulee) const PopupMenuItem(value: 'cancel', child: Text('Annuler la facture')),
              if (paid) const PopupMenuItem(value: 'uncollect', child: Text('Annuler l’encaissement')),
              const PopupMenuItem(value: 'dup', child: Text('Dupliquer')),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: (!paid && inv.status != InvoiceStatus.annulee)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => _collect(inv),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Encaisser sur un compte'),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final t in InvoiceTemplate.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.label),
                    selected: shown.template == t,
                    onSelected: (_) => setState(() => _tplOverride = t),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          InvoicePaper(invoice: shown, company: co),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Rendu écran de la facture, reprenant les couleurs et la structure de chaque
/// modèle PDF (le PDF reste la référence pour l'impression).
class InvoicePaper extends StatelessWidget {
  final Invoice invoice;
  final CompanyProfile company;
  const InvoicePaper({super.key, required this.invoice, required this.company});

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final tpl = inv.template;
    final plain = tpl == InvoiceTemplate.minimal;
    final accent = Color(tpl.accent);
    final headerBg = Color(tpl.header);
    final onHeader = plain ? Colors.black : Colors.white;
    final gold = tpl == InvoiceTemplate.institutionnel;
    final fmt = AppFormat.currency(symbol: inv.currency, decimalDigits: 0);
    final df = DateFormat('dd/MM/yyyy');
    final name = company.name.trim().isEmpty ? 'Mon entreprise' : company.name.trim();
    const ink = Color(0xFF1A1A1A);

    TextStyle s(double size, {bool bold = false, Color color = ink}) =>
        TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.normal, color: color);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: plain ? null : headerBg,
            border: plain ? const Border(bottom: BorderSide(color: Colors.black, width: 1.2)) : null,
            borderRadius: tpl == InvoiceTemplate.moderne ? BorderRadius.circular(8) : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: s(16, bold: true, color: onHeader)),
                if (company.address.isNotEmpty) Text(company.address, style: s(10, color: onHeader)),
                if (company.phone.isNotEmpty) Text('Tél : ${company.phone}', style: s(10, color: onHeader)),
                if (company.email.isNotEmpty) Text(company.email, style: s(10, color: onHeader)),
                if (company.taxId.isNotEmpty) Text('IFU / NIF : ${company.taxId}', style: s(10, color: onHeader)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('FACTURE', style: s(18, bold: true, color: gold ? const Color(0xFFD9B54A) : onHeader)),
              Text('N° ${inv.number}', style: s(11, bold: true, color: onHeader)),
              Text('Émise le ${df.format(inv.issueDate)}', style: s(10, color: onHeader)),
              if (inv.dueDate != null) Text('Échéance : ${df.format(inv.dueDate!)}', style: s(10, color: onHeader)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: accent.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FACTURÉ À', style: s(9, bold: true, color: accent)),
            Text(inv.clientName, style: s(13, bold: true)),
            if ((inv.clientAddress ?? '').isNotEmpty) Text(inv.clientAddress!, style: s(10)),
            if ((inv.clientPhone ?? '').isNotEmpty) Text('Tél : ${inv.clientPhone}', style: s(10)),
            if ((inv.clientEmail ?? '').isNotEmpty) Text(inv.clientEmail!, style: s(10)),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          color: plain ? const Color(0xFFEEEEEE) : accent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Expanded(flex: 5, child: Text('Désignation', style: s(10, bold: true, color: plain ? ink : Colors.white))),
            Expanded(flex: 2, child: Text('Qté', textAlign: TextAlign.right, style: s(10, bold: true, color: plain ? ink : Colors.white))),
            Expanded(flex: 3, child: Text('P.U.', textAlign: TextAlign.right, style: s(10, bold: true, color: plain ? ink : Colors.white))),
            Expanded(flex: 3, child: Text('Total', textAlign: TextAlign.right, style: s(10, bold: true, color: plain ? ink : Colors.white))),
          ]),
        ),
        for (final it in inv.items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD)))),
            child: Row(children: [
              Expanded(flex: 5, child: Text(it.description, style: s(11))),
              Expanded(flex: 2, child: Text(NumberFormat('#,##0.##', 'fr_FR').format(it.quantity), textAlign: TextAlign.right, style: s(11))),
              Expanded(flex: 3, child: Text(fmt.format(it.unitPrice), textAlign: TextAlign.right, style: s(11))),
              Expanded(flex: 3, child: Text(fmt.format(it.total), textAlign: TextAlign.right, style: s(11, bold: true))),
            ]),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 230,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tpl == InvoiceTemplate.moderne ? accent.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(children: [
              _line('Sous-total', fmt.format(inv.subtotal), s(11)),
              if (inv.discount > 0) _line('Remise', '- ${fmt.format(inv.discount)}', s(11)),
              if (inv.taxRate > 0) _line('TVA (${inv.taxRate} %)', fmt.format(inv.taxAmount), s(11)),
              const Divider(height: 10),
              _line('TOTAL', fmt.format(inv.total), s(14, bold: true, color: accent)),
              if (inv.paidAmount > 0) _line('Déjà réglé', fmt.format(inv.paidAmount), s(11)),
              if (inv.paidAmount > 0) _line('Reste à payer', fmt.format(inv.remaining), s(11, bold: true)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if ((inv.notes ?? '').isNotEmpty) ...[
          Text('NOTES', style: s(9, bold: true, color: accent)),
          Text(inv.notes!, style: s(10)),
          const SizedBox(height: 8),
        ],
        if (company.bank.isNotEmpty) ...[
          Text('MODALITÉS DE RÈGLEMENT', style: s(9, bold: true, color: accent)),
          Text(company.bank, style: s(10)),
          const SizedBox(height: 8),
        ],
        if (gold)
          Text('Toute somme non réglée à l’échéance pourra donner lieu à des pénalités de retard.',
              style: s(9, color: const Color(0xFF666666))),
        const SizedBox(height: 6),
        Center(child: Text(company.footer, style: s(10, bold: true, color: accent))),
        const SizedBox(height: 4),
        Center(child: Text('Statut : ${inv.status.label}', style: s(9, color: const Color(0xFF888888)))),
      ]),
    );
  }

  Widget _line(String l, String v, TextStyle st) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: st), Text(v, style: st)]),
      );
}
