import '../../domain/entities/debt.dart';

/// Convertit Debt <-> Map SQLite.
/// Le paidAmount n'est jamais stocké : il est recalculé côté Repository
/// à partir des DebtPayment liés.
class DebtModel {
  static Debt fromMap(Map<String, dynamic> map, {double paidAmount = 0}) {
    return Debt(
      id: map['id'] as int?,
      type: (map['type'] as String) == 'creance' ? DebtType.creance : DebtType.dette,
      personName: map['person_name'] as String,
      description: map['description'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'XOF',
      accountId: map['account_id'] as int?,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      paidAmount: paidAmount,
    );
  }

  static Map<String, dynamic> toMap(Debt debt) {
    return {
      if (debt.id != null) 'id': debt.id,
      'type': debt.type == DebtType.creance ? 'creance' : 'dette',
      'person_name': debt.personName,
      'description': debt.description,
      'total_amount': debt.totalAmount,
      'currency': debt.currency,
      'account_id': debt.accountId,
      'due_date': debt.dueDate?.toIso8601String(),
      'created_at': debt.createdAt.toIso8601String(),
      'updated_at': debt.updatedAt.toIso8601String(),
    };
  }
}

class DebtPaymentModel {
  static DebtPayment fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'] as int?,
      debtId: map['debt_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(DebtPayment payment) {
    return {
      if (payment.id != null) 'id': payment.id,
      'debt_id': payment.debtId,
      'amount': payment.amount,
      'payment_date': payment.paymentDate.toIso8601String(),
      'note': payment.note,
      'created_at': payment.createdAt.toIso8601String(),
    };
  }
}
