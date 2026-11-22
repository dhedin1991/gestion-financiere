import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/external_activity_guard.dart';
import '../domain/invoice.dart';

String _money(double v, String currency) {
  final n = NumberFormat('#,##0.##', 'fr_FR').format(v).replaceAll(' ', ' ').replaceAll(' ', ' ');
  return '$n $currency';
}

String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// Génère le PDF d'une facture selon son modèle (4 présentations).
Future<Uint8List> buildInvoicePdf(Invoice inv, CompanyProfile co) async {
  pw.ThemeData? theme;
  try {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSans_400Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSans_700Bold.ttf'));
    theme = pw.ThemeData.withFont(base: regular, bold: bold);
  } catch (_) {
    theme = null; // repli sur la police standard du PDF
  }
  final doc = theme == null ? pw.Document() : pw.Document(theme: theme);
  final tpl = inv.template;
  final accent = PdfColor.fromInt(tpl.accent);
  final headerBg = PdfColor.fromInt(tpl.header);
  final plain = tpl == InvoiceTemplate.minimal;
  final onHeader = plain ? PdfColors.black : PdfColors.white;
  final gold = tpl == InvoiceTemplate.institutionnel;

  pw.TextStyle ts(double size, {bool bold = false, PdfColor? color}) =>
      pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color);

  final companyName = co.name.trim().isEmpty ? 'Mon entreprise' : co.name.trim();

  pw.Widget header() => pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: plain ? null : headerBg,
          border: plain ? pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.2)) : null,
          borderRadius: tpl == InvoiceTemplate.moderne ? pw.BorderRadius.circular(8) : null,
        ),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(companyName, style: ts(18, bold: true, color: onHeader)),
            if (co.address.isNotEmpty) pw.Text(co.address, style: ts(9, color: onHeader)),
            if (co.phone.isNotEmpty) pw.Text('Tél : ${co.phone}', style: ts(9, color: onHeader)),
            if (co.email.isNotEmpty) pw.Text(co.email, style: ts(9, color: onHeader)),
            if (co.taxId.isNotEmpty) pw.Text('IFU / NIF : ${co.taxId}', style: ts(9, color: onHeader)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('FACTURE', style: ts(22, bold: true, color: gold ? PdfColor.fromInt(0xFFD9B54A) : onHeader)),
            pw.Text('N° ${inv.number}', style: ts(11, bold: true, color: onHeader)),
            pw.Text('Émise le ${_date(inv.issueDate)}', style: ts(9, color: onHeader)),
            if (inv.dueDate != null) pw.Text('Échéance : ${_date(inv.dueDate!)}', style: ts(9, color: onHeader)),
          ]),
        ]),
      );

  pw.Widget client() => pw.Container(
        margin: const pw.EdgeInsets.only(top: 18, bottom: 14),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FACTURÉ À', style: ts(8, bold: true, color: accent)),
            pw.SizedBox(height: 3),
            pw.Text(inv.clientName, style: ts(12, bold: true)),
            if ((inv.clientAddress ?? '').isNotEmpty) pw.Text(inv.clientAddress!, style: ts(9)),
            if ((inv.clientPhone ?? '').isNotEmpty) pw.Text('Tél : ${inv.clientPhone}', style: ts(9)),
            if ((inv.clientEmail ?? '').isNotEmpty) pw.Text(inv.clientEmail!, style: ts(9)),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: accent), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(inv.status.label.toUpperCase(), style: ts(10, bold: true, color: accent)),
          ),
        ]),
      );

  pw.Widget cell(String text, {bool bold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(text, textAlign: align, style: ts(9.5, bold: bold, color: color)),
      );

  pw.Widget itemsTable() {
    final headStyleColor = plain ? PdfColors.black : PdfColors.white;
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(2.2),
        3: const pw.FlexColumnWidth(2.4),
      },
      border: plain
          ? pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.5))
          : pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: plain ? null : accent, border: plain ? pw.Border(bottom: pw.BorderSide(width: 1.2)) : null),
          children: [
            cell('Description', bold: true, color: headStyleColor),
            cell('Qté', bold: true, color: headStyleColor, align: pw.TextAlign.right),
            cell('Prix unitaire', bold: true, color: headStyleColor, align: pw.TextAlign.right),
            cell('Montant', bold: true, color: headStyleColor, align: pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < inv.items.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: (!plain && i.isOdd) ? PdfColors.grey100 : null),
            children: [
              cell(inv.items[i].description),
              cell(NumberFormat('#,##0.##', 'fr_FR').format(inv.items[i].quantity), align: pw.TextAlign.right),
              cell(_money(inv.items[i].unitPrice, inv.currency), align: pw.TextAlign.right),
              cell(_money(inv.items[i].total, inv.currency), align: pw.TextAlign.right, bold: true),
            ],
          ),
      ],
    );
  }

  pw.Widget totals() {
    pw.Widget line(String l, String v, {bool strong = false, PdfColor? color}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(l, style: ts(strong ? 11 : 9.5, bold: strong, color: color)),
            pw.Text(v, style: ts(strong ? 11 : 9.5, bold: strong, color: color)),
          ]),
        );
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        margin: const pw.EdgeInsets.only(top: 14),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: tpl == InvoiceTemplate.moderne ? PdfColors.grey100 : null,
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(children: [
          line('Sous-total', _money(inv.subtotal, inv.currency)),
          if (inv.discount > 0) line('Remise', '- ${_money(inv.discount, inv.currency)}'),
          if (inv.taxRate > 0) line('TVA (${inv.taxRate.toStringAsFixed(inv.taxRate % 1 == 0 ? 0 : 1)} %)', _money(inv.taxAmount, inv.currency)),
          pw.Divider(color: accent, thickness: 1),
          line('TOTAL', _money(inv.total, inv.currency), strong: true, color: accent),
          if (inv.paidAmount > 0) line('Déjà réglé', _money(inv.paidAmount, inv.currency)),
          if (inv.paidAmount > 0) line('Reste à payer', _money(inv.remaining, inv.currency), strong: true),
        ]),
      ),
    );
  }

  pw.Widget footer() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(height: 16),
        if ((inv.notes ?? '').isNotEmpty) ...[
          pw.Text('NOTES', style: ts(8, bold: true, color: accent)),
          pw.Text(inv.notes!, style: ts(9)),
          pw.SizedBox(height: 8),
        ],
        if (co.bank.isNotEmpty) ...[
          pw.Text('MODALITÉS DE RÈGLEMENT', style: ts(8, bold: true, color: accent)),
          pw.Text(co.bank, style: ts(9)),
          pw.SizedBox(height: 8),
        ],
        if (gold)
          pw.Text(
            'Toute somme non réglée à l\'échéance pourra donner lieu à des pénalités de retard.',
            style: ts(8, color: PdfColors.grey700),
          ),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text(co.footer, style: ts(9, bold: true, color: accent))),
      ]);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => [header(), client(), itemsTable(), totals(), footer()],
  ));
  return doc.save();
}

/// Génère le PDF dans un fichier temporaire puis ouvre la feuille de
/// partage (enregistrer, imprimer, envoyer par WhatsApp / e-mail...).
Future<void> shareInvoicePdf(Invoice inv, CompanyProfile co) async {
  final bytes = await buildInvoicePdf(inv, co);
  final dir = await getTemporaryDirectory();
  final safe = inv.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final file = File('${dir.path}/Facture_$safe.pdf');
  await file.writeAsBytes(bytes);
  await ExternalActivityGuard.run(() => Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Facture ${inv.number}',
        text: 'Facture ${inv.number} — ${inv.clientName}',
      ));
}
