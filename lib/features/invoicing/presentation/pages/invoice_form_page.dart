import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_format.dart';
import '../../data/invoice_repository.dart';
import '../../domain/invoice.dart';

class _ItemRow {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController price;
  _ItemRow({String d = '', String q = '1', String p = ''})
      : description = TextEditingController(text: d),
        quantity = TextEditingController(text: q),
        price = TextEditingController(text: p);

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
  }
}

double _num(String s) => double.tryParse(s.trim().replaceAll(',', '.').replaceAll(' ', '')) ?? 0;

/// Création / modification d'une facture. Renvoie `true` si enregistrée.
class InvoiceFormPage extends ConsumerStatefulWidget {
  final Invoice? existing;
  const InvoiceFormPage({super.key, this.existing});

  @override
  ConsumerState<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends ConsumerState<InvoiceFormPage> {
  final _client = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _tax = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _currency = TextEditingController(text: 'XOF');
  final List<_ItemRow> _rows = [];
  late DateTime _issue;
  DateTime? _due;
  InvoiceTemplate _template = InvoiceTemplate.classique;
  String _number = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _issue = e?.issueDate ?? DateTime.now();
    if (e != null) {
      _client.text = e.clientName;
      _address.text = e.clientAddress ?? '';
      _phone.text = e.clientPhone ?? '';
      _email.text = e.clientEmail ?? '';
      _tax.text = e.taxRate.toString();
      _discount.text = e.discount.toString();
      _notes.text = e.notes ?? '';
      _currency.text = e.currency;
      _due = e.dueDate;
      _template = e.template;
      _number = e.number;
      for (final i in e.items) {
        _rows.add(_ItemRow(d: i.description, q: i.quantity.toString(), p: i.unitPrice.toString()));
      }
    } else {
      _due = DateTime.now().add(const Duration(days: 30));
      _rows.add(_ItemRow());
      ref.read(invoiceRepositoryProvider).nextNumber().then((n) {
        if (mounted) setState(() => _number = n);
      });
    }
    if (_rows.isEmpty) _rows.add(_ItemRow());
  }

  @override
  void dispose() {
    for (final c in [_client, _address, _phone, _email, _tax, _discount, _notes, _currency]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  List<InvoiceItem> _items() => [
        for (final r in _rows)
          if (r.description.text.trim().isNotEmpty)
            InvoiceItem(description: r.description.text.trim(), quantity: _num(r.quantity.text), unitPrice: _num(r.price.text)),
      ];

  Invoice _build() {
    final e = widget.existing;
    final now = DateTime.now();
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return Invoice(
      id: e?.id,
      number: _number,
      template: _template,
      status: e?.status ?? InvoiceStatus.brouillon,
      clientName: _client.text.trim(),
      clientAddress: opt(_address),
      clientPhone: opt(_phone),
      clientEmail: opt(_email),
      issueDate: _issue,
      dueDate: _due,
      currency: _currency.text.trim().isEmpty ? 'XOF' : _currency.text.trim().toUpperCase(),
      taxRate: _num(_tax.text),
      discount: _num(_discount.text),
      paidAmount: e?.paidAmount ?? 0,
      accountId: e?.accountId,
      notes: opt(_notes),
      items: _items(),
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    final inv = _build();
    if (inv.clientName.isEmpty) {
      _snack('Indique le nom du client.');
      return;
    }
    if (inv.items.isEmpty) {
      _snack('Ajoute au moins une ligne.');
      return;
    }
    if (_number.isEmpty) {
      _snack('Numéro en cours de calcul, réessaie.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(invoiceRepositoryProvider).save(inv);
      ref.invalidate(invoicesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Enregistrement impossible : $e');
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDate({required bool due}) async {
    final init = due ? (_due ?? _issue) : _issue;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => due ? _due = d : _issue = d);
  }

  @override
  Widget build(BuildContext context) {
    final inv = _build();
    final fmt = AppFormat.currency(symbol: inv.currency);
    final df = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nouvelle facture' : 'Modifier ${widget.existing!.number}'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('N° $_number', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: _client, decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse du client', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(due: false),
                icon: const Icon(Icons.event),
                label: Text('Émise : ${df.format(_issue)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(due: true),
                icon: const Icon(Icons.event_available),
                label: Text(_due == null ? 'Échéance' : 'Échéance : ${df.format(_due!)}'),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          const Text('Lignes', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++) _rowEditor(i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rows.add(_ItemRow())),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une ligne'),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _currency, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Devise', border: OutlineInputBorder()), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _tax, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'TVA %', border: OutlineInputBorder()), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Remise', border: OutlineInputBorder()), onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              _totalLine('Sous-total', fmt.format(inv.subtotal)),
              if (inv.discount > 0) _totalLine('Remise', '- ${fmt.format(inv.discount)}'),
              if (inv.taxRate > 0) _totalLine('TVA (${inv.taxRate.toString()} %)', fmt.format(inv.taxAmount)),
              const Divider(),
              _totalLine('TOTAL', fmt.format(inv.total), bold: true),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Modèle', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in InvoiceTemplate.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _template == t,
                avatarBoxConstraints: const BoxConstraints(maxWidth: 18, maxHeight: 18),
                avatar: CircleAvatar(backgroundColor: Color(t.accent)),
                onSelected: (_) => setState(() => _template = t),
              ),
          ]),
          const SizedBox(height: 4),
          Text(_template.hint, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes (facultatif)', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Enregistrer la facture')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _totalLine(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        ]),
      );

  Widget _rowEditor(int i) {
    final r = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: r.description,
              decoration: InputDecoration(labelText: 'Désignation ${i + 1}', border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer la ligne',
            icon: const Icon(Icons.delete_outline),
            onPressed: _rows.length <= 1
                ? null
                : () => setState(() {
                      _rows.removeAt(i).dispose();
                    }),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: r.quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: r.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prix unitaire', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      ]),
    );
  }
}
