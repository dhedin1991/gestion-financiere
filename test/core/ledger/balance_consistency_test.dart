import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestion_financiere/core/database/app_database.dart';
import 'package:gestion_financiere/core/database/database_providers.dart';
import 'package:gestion_financiere/core/ledger/operation_service.dart';
import 'package:gestion_financiere/features/debts/presentation/providers/debt_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Cohérence des soldes sur une vraie base SQLite : après chaque opération,
///   solde = solde initial + somme des écritures du grand livre.
/// Montants stockés en centimes (×100).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late AppDatabase appDb;
  late ProviderContainer container;
  late OperationService ops;

  const caisse = 1, moov = 2, banque = 3, epargneImm = 4;
  final day = DateTime(2026, 9, 1);

  Future<void> addAccount(Database db, int id, String name, String type, int initialUnits, {String? role}) =>
      db.insert('accounts', {
        'id': id,
        'name': name,
        'account_type': type,
        'currency': 'XOF',
        'initial_balance': initialUnits * 100,
        'current_balance': initialUnits * 100,
        'role': role,
        'is_archived': 0,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('gf_ledger_test_');
    appDb = AppDatabase(directoryOverride: dir);
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(appDb)]);
    ops = container.read(operationServiceProvider);
    final db = await appDb.database;
    await addAccount(db, caisse, 'Agent liquide', 'especes', 100000, role: 'caisse');
    await addAccount(db, moov, 'Moov', 'mobileMoney', 500000);
    await addAccount(db, banque, 'Banque courante', 'courant', 200000);
    await addAccount(db, epargneImm, 'Épargne immédiate', 'epargne', 0, role: 'epargne');
  });

  tearDown(() async {
    // Laisse finir les rechargements asynchrones déclenchés par les invalidations.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    try {
      container.dispose();
    } catch (_) {
      // Riverpod peut signaler « Future already completed » à la fermeture après
      // des invalidations : sans conséquence pour les soldes vérifiés ici.
    }
    await appDb.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<int> balance(int id) async {
    final db = await appDb.database;
    final r = await db.query('accounts', columns: ['current_balance'], where: 'id = ?', whereArgs: [id]);
    return (r.first['current_balance'] as num).round() ~/ 100;
  }

  /// solde == initial + somme des écritures, pour tous les comptes.
  Future<void> expectLedgerConsistent() async {
    final db = await appDb.database;
    for (final a in await db.query('accounts')) {
      final s = await db.rawQuery(
        "SELECT COALESCE(SUM(CASE WHEN type='revenu' THEN amount ELSE -amount END),0) AS s "
        'FROM transactions WHERE account_id = ?',
        [a['id']],
      );
      final expected = (a['initial_balance'] as num).round() + (s.first['s'] as num).round();
      expect((a['current_balance'] as num).round(), expected, reason: 'compte ${a['name']} incohérent avec le grand livre');
    }
  }

  /// Total des vraies dépenses / revenus (hors opérations neutres), en unités.
  Future<int> realTotal(String type) async {
    final db = await appDb.database;
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE type = ? AND transfer_group IS NULL',
      [type],
    );
    return (r.first['s'] as num).round() ~/ 100;
  }

  Future<int> count(String table) async {
    final db = await appDb.database;
    return (await db.rawQuery('SELECT COUNT(*) AS c FROM $table')).first['c'] as int;
  }

  test('retrait Moov vers caisse : Moov baisse, caisse monte, rien dans les stats', () async {
    await ops.execute(OperationRequest(kind: OperationKind.retrait, amount: 50000, date: day, accountId: moov, toAccountId: caisse));
    expect(await balance(moov), 450000);
    expect(await balance(caisse), 150000);
    expect(await realTotal('revenu'), 0);
    expect(await realTotal('depense'), 0);
    await expectLedgerConsistent();
  });

  test('transfert entre comptes : soldes déplacés, total inchangé', () async {
    await ops.execute(OperationRequest(kind: OperationKind.transfert, amount: 30000, date: day, accountId: banque, toAccountId: moov));
    expect(await balance(banque), 170000);
    expect(await balance(moov), 530000);
    expect(await balance(banque) + await balance(moov), 700000);
    await expectLedgerConsistent();
  });

  test('dépôt : le solde augmente sans compter comme revenu', () async {
    await ops.execute(OperationRequest(kind: OperationKind.depot, amount: 10000, date: day, accountId: caisse));
    expect(await balance(caisse), 110000);
    expect(await realTotal('revenu'), 0);
    await expectLedgerConsistent();
  });

  test('épargne vers le compte d’épargne immédiate', () async {
    await ops.execute(OperationRequest(kind: OperationKind.epargne, amount: 20000, date: day, accountId: moov, toAccountId: epargneImm));
    expect(await balance(moov), 480000);
    expect(await balance(epargneImm), 20000);
    await expectLedgerConsistent();
  });

  test('suppression d’un transfert supprime les deux écritures et rétablit les soldes', () async {
    await ops.execute(OperationRequest(kind: OperationKind.transfert, amount: 30000, date: day, accountId: banque, toAccountId: moov));
    final db = await appDb.database;
    final first = (await db.query('transactions', orderBy: 'id ASC', limit: 1)).first['id'] as int;
    await ops.deleteLedgerEntry(first);
    expect(await count('transactions'), 0);
    expect(await balance(banque), 200000);
    expect(await balance(moov), 500000);
    await expectLedgerConsistent();
  });

  test('dette contractée puis remboursée en deux fois, puis supprimée', () async {
    await ops.execute(OperationRequest(
        kind: OperationKind.detteRecue, amount: 100000, date: day, accountId: caisse, counterparty: 'Fournisseur'));
    expect(await balance(caisse), 200000);
    await expectLedgerConsistent();

    final db = await appDb.database;
    final debtId = (await db.query('debts')).first['id'] as int;

    await ops.execute(OperationRequest(kind: OperationKind.rembDette, amount: 40000, date: day, accountId: caisse, debtId: debtId));
    expect(await balance(caisse), 160000);
    await ops.execute(OperationRequest(kind: OperationKind.rembDette, amount: 60000, date: day, accountId: caisse, debtId: debtId));
    expect(await balance(caisse), 100000);
    await expectLedgerConsistent();

    // Un remboursement au-delà du reste dû est refusé.
    expect(
      () => ops.execute(OperationRequest(kind: OperationKind.rembDette, amount: 1, date: day, accountId: caisse, debtId: debtId)),
      throwsA(isA<ArgumentError>()),
    );

    await container.read(debtActionsProvider).delete(debtId);
    expect(await count('debts'), 0);
    expect(await balance(caisse), 100000, reason: 'retour au solde de départ après suppression en cascade');
    expect(await count('transactions'), 0);
    await expectLedgerConsistent();
  });

  test('créance accordée puis encaissée', () async {
    await ops.execute(OperationRequest(
        kind: OperationKind.creanceAccordee, amount: 25000, date: day, accountId: caisse, counterparty: 'Client'));
    expect(await balance(caisse), 75000);
    final db = await appDb.database;
    final debtId = (await db.query('debts')).first['id'] as int;
    await ops.execute(OperationRequest(kind: OperationKind.encaissementCreance, amount: 25000, date: day, accountId: caisse, debtId: debtId));
    expect(await balance(caisse), 100000);
    await expectLedgerConsistent();
  });

  test('achat à crédit : dépense comptée, solde inchangé, dette créée ; remboursement débite', () async {
    await ops.execute(OperationRequest(
        kind: OperationKind.achatCredit, amount: 80000, date: day, accountId: caisse, counterparty: 'Grossiste', description: 'Marchandises'));
    expect(await balance(caisse), 100000, reason: 'le solde ne bouge pas avant remboursement');
    expect(await realTotal('depense'), 80000, reason: 'la dépense réelle est comptée');
    expect(await count('debts'), 1);
    await expectLedgerConsistent();

    final db = await appDb.database;
    final debtId = (await db.query('debts')).first['id'] as int;
    await ops.execute(OperationRequest(kind: OperationKind.rembDette, amount: 80000, date: day, accountId: caisse, debtId: debtId));
    expect(await balance(caisse), 20000);
    expect(await realTotal('depense'), 80000, reason: 'le remboursement n’est pas une seconde dépense');
    await expectLedgerConsistent();
  });

  test('crédit contracté, échéance payée puis annulée, crédit supprimé', () async {
    await ops.execute(OperationRequest(
        kind: OperationKind.creditRecu, amount: 120000, date: day, accountId: banque, counterparty: 'Prêt banque', durationMonths: 12));
    expect(await balance(banque), 320000);
    expect(await realTotal('revenu'), 0, reason: 'un crédit reçu n’est pas un revenu');
    await expectLedgerConsistent();

    final db = await appDb.database;
    final creditId = (await db.query('credits')).first['id'] as int;
    final inst = (await db.query('credit_installments', where: 'credit_id = ?', whereArgs: [creditId], orderBy: 'due_date ASC')).first;
    final instId = inst['id'] as int;
    final instAmount = (inst['amount'] as num).round() ~/ 100;

    await ops.execute(OperationRequest(
        kind: OperationKind.rembCredit, amount: instAmount.toDouble(), date: day, accountId: banque, creditId: creditId, installmentId: instId));
    expect(await balance(banque), 320000 - instAmount);
    await expectLedgerConsistent();

    final payTx = (await db.query('transactions', where: "kind = 'remb_credit'")).first['id'] as int;
    await ops.deleteLedgerEntry(payTx);
    expect(await balance(banque), 320000, reason: 'annuler le remboursement rend l’argent');
    await expectLedgerConsistent();

    final creditTx = (await db.query('transactions', where: "kind = 'credit_recu'")).first['id'] as int;
    await ops.deleteLedgerEntry(creditTx);
    expect(await count('credits'), 0);
    expect(await balance(banque), 200000);
    expect(await count('transactions'), 0);
    await expectLedgerConsistent();
  });

  test('enchaînement complet : tout reste cohérent avec le grand livre', () async {
    await ops.execute(OperationRequest(kind: OperationKind.retrait, amount: 100000, date: day, accountId: moov, toAccountId: caisse));
    await ops.execute(OperationRequest(kind: OperationKind.epargne, amount: 50000, date: day, accountId: caisse, toAccountId: moov));
    await ops.execute(OperationRequest(kind: OperationKind.transfert, amount: 70000, date: day, accountId: banque, toAccountId: caisse));
    await ops.execute(OperationRequest(kind: OperationKind.achatCredit, amount: 15000, date: day, accountId: caisse, counterparty: 'X'));
    await ops.execute(OperationRequest(kind: OperationKind.depot, amount: 5000, date: day, accountId: banque));
    await expectLedgerConsistent();
    final total = await balance(caisse) + await balance(moov) + await balance(banque) + await balance(epargneImm);
    expect(total, 100000 + 500000 + 200000 + 5000, reason: 'seul le dépôt crée de l’argent ; l’achat à crédit est neutre sur le solde');
  });
}
