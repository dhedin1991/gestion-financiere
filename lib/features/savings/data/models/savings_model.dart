import '../../domain/entities/savings.dart';

/// Conversion entre l'entité métier Savings et la ligne SQLite (Map).
class SavingsModel {
  static Savings fromMap(Map<String, dynamic> map) {
    return Savings(
      id: map['id'] as int,
      name: map['name'] as String,
      accountId: map['account_id'] as int,
      targetAmount: map['target_amount'] == null ? null : (map['target_amount'] as num).toDouble(),
      targetDate: map['target_date'] == null ? null : DateTime.parse(map['target_date'] as String),
      currentBalance: (map['current_balance'] as num).toDouble(),
      currency: map['currency'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(Savings savings) {
    return {
      if (savings.id != null) 'id': savings.id,
      'name': savings.name,
      'account_id': savings.accountId,
      'target_amount': savings.targetAmount,
      'target_date': savings.targetDate?.toIso8601String(),
      'current_balance': savings.currentBalance,
      'currency': savings.currency,
      'created_at': savings.createdAt.toIso8601String(),
      'updated_at': savings.updatedAt.toIso8601String(),
    };
  }
}

/// Conversion entre SavingsTransaction et la ligne SQLite (Map).
class SavingsTransactionModel {
  static SavingsTransaction fromMap(Map<String, dynamic> map) {
    return SavingsTransaction(
      id: map['id'] as int,
      savingsId: map['savings_id'] as int,
      type: (map['type'] as String) == 'versement'
          ? SavingsTransactionType.versement
          : SavingsTransactionType.retrait,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(SavingsTransaction transaction) {
    return {
      if (transaction.id != null) 'id': transaction.id,
      'savings_id': transaction.savingsId,
      'type': transaction.type == SavingsTransactionType.versement ? 'versement' : 'retrait',
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'note': transaction.note,
      'created_at': transaction.createdAt.toIso8601String(),
    };
  }
}
