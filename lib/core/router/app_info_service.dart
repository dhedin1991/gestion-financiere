import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// Statistiques globales de l'application (nombre d'éléments dans chaque
/// module) et informations sur l'espace de stockage utilisé.
class AppUsageStats {
  final int accountsCount;
  final int transactionsCount;
  final int debtsCount;
  final int budgetsCount;
  final int savingsCount;
  final int patrimoineItemsCount;
  final int creditsCount;
  final int databaseSizeBytes;

  const AppUsageStats({
    required this.accountsCount,
    required this.transactionsCount,
    required this.debtsCount,
    required this.budgetsCount,
    required this.savingsCount,
    required this.patrimoineItemsCount,
    required this.creditsCount,
    required this.databaseSizeBytes,
  });

  /// Taille formatée de façon lisible (Ko, Mo...).
  String get formattedSize {
    if (databaseSizeBytes < 1024) return '$databaseSizeBytes o';
    if (databaseSizeBytes < 1024 * 1024) {
      return '${(databaseSizeBytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(databaseSizeBytes / (1024 * 1024)).toStringAsFixed(2)} Mo';
  }
}

class AppInfoService {
  final AppDatabase appDatabase;

  AppInfoService(this.appDatabase);

  Future<int> _countRows(String table) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM $table');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> _getDatabaseFileSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'gestion_financiere.db');
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<AppUsageStats> computeStats() async {
    final accountsCount = await _countRows('accounts');
    final transactionsCount = await _countRows('transactions');
    final debtsCount = await _countRows('debts');
    final budgetsCount = await _countRows('budgets');
    final savingsCount = await _countRows('savings');
    final patrimoineItemsCount = await _countRows('patrimoine_items');
    final creditsCount = await _countRows('credits');
    final sizeBytes = await _getDatabaseFileSize();

    return AppUsageStats(
      accountsCount: accountsCount,
      transactionsCount: transactionsCount,
      debtsCount: debtsCount,
      budgetsCount: budgetsCount,
      savingsCount: savingsCount,
      patrimoineItemsCount: patrimoineItemsCount,
      creditsCount: creditsCount,
      databaseSizeBytes: sizeBytes,
    );
  }
}
