import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money.dart';
import '../models/credit_installment_model.dart';
import '../models/credit_model.dart';
import '../../../../core/utils/month_math.dart';

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
        final dueDate = addMonthsClamped(credit.startDate, i + 1);
        await txn.insert(_installmentsTable, {
          'credit_id': creditId,
          'due_date': dueDate.toIso8601String(),
          'amount': Money.toCents(credit.monthlyPayment),
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
    return db.transaction((txn) async {
      final previous = await txn.query(
        _installmentsTable,
        columns: ['status', 'amount', 'credit_id'],
        where: 'id = ?',
        whereArgs: [installment.id],
        limit: 1,
      );
      final newRow = installment.toMap();
      final rows = await txn.update(
        _installmentsTable,
        newRow,
        where: 'id = ?',
        whereArgs: [installment.id],
      );

      // Effet sur le compte de remboursement du crédit (comme pour les
      // dettes) : payer une échéance débite le compte, l'annuler le recrédite.
      // Déduit de la transition réelle du statut en base, donc jamais
      // appliqué deux fois pour le même changement.
      if (previous.isNotEmpty) {
        final wasPaid = previous.first['status'] == 'payee';
        final isPaid = newRow['status'] == 'payee';
        if (wasPaid != isPaid) {
          final creditRows = await txn.query(
            _creditsTable,
            columns: ['account_id'],
            where: 'id = ?',
            whereArgs: [previous.first['credit_id']],
            limit: 1,
          );
          final accountId = creditRows.isEmpty ? null : creditRows.first['account_id'] as int?;
          if (accountId != null) {
            final cents = (previous.first['amount'] as num).round();
            await txn.rawUpdate(
              'UPDATE accounts SET current_balance = current_balance ${isPaid ? '-' : '+'} ?, '
              'updated_at = ? WHERE id = ?',
              [cents, DateTime.now().toIso8601String(), accountId],
            );
          }
        }
      }
      return rows;
    });
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
    return Money.fromCents((total as num).toInt());
  }
}
