import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/recurring_transaction.dart';

class RecurringTransactionModel {
  static RecurrenceFrequency _frequencyFromString(String value) {
    switch (value) {
      case 'hebdomadaire':
        return RecurrenceFrequency.hebdomadaire;
      case 'annuelle':
        return RecurrenceFrequency.annuelle;
      case 'mensuelle':
      default:
        return RecurrenceFrequency.mensuelle;
    }
  }

  static String _frequencyToString(RecurrenceFrequency f) => f.name;

  static RecurringTransaction fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int?,
      type: (map['type'] as String) == 'revenu' ? TransactionType.revenu : TransactionType.depense,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'XOF',
      description: map['description'] as String?,
      frequency: _frequencyFromString(map['frequency'] as String),
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      active: (map['active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(RecurringTransaction r) {
    return {
      if (r.id != null) 'id': r.id,
      'account_id': r.accountId,
      'category_id': r.categoryId,
      'type': r.type == TransactionType.revenu ? 'revenu' : 'depense',
      'amount': r.amount,
      'currency': r.currency,
      'description': r.description,
      'frequency': _frequencyToString(r.frequency),
      'next_due_date': r.nextDueDate.toIso8601String(),
      'active': r.active ? 1 : 0,
      'created_at': r.createdAt.toIso8601String(),
      'updated_at': r.updatedAt.toIso8601String(),
    };
  }
}
