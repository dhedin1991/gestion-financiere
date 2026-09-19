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

  test('installation neuve : schéma v14 complet', () async {
    final appDb = AppDatabase(directoryOverride: dir);
    final db = await appDb.database;

    final version = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    expect(version, AppDatabase.schemaVersion);
    expect(AppDatabase.schemaVersion, 14);

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

    final fk = (await db.rawQuery('PRAGMA foreign_keys')).first.values.first;
    expect(fk, 1);

    await appDb.close();
  });

  test('v13 -> v14 : colonne anchor_day ajoutée, données conservées', () async {
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

  test('v12 -> v14 : montants convertis en centimes entiers + sauvegarde de sécurité', () async {
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
