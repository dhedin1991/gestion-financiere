import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests d'intégration des migrations SQLite (base réelle en fichier
/// temporaire, via sqflite_common_ffi) : c'est ce qui protège les données
/// financières lors d'une mise à jour de l'app.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gf_migration_test_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String dbPath() => p.join(dir.path, 'gestion_financiere.db');

  Future<Database> openRaw(int version, Future<void> Function(Database db) onCreate) {
    return openDatabase(dbPath(), version: version, onCreate: (db, _) => onCreate(db));
  }

  test('installation neuve : schéma v19 complet', () async {
    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final version = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    expect(version, AppDatabase.schemaVersion);
    expect(AppDatabase.schemaVersion, 19);

    final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
        .map((r) => r['name'] as String)
        .toSet();
    for (final t in [
      'accounts',
      'transactions',
      'recurring_transactions',
      'savings',
      'savings_transactions',
      'credits',
      'credit_installments',
      'debts',
      'debt_payments',
      'budgets',
    ]) {
      expect(tables, contains(t), reason: 'table $t manquante');
    }

    final cols = (await db.rawQuery('PRAGMA table_info(recurring_transactions)'))
        .map((c) => c['name'])
        .toSet();
    expect(cols, contains('anchor_day'));

    final savingsCols = (await db.rawQuery('PRAGMA table_info(savings)')).map((c) => c['name']).toSet();
    expect(savingsCols, contains('category'));

    final fk = (await db.rawQuery('PRAGMA foreign_keys')).first.values.first;
    expect(fk, 1);

    await appDb.close();
  });

  test('v13 -> v15 : colonne anchor_day ajoutée, données conservées', () async {
    final raw = await openRaw(13, (db) async {
      await db.execute('''
        CREATE TABLE recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          next_due_date TEXT NOT NULL
        )
      ''');
      await db.insert('recurring_transactions',
          {'account_id': 1, 'amount': 150000, 'next_due_date': '2026-10-31T00:00:00.000'});
    });
    await raw.close();

    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final cols = (await db.rawQuery('PRAGMA table_info(recurring_transactions)'))
        .map((c) => c['name'])
        .toSet();
    expect(cols, contains('anchor_day'));

    final rows = await db.query('recurring_transactions');
    expect(rows, hasLength(1));
    expect(rows.first['amount'], 150000);
    expect(rows.first['anchor_day'], isNull);

    await appDb.close();
  });

  test('v12 -> v15 : montants convertis en centimes entiers + sauvegarde de sécurité', () async {
    final raw = await openRaw(12, (db) async {
      await db.execute(
          'CREATE TABLE accounts (id INTEGER PRIMARY KEY, initial_balance REAL, current_balance REAL)');
      await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, amount REAL)');
      await db.insert('accounts', {'id': 1, 'initial_balance': 1000.0, 'current_balance': 1500.5});
      await db.insert('transactions', {'id': 1, 'amount': 0.1});
      await db.insert('transactions', {'id': 2, 'amount': 2500.0});
    });
    await raw.close();

    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final account = (await db.query('accounts')).first;
    expect((account['initial_balance'] as num).round(), 100000);
    expect((account['current_balance'] as num).round(), 150050);

    final amounts = (await db.query('transactions', orderBy: 'id'))
        .map((r) => (r['amount'] as num).round())
        .toList();
    expect(amounts, [10, 250000]);

    final backups = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('avant_migration_centimes_'))
        .toList();
    expect(backups, isNotEmpty, reason: 'la sauvegarde avant migration doit exister');

    await appDb.close();
  });

  test('v14 -> v15 : photos existantes rattachées à la première entité, index par entité', () async {
    final raw = await openRaw(14, (db) async {
      await db.execute(
          'CREATE TABLE business_entities (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, type TEXT, created_at TEXT)');
      await db.insert('business_entities', {'name': 'Personnel', 'type': 'personnel', 'created_at': 'x'});
      await db.insert('business_entities', {'name': 'Société', 'type': 'entreprise', 'created_at': 'x'});
      await db.execute('''
        CREATE TABLE net_worth_snapshots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          snapshot_date TEXT NOT NULL,
          net_worth REAL NOT NULL
        )
      ''');
      await db.execute('CREATE UNIQUE INDEX idx_snapshot_date ON net_worth_snapshots (snapshot_date)');
      await db.insert('net_worth_snapshots', {'snapshot_date': '2026-09-01', 'net_worth': 500000});
    });
    await raw.close();

    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final old = (await db.query('net_worth_snapshots')).first;
    expect(old['entity_id'], 1, reason: 'rattachée à Personnel');
    expect(old['net_worth'], 500000);

    // Deux entités peuvent avoir chacune leur photo le même jour...
    await db.insert('net_worth_snapshots',
        {'snapshot_date': '2026-09-01', 'net_worth': 100, 'entity_id': 2});
    // ... mais pas deux fois pour la même entité.
    expect(
      () => db.insert('net_worth_snapshots',
          {'snapshot_date': '2026-09-01', 'net_worth': 1, 'entity_id': 2}),
      throwsA(isA<DatabaseException>()),
    );

    final safety = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('avant_migration_v14_'));
    expect(safety, isNotEmpty, reason: 'toute migration doit être précédée d\'une copie');

    await appDb.close();
  });

  test('v15 -> v16 : colonne transfer_group ajoutée, transactions existantes conservées', () async {
    final raw = await openRaw(15, (db) async {
      await db.execute(
          'CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER, type TEXT, amount INTEGER, transaction_date TEXT)');
      await db.insert('transactions',
          {'account_id': 1, 'type': 'depense', 'amount': 100000, 'transaction_date': '2026-09-01'});
    });
    await raw.close();

    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final cols = (await db.rawQuery('PRAGMA table_info(transactions)')).map((c) => c['name']).toSet();
    expect(cols, contains('transfer_group'));

    final rows = await db.query('transactions');
    expect(rows, hasLength(1));
    expect(rows.first['amount'], 100000);
    expect(rows.first['transfer_group'], isNull);

    await appDb.close();
  });

  test('v16 -> v17 : table exchange_rates créée', () async {
    final raw = await openRaw(16, (db) async {});
    await raw.close();

    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
        .map((r) => r['name'] as String)
        .toSet();
    expect(tables, contains('exchange_rates'));

    await db.insert('exchange_rates', {'currency': 'EUR', 'rate_to_xof': 655.0, 'updated_at': 'x'});
    final rows = await db.query('exchange_rates');
    expect(rows, hasLength(1));

    await appDb.close();
  });

  test('v18 -> v19 : catégorie d\'épargne ajoutée, épargnes existantes rangées dans « libre »', () async {
    final raw = await openRaw(18, (db) async {
      await db.execute(
          'CREATE TABLE savings (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, account_id INTEGER NOT NULL, current_balance INTEGER NOT NULL DEFAULT 0)');
      await db.insert('savings', {'name': 'Fonds', 'account_id': 1, 'current_balance': 500000});
    });
    await raw.close();

    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final rows = await db.query('savings');
    expect(rows, hasLength(1));
    expect(rows.first['name'], 'Fonds');
    expect(rows.first['current_balance'], 500000);
    expect(rows.first['category'], 'libre');

    final backups = dir.listSync().whereType<File>().where((f) => p.basename(f.path).startsWith('avant_migration_v18_'));
    expect(backups, isNotEmpty);

    await appDb.close();
  });

  test('ouvertures simultanées : une seule connexion, aucune erreur', () async {
    final appDb = AppDatabase(directoryOverride: dir);
    final results = await Future.wait([
      appDb.database,
      appDb.database,
      appDb.database,
      appDb.database,
    ]);
    expect(results.every((d) => identical(d, results.first)), isTrue);
    // La base reste utilisable (elle n'a pas été fermée par une autre ouverture).
    expect(await results.first.rawQuery('SELECT 1 AS ok'), isNotEmpty);
    await appDb.close();
  });
}
