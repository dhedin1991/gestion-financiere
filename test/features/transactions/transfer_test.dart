import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/database/app_database.dart';
import 'package:gestion_financiere/features/audit_log/data/audit_log_dao.dart';
import 'package:gestion_financiere/features/transactions/data/datasources/transaction_dao.dart';
import 'package:gestion_financiere/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:gestion_financiere/features/transactions/domain/entities/transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Virement entre comptes : les deux écritures liées, l'effet sur les deux
/// soldes, l'exclusion des totaux Revenus/Dépenses, et la suppression
/// groupée — sur une vraie base SQLite.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late AppDatabase appDb;
  late TransactionRepositoryImpl repo;
  late TransactionDao dao;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('gf_transfer_test_');
    appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;
    dao = TransactionDao(appDb);
    repo = TransactionRepositoryImpl(dao, AuditLogDao(appDb));

    await db.insert('accounts', {
      'id': 1,
      'name': 'Compte courant',
      'account_type': 'courant',
      'currency': 'XOF',
      'initial_balance': 100000000,
      'current_balance': 100000000,
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    await db.insert('accounts', {
      'id': 2,
      'name': 'Épargne',
      'account_type': 'epargne',
      'currency': 'XOF',
      'initial_balance': 0,
      'current_balance': 0,
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
  });

  tearDown(() async {
    await appDb.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('un virement crée deux écritures liées et met à jour les deux soldes', () async {
    await repo.createTransfer(
      fromAccountId: 1,
      toAccountId: 2,
      amount: 50000,
      currency: 'XOF',
      date: DateTime(2026, 9, 1),
      description: 'Épargne du mois',
    );

    final db = await appDb.database;
    final accounts = {for (final a in await db.query('accounts')) a['id']: a};
    expect((accounts[1]!['current_balance'] as num).round(), 95000000);
    expect((accounts[2]!['current_balance'] as num).round(), 5000000);

    final transactions = await repo.getTransactions(limit: 10);
    expect(transactions, hasLength(2));
    expect(transactions.every((t) => t.isTransfer), isTrue);
    final groups = transactions.map((t) => t.transferGroup).toSet();
    expect(groups, hasLength(1), reason: 'les deux écritures partagent le même transfer_group');
  });

  test('un virement n\'entre jamais dans les totaux Revenus/Dépenses', () async {
    await repo.createTransfer(
      fromAccountId: 1,
      toAccountId: 2,
      amount: 50000,
      currency: 'XOF',
      date: DateTime(2026, 9, 1),
    );
    final expense = await repo.getTotalByType(TransactionType.depense, currency: 'XOF');
    final income = await repo.getTotalByType(TransactionType.revenu, currency: 'XOF');
    expect(expense, 0);
    expect(income, 0);
  });

  test('supprimer un virement supprime ses deux écritures et annule l\'effet sur les deux soldes', () async {
    await repo.createTransfer(
      fromAccountId: 1,
      toAccountId: 2,
      amount: 50000,
      currency: 'XOF',
      date: DateTime(2026, 9, 1),
    );
    final transactions = await repo.getTransactions(limit: 10);
    // Supprimer UNE des deux moitiés doit supprimer les deux (voir deleteTransaction).
    await repo.deleteTransaction(transactions.first.id!);

    final remaining = await repo.getTransactions(limit: 10);
    expect(remaining, isEmpty);

    final db = await appDb.database;
    final accounts = {for (final a in await db.query('accounts')) a['id']: a};
    expect((accounts[1]!['current_balance'] as num).round(), 100000000);
    expect((accounts[2]!['current_balance'] as num).round(), 0);
  });

  test('refuse un virement vers le même compte ou un montant nul', () async {
    expect(
      () => repo.createTransfer(
          fromAccountId: 1, toAccountId: 1, amount: 100, currency: 'XOF', date: DateTime(2026, 9, 1)),
      throwsArgumentError,
    );
    expect(
      () => repo.createTransfer(
          fromAccountId: 1, toAccountId: 2, amount: 0, currency: 'XOF', date: DateTime(2026, 9, 1)),
      throwsArgumentError,
    );
  });
}
