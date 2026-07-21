import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../accounts/domain/entities/account.dart';
import '../../categories/domain/entities/category.dart';
import '../../transactions/domain/entities/transaction.dart';

/// Génère et partage un relevé des transactions, au format CSV (pour
/// tableur / comptable) ou PDF (pour impression / archive).
///
/// Les noms de compte et de catégorie sont résolus à partir des listes
/// passées en paramètre plutôt que d'aller les rechercher un par un en
/// base — l'appelant les a déjà (ce sont de petites listes, chargées une
/// fois pour tout l'écran).
class StatementExportService {
  String _accountName(List<Account> accounts, int id) {
    final match = accounts.where((a) => a.id == id);
    return match.isEmpty ? 'Compte supprimé' : match.first.name;
  }

  String _categoryName(List<AppCategory> categories, int? id) {
    if (id == null) return '—';
    final match = categories.where((c) => c.id == id);
    return match.isEmpty ? '—' : match.first.name;
  }

  Future<void> exportCsv({
    required List<FinancialTransaction> transactions,
    required List<Account> accounts,
    required List<AppCategory> categories,
  }) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final rows = <List<String>>[
      ['Date', 'Compte', 'Type', 'Catégorie', 'Description', 'Montant', 'Devise'],
      ...transactions.map((t) => [
            dateFmt.format(t.transactionDate),
            _accountName(accounts, t.accountId),
            t.type == TransactionType.revenu ? 'Revenu' : 'Dépense',
            _categoryName(categories, t.categoryId),
            t.description ?? '',
            t.amount.toStringAsFixed(0),
            t.currency,
          ]),
    ];

    final csvContent = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final file = await _writeToTempFile(
      'transactions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      csvContent,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Export transactions',
    );
  }

  Future<void> exportPdf({
    required List<FinancialTransaction> transactions,
    required List<Account> accounts,
    required List<AppCategory> categories,
    DateTime? periodFrom,
    DateTime? periodTo,
  }) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final currency = transactions.isNotEmpty ? transactions.first.currency : 'XOF';
    final amountFmt = NumberFormat.currency(locale: 'fr_FR', symbol: currency, decimalDigits: 0);

    final totalRevenus = transactions
        .where((t) => t.type == TransactionType.revenu)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalDepenses = transactions
        .where((t) => t.type == TransactionType.depense)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Relevé de transactions',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            if (periodFrom != null && periodTo != null)
              pw.Text(
                'Période du ${dateFmt.format(periodFrom)} au ${dateFmt.format(periodTo)}',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),
            pw.Text(
              'Généré le ${dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox('Revenus', amountFmt.format(totalRevenus), PdfColors.green700),
              pw.SizedBox(width: 12),
              _summaryBox('Dépenses', amountFmt.format(totalDepenses), PdfColors.red700),
              pw.SizedBox(width: 12),
              _summaryBox(
                'Solde',
                amountFmt.format(totalRevenus - totalDepenses),
                PdfColors.blueGrey800,
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(2.5),
              4: pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _headerCell('Date'),
                  _headerCell('Compte'),
                  _headerCell('Catégorie'),
                  _headerCell('Description'),
                  _headerCell('Montant', align: pw.TextAlign.right),
                ],
              ),
              ...transactions.map((t) {
                final isIncome = t.type == TransactionType.revenu;
                return pw.TableRow(
                  children: [
                    _cell(dateFmt.format(t.transactionDate)),
                    _cell(_accountName(accounts, t.accountId)),
                    _cell(_categoryName(categories, t.categoryId)),
                    _cell(t.description ?? ''),
                    _cell(
                      '${isIncome ? '+' : '-'}${amountFmt.format(t.amount)}',
                      align: pw.TextAlign.right,
                      color: isIncome ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final file = await _writeBytesToTempFile(
      'releve_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      await doc.save(),
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Relevé de transactions',
    );
  }

  pw.Widget _summaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  pw.Widget _cell(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black),
      ),
    );
  }

  Future<File> _writeToTempFile(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    return file;
  }

  Future<File> _writeBytesToTempFile(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }
}
