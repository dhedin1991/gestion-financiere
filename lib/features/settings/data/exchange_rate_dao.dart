import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

/// Taux de change saisis à la main par l'utilisateur (voir le commentaire
/// sur la table `exchange_rates`). Aucun appel réseau : l'app reste
/// 100% hors ligne, ces taux doivent être mis à jour manuellement.
class ExchangeRateDao {
  final AppDatabase appDatabase;
  ExchangeRateDao(this.appDatabase);

  /// `{ 'EUR': 655.0, 'USD': 610.0, ... }` — 1 unité de la devise = X XOF.
  Future<Map<String, double>> getAll() async {
    final db = await appDatabase.database;
    final rows = await db.query('exchange_rates');
    return {for (final r in rows) r['currency'] as String: (r['rate_to_xof'] as num).toDouble()};
  }

  Future<void> setRate(String currency, double rateToXof) async {
    final db = await appDatabase.database;
    await db.insert(
      'exchange_rates',
      {'currency': currency, 'rate_to_xof': rateToXof, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRate(String currency) async {
    final db = await appDatabase.database;
    await db.delete('exchange_rates', where: 'currency = ?', whereArgs: [currency]);
  }
}
