import 'dart:io';

import 'package:csv/csv.dart';

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
    final content = await file.readAsString();
    final rows = const CsvToListConverter(fieldDelimiter: ';', eol: '\n').convert(content);

    if (rows.isEmpty) {
      return const ImportResult(imported: 0, skipped: 0, errors: ['Fichier vide.']);
    }

    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    // Ignore la ligne d'en-tête (index 0).
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) {
        skipped++;
        continue;
      }
      try {
        final dateParts = row[0].toString().split('/');
        final date = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
        );
        final accountName = row[1].toString().trim();
        final typeStr = row[2].toString().trim().toLowerCase();
        final categoryName = row[3].toString().trim();
        final description = row[4].toString().trim();
        final amount = double.parse(row[5].toString().replaceAll(',', '.'));
        final currency = row.length > 6 ? row[6].toString().trim() : 'XOF';

        final account = accounts.where((a) => a.name.toLowerCase() == accountName.toLowerCase());
        if (account.isEmpty) {
          errors.add('Ligne ${i + 1} : compte "$accountName" introuvable, ignorée.');
          skipped++;
          continue;
        }

        final category = categories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase());
        final type = typeStr.contains('revenu') ? TransactionType.revenu : TransactionType.depense;

        await _transactionRepository.createTransaction(FinancialTransaction(
          accountId: account.first.id!,
          categoryId: category.isNotEmpty ? category.first.id : null,
          type: type,
          amount: amount.abs(),
          currency: currency.isEmpty ? 'XOF' : currency,
          description: description.isEmpty ? null : description,
          transactionDate: date,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        imported++;
      } catch (e) {
        errors.add('Ligne ${i + 1} : format invalide, ignorée.');
        skipped++;
      }
    }

    return ImportResult(imported: imported, skipped: skipped, errors: errors);
  }
}
