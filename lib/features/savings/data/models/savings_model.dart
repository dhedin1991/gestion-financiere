import '../../../../core/utils/money.dart';
import '../../domain/entities/savings.dart';

/// Conversion entre l'entité métier Savings et la ligne SQLite (Map).
class SavingsModel {
  static Savings fromMap(Map<String, dynamic> map) {
    return Savings(
      id: map['id'] as int,
      name: map['name'] as String,
      accountId: map['account_id'] as int,
      targetAmount: Money.fromCentsOrNull(map['target_amount'] == null ? null : (map['target_amount'] as num).toInt()),
      targetDate: map['target_date'] == null ? null : DateTime.parse(map['target_date'] as String),
      currentBalance: Money.fromCents((map['current_balance'] as num).toInt()),
      currency: map['currency'] as String,
      category: SavingsCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => SavingsCategory.libre,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(Savings savings) {
    return {
      if (savings.id != null) 'id': savings.id,
      'name': savings.name,
      'account_id': savings.accountId,
      'target_amount': Money.toCentsOrNull(savings.targetAmount),
      'target_date': savings.targetDate?.toIso8601String(),
      'current_balance': Money.toCents(savings.currentBalance),
      'currency': savings.currency,
      'category': savings.category.name,
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
      amount: Money.fromCents((map['amount'] as num).toInt()),
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
      'amount': Money.toCents(transaction.amount),
      'date': transaction.date.toIso8601String(),
      'note': transaction.note,
      'created_at': transaction.createdAt.toIso8601String(),
    };
  }
}
