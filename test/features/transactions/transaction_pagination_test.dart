import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/database/app_database.dart';
import 'package:gestion_financiere/features/audit_log/data/audit_log_dao.dart';
import 'package:gestion_financiere/features/transactions/data/datasources/transaction_dao.dart';
import 'package:gestion_financiere/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:gestion_financiere/features/transactions/domain/entities/transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pagination (limit + offset) des transactions : vérifie qu'aucune ligne
/// n'est ni oubliée ni répétée en parcourant plusieurs pages, sur une
/// vraie base SQLite avec plus de transactions que la taille d'une page.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late AppDatabase appDb;
  late TransactionRepositoryImpl repo;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('gf_pagination_test_');
    appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;
    repo = TransactionRepositoryImpl(TransactionDao(appDb), AuditLogDao(appDb));

    await db.insert('accounts', {
      'id': 1,
      'name': 'Compte',
      'account_type': 'courant',
      'currency': 'XOF',
      'initial_balance': 0,
      'current_balance': 0,
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    // 25 transactions, une par jour, pour tester une pagination par pages de 10.
    for (var i = 0; i < 25; i++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: i)).toIso8601String();
      await db.insert('transactions', {
        'account_id': 1,
        'type': 'depense',
        'amount': 1000 * (i + 1),
        'currency': 'XOF',
        'description': 'Transaction $i',
        'transaction_date': date,
        'created_at': date,
        'updated_at': date,
      });
    }
  });

  tearDown(() async {
    await appDb.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('parcourir toutes les pages retrouve exactement les 25 transactions, sans doublon', () async {
    final all = <FinancialTransaction>[];
    var offset = 0;
    const pageSize = 10;
    while (true) {
      final page = await repo.getTransactions(limit: pageSize, offset: offset);
      all.addAll(page);
      offset += page.length;
      if (page.length < pageSize) break;
    }
    expect(all, hasLength(25));
    expect(all.map((t) => t.id).toSet(), hasLength(25), reason: 'aucun id en double');
  });

  test('la dernière page indique bien qu\'il n\'y en a plus (moins que pageSize)', () async {
    final page1 = await repo.getTransactions(limit: 10, offset: 0);
    final page2 = await repo.getTransactions(limit: 10, offset: 10);
    final page3 = await repo.getTransactions(limit: 10, offset: 20);
    expect(page1, hasLength(10));
    expect(page2, hasLength(10));
    expect(page3, hasLength(5)); // 25 - 20 = 5 : signal de fin de liste
  });

  test('les pages sont triées du plus récent au plus ancien, cohérentes entre elles', () async {
    final page1 = await repo.getTransactions(limit: 10, offset: 0);
    final page2 = await repo.getTransactions(limit: 10, offset: 10);
    expect(page1.first.transactionDate.isAfter(page1.last.transactionDate), isTrue);
    expect(page1.last.transactionDate.isAfter(page2.first.transactionDate), isTrue);
  });
}
