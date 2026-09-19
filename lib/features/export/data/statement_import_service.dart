import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

import '../../../core/utils/money.dart';
import '../../accounts/domain/entities/account.dart';
import '../../categories/domain/entities/category.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/domain/repositories/transaction_repository.dart';

class ImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;
  const ImportResult({required this.imported, required this.skipped, required this.errors});
}

/// Importe des transactions depuis un fichier CSV au même format que
/// celui généré par l'export (Date;Compte;Type;Catégorie;Description;
/// Montant;Devise) — séparateur point-virgule, dates dd/MM/yyyy.
///
/// Le compte et la catégorie sont retrouvés par correspondance de nom
/// (insensible à la casse) parmi ceux déjà existants dans l'app : cet
/// import ne crée ni compte ni catégorie, pour éviter les doublons créés
/// par une simple faute de frappe dans le fichier.
class StatementImportService {
  final TransactionRepository _transactionRepository;
  StatementImportService(this._transactionRepository);

  Future<ImportResult> importCsv({
    required File file,
    required List<Account> accounts,
    required List<AppCategory> categories,
  }) async {
    final content = _decode(await file.readAsBytes())
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final rows = const CsvToListConverter(fieldDelimiter: ';', eol: '\n').convert(content);

    if (rows.isEmpty) {
      return const ImportResult(imported: 0, skipped: 0, errors: ['Fichier vide.']);
    }

    var skipped = 0;
    final errors = <String>[];

    // 1) Lecture et validation de toutes les lignes AVANT la moindre écriture.
    final parsed = <_ParsedRow>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) {
        skipped++;
        continue;
      }
      try {
        final dateParts = row[0].toString().trim().split('/');
        final date = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
        );
        final accountName = row[1].toString().trim();
        final typeStr = row[2].toString().trim().toLowerCase();
        final categoryName = row[3].toString().trim();
        final description = row[4].toString().trim();
        final amount = _parseAmount(row[5].toString());
        final currency = row.length > 6 ? row[6].toString().trim() : 'XOF';

        final account = accounts.where((a) => a.name.toLowerCase() == accountName.toLowerCase());
        if (account.isEmpty) {
          errors.add('Ligne ${i + 1} : compte "$accountName" introuvable, ignorée.');
          skipped++;
          continue;
        }

        final category = categories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase());
        final type = typeStr.contains('revenu') ? TransactionType.revenu : TransactionType.depense;

        parsed.add(_ParsedRow(
          accountId: account.first.id!,
          categoryId: category.isNotEmpty ? category.first.id : null,
          type: type,
          amount: amount.abs(),
          currency: currency.isEmpty ? 'XOF' : currency,
          description: description.isEmpty ? null : description,
          date: date,
        ));
      } catch (e) {
        errors.add('Ligne ${i + 1} : format invalide, ignorée.');
        skipped++;
      }
    }

    // 2) Détection des doublons : on compte, par compte, les transactions
    //    déjà présentes sur la période du fichier. Une ligne du fichier qui
    //    correspond à une transaction existante est ignorée (un fichier
    //    réimporté ne double plus les données), en tenant compte du nombre
    //    d'occurrences (deux achats identiques le même jour restent possibles).
    final existingCounts = <String, int>{};
    final byAccount = <int, List<_ParsedRow>>{};
    for (final r in parsed) {
      byAccount.putIfAbsent(r.accountId, () => []).add(r);
    }
    for (final entry in byAccount.entries) {
      final dates = entry.value.map((r) => r.date).toList()..sort();
      final existing = await _transactionRepository.getTransactions(
        accountId: entry.key,
        from: dates.first,
        to: dates.last.add(const Duration(days: 1)),
        limit: 100000,
      );
      for (final t in existing) {
        final key = _key(entry.key, t.transactionDate, t.type, t.amount, t.description);
        existingCounts[key] = (existingCounts[key] ?? 0) + 1;
      }
    }

    // 3) Création des transactions restantes.
    var imported = 0;
    var duplicates = 0;
    for (final r in parsed) {
      final key = _key(r.accountId, r.date, r.type, r.amount, r.description);
      final remaining = existingCounts[key] ?? 0;
      if (remaining > 0) {
        existingCounts[key] = remaining - 1;
        duplicates++;
        continue;
      }
      try {
        await _transactionRepository.createTransaction(FinancialTransaction(
          accountId: r.accountId,
          categoryId: r.categoryId,
          type: r.type,
          amount: r.amount,
          currency: r.currency,
          description: r.description,
          transactionDate: r.date,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        imported++;
      } catch (e) {
        errors.add('Une transaction du ${r.date.day}/${r.date.month}/${r.date.year} n\'a pas pu être enregistrée.');
        skipped++;
      }
    }

    if (duplicates > 0) {
      errors.add('$duplicates transaction(s) déjà présente(s) dans l\'app : ignorée(s) (doublons).');
      skipped += duplicates;
    }

    return ImportResult(imported: imported, skipped: skipped, errors: errors);
  }

  static String _key(int accountId, DateTime date, TransactionType type, double amount, String? description) {
    final d = '${date.year}-${date.month}-${date.day}';
    return '$accountId|$d|${type.name}|${Money.toCents(amount)}|${(description ?? '').trim().toLowerCase()}';
  }

  /// UTF-8 (BOM ignoré) ; si le fichier n'est pas de l'UTF-8 valide (export
  /// Excel en Windows-1252), repli sur Latin-1 plutôt que d'échouer.
  static String _decode(List<int> bytes) {
    var data = bytes;
    if (data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) {
      data = data.sublist(3);
    }
    try {
      return utf8.decode(data);
    } catch (_) {
      return latin1.decode(data);
    }
  }

  /// Accepte « 1500 », « 1500,50 », « 1 500,50 », « 1.500,50 », « 1,500.50 ».
  /// Quand les deux séparateurs sont présents, le dernier est la décimale.
  static double _parseAmount(String raw) {
    var v = raw.trim().replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
    final lastComma = v.lastIndexOf(',');
    final lastDot = v.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        v = v.replaceAll('.', '').replaceAll(',', '.');
      } else {
        v = v.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      v = v.replaceAll(',', '.');
    }
    return double.parse(v);
  }
}

class _ParsedRow {
  final int accountId;
  final int? categoryId;
  final TransactionType type;
  final double amount;
  final String currency;
  final String? description;
  final DateTime date;

  const _ParsedRow({
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.description,
    required this.date,
  });
}
