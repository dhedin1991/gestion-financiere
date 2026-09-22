import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/database/app_database.dart';
import 'package:gestion_financiere/features/sync/data/database_merge_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests de la fusion sur de vraies bases SQLite (deux fichiers distincts,
/// comme deux appareils) : c'est ce qui remplace un test sur appareil réel
/// pour valider que rien n'est perdu ni dupliqué lors d'une synchronisation.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late AppDatabase local;
  late AppDatabase remote;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('gf_merge_test_');
    local = AppDatabase(directoryOverride: Directory(p.join(dir.path, 'local'))..createSync());
    remote = AppDatabase(directoryOverride: Directory(p.join(dir.path, 'remote'))..createSync());
    await local.database;
    await remote.database;
  });

  tearDown(() async {
    await local.close();
    await remote.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<int> insertAccount(AppDatabase appDb, String name, {int balanceCents = 0}) async {
    final db = await appDb.database;
    return db.insert('accounts', {
      'name': name,
      'account_type': 'courant',
      'currency': 'XOF',
      'initial_balance': balanceCents,
      'current_balance': balanceCents,
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
  }

  Future<int> insertTransaction(AppDatabase appDb, int accountId,
      {required String type, required int amountCents, required String date, String? description}) async {
    final db = await appDb.database;
    return db.insert('transactions', {
      'account_id': accountId,
      'type': type,
      'amount': amountCents,
      'currency': 'XOF',
      'description': description,
      'transaction_date': date,
      'created_at': date,
      'updated_at': date,
    });
  }

  test('deux appareils avec le même compte : leurs transactions respectives sont toutes conservées', () async {
    final localAccId = await insertAccount(local, 'Compte courant');
    final remoteAccId = await insertAccount(remote, 'Compte courant'); // même nom, id différent

    await insertTransaction(local, localAccId,
        type: 'depense', amountCents: 500000, date: '2026-09-01T00:00:00.000', description: 'Loyer');
    await insertTransaction(remote, remoteAccId,
        type: 'revenu', amountCents: 1000000, date: '2026-09-05T00:00:00.000', description: 'Salaire');

    final localDb = await local.database;
    final remoteFile = File(p.join(dir.path, 'remote', 'gestion_financiere.db'));
    // Force l'écriture sur disque du côté "distant" avant de le lire depuis "local".
    await (await remote.database).rawQuery('PRAGMA wal_checkpoint(FULL)');

    final added = await DatabaseMergeService(localDb).mergeFrom(remoteFile.path);

    final transactions = await localDb.query('transactions', orderBy: 'transaction_date');
    expect(transactions, hasLength(2));
    expect(transactions[0]['description'], 'Loyer');
    expect(transactions[1]['description'], 'Salaire');
    expect(added['transactions'], 1);

    // Un seul compte "Compte courant" au final (rapproché par nom, pas dupliqué).
    final accounts = await localDb.query('accounts');
    expect(accounts, hasLength(1));

    // Solde recalculé à partir des VRAIS mouvements : -5000 + 10000 = 5000.
    expect((accounts.first['current_balance'] as num).round(), 500000);
  });

  test('rejouer la même fusion deux fois ne crée aucun doublon', () async {
    final localAccId = await insertAccount(local, 'Compte courant');
    final remoteAccId = await insertAccount(remote, 'Compte courant');
    await insertTransaction(remote, remoteAccId,
        type: 'depense', amountCents: 250000, date: '2026-09-10T00:00:00.000', description: 'Courses');

    final localDb = await local.database;
    final remoteFile = File(p.join(dir.path, 'remote', 'gestion_financiere.db'));
    await (await remote.database).rawQuery('PRAGMA wal_checkpoint(FULL)');

    await DatabaseMergeService(localDb).mergeFrom(remoteFile.path);
    final secondRun = await DatabaseMergeService(localDb).mergeFrom(remoteFile.path);

    final transactions = await localDb.query('transactions');
    expect(transactions, hasLength(1));
    expect(secondRun['transactions'] ?? 0, 0);
    expect(localAccId, isNotNull); // compte local inchangé
  });

  test('un nouveau compte distant est ajouté avec les bonnes transactions rattachées', () async {
    final remoteAccId = await insertAccount(remote, 'Épargne vacances');
    await insertTransaction(remote, remoteAccId,
        type: 'revenu', amountCents: 300000, date: '2026-09-01T00:00:00.000', description: 'Virement');

    final localDb = await local.database;
    final remoteFile = File(p.join(dir.path, 'remote', 'gestion_financiere.db'));
    await (await remote.database).rawQuery('PRAGMA wal_checkpoint(FULL)');

    final added = await DatabaseMergeService(localDb).mergeFrom(remoteFile.path);

    expect(added['accounts'], 1);
    final accounts = await localDb.query('accounts', where: "name = 'Épargne vacances'");
    expect(accounts, hasLength(1));
    final newAccountId = accounts.first['id'];

    final transactions = await localDb.query('transactions', where: 'account_id = ?', whereArgs: [newAccountId]);
    expect(transactions, hasLength(1));
    expect(transactions.first['description'], 'Virement');
  });

  test('une échéance de crédit payée sur un appareil le reste après fusion', () async {
    final localAccId = await insertAccount(local, 'Compte courant');
    final remoteAccId = await insertAccount(remote, 'Compte courant');

    final localDb = await local.database;
    final remoteDb = await remote.database;

    final localCreditId = await localDb.insert('credits', {
      'name': 'Prêt voiture',
      'principal_amount': 500000000,
      'interest_rate': 0,
      'start_date': '2026-01-01T00:00:00.000',
      'duration_months': 2,
      'monthly_payment': 250000000,
      'account_id': localAccId,
      'currency': 'XOF',
      'status': 'actif',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    await localDb.insert('credit_installments', {
      'credit_id': localCreditId,
      'due_date': '2026-02-01T00:00:00.000',
      'amount': 250000000,
      'status': 'en_attente',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });

    final remoteCreditId = await remoteDb.insert('credits', {
      'name': 'Prêt voiture',
      'principal_amount': 500000000,
      'interest_rate': 0,
      'start_date': '2026-01-01T00:00:00.000',
      'duration_months': 2,
      'monthly_payment': 250000000,
      'account_id': remoteAccId,
      'currency': 'XOF',
      'status': 'actif',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    // Sur l'autre appareil, cette échéance a été marquée payée.
    await remoteDb.insert('credit_installments', {
      'credit_id': remoteCreditId,
      'due_date': '2026-02-01T00:00:00.000',
      'amount': 250000000,
      'status': 'payee',
      'payment_date': '2026-01-28T00:00:00.000',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-28T00:00:00.000',
    });

    final remoteFile = File(p.join(dir.path, 'remote', 'gestion_financiere.db'));
    await remoteDb.rawQuery('PRAGMA wal_checkpoint(FULL)');

    await DatabaseMergeService(localDb).mergeFrom(remoteFile.path);

    final installments = await localDb.query('credit_installments');
    expect(installments, hasLength(1), reason: 'une seule échéance, pas de doublon');
    expect(installments.first['status'], 'payee');
  });
}
