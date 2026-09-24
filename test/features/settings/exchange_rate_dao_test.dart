import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/database/app_database.dart';
import 'package:gestion_financiere/features/settings/data/exchange_rate_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late AppDatabase appDb;
  late ExchangeRateDao dao;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('gf_rates_test_');
    appDb = AppDatabase(directoryOverride: dir);
    await appDb.database;
    dao = ExchangeRateDao(appDb);
  });

  tearDown(() async {
    await appDb.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('setRate puis getAll retrouve le taux enregistré', () async {
    await dao.setRate('EUR', 655.0);
    final rates = await dao.getAll();
    expect(rates['EUR'], 655.0);
  });

  test('setRate sur une devise déjà enregistrée remplace l\\'ancien taux (pas de doublon)', () async {
    await dao.setRate('EUR', 650.0);
    await dao.setRate('EUR', 655.5);
    final rates = await dao.getAll();
    expect(rates['EUR'], 655.5);
    expect(rates.length, 1);
  });

  test('deleteRate retire la devise', () async {
    await dao.setRate('USD', 610.0);
    await dao.deleteRate('USD');
    final rates = await dao.getAll();
    expect(rates.containsKey('USD'), isFalse);
  });
}
