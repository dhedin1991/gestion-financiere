import '../../../../core/database/app_database.dart';
import '../models/credit_installment_model.dart';
import '../models/credit_model.dart';

/// Accès direct aux tables `credits` et `credit_installments`.
/// Contient aussi la logique de génération automatique de l'échéancier
/// (une échéance mensuelle par mois, sur toute la durée du crédit).
class CreditDao {
  final AppDatabase appDatabase;

  CreditDao(this.appDatabase);

  static const String _creditsTable = 'credits';
  static const String _installmentsTable = 'credit_installments';

  // ---------------- CREDITS ----------------

  /// Crée un crédit ET génère automatiquement son échéancier complet.
  Future<int> insertCreditWithSchedule(CreditModel credit) async {
    final db = await appDatabase.database;

    return db.transaction((txn) async {
      final creditId = await txn.insert(_creditsTable, credit.toMap());

      final now = DateTime.now().toIso8601String();
      for (int i = 0; i < credit.durationMonths; i++) {
        final dueDate = DateTime(
          credit.startDate.year,
          credit.startDate.month + i + 1,
          credit.startDate.day,
        );
        await txn.insert(_installmentsTable, {
          'credit_id': creditId,
          'due_date': dueDate.toIso8601String(),
          'amount': credit.monthlyPayment,
          'status': 'en_attente',
          'payment_date': null,
          'created_at': now,
          'updated_at': now,
        });
      }

      return creditId;
    });
  }

  Future<int> updateCredit(CreditModel credit) async {
    if (credit.id == null) {
      throw ArgumentError('Impossible de mettre à jour un crédit sans id');
    }
    final db = await appDatabase.database;
    return db.update(
      _creditsTable,
      credit.toMap(),
      where: 'id = ?',
      whereArgs: [credit.id],
    );
  }

  /// Supprime un crédit et, grâce à ON DELETE CASCADE, toutes ses échéances.
  Future<int> deleteCredit(int id) async {
    final db = await appDatabase.database;
    return db.delete(_creditsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<CreditModel?> getCreditById(int id) async {
    final db = await appDatabase.database;
    final results = await db.query(_creditsTable, where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return CreditModel.fromMap(results.first);
  }

  Future<List<CreditModel>> getAllCredits() async {
    final db = await appDatabase.database;
    final results = await db.query(_creditsTable, orderBy: 'start_date DESC');
    return results.map((map) => CreditModel.fromMap(map)).toList();
  }

  // ---------------- INSTALLMENTS (échéances) ----------------

  Future<List<CreditInstallmentModel>> getInstallmentsForCredit(int creditId) async {
    final db = await appDatabase.database;
    final results = await db.query(
      _installmentsTable,
      where: 'credit_id = ?',
      whereArgs: [creditId],
      orderBy: 'due_date ASC',
    );
    return results.map((map) => CreditInstallmentModel.fromMap(map)).toList();
  }

  Future<int> updateInstallment(CreditInstallmentModel installment) async {
    if (installment.id == null) {
      throw ArgumentError('Impossible de mettre à jour une échéance sans id');
    }
    final db = await appDatabase.database;
    return db.update(
      _installmentsTable,
      installment.toMap(),
      where: 'id = ?',
      whereArgs: [installment.id],
    );
  }

  /// Nombre d'échéances déjà payées pour un crédit donné.
  Future<int> countPaidInstallments(int creditId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as total FROM $_installmentsTable WHERE credit_id = ? AND status = 'payee'",
      [creditId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Somme totale déjà remboursée pour un crédit donné.
  Future<double> getTotalPaidForCredit(int creditId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM $_installmentsTable WHERE credit_id = ? AND status = 'payee'",
      [creditId],
    );
    final total = result.first['total'];
    if (total == null) return 0.0;
    return (total as num).toDouble();
  }
}
