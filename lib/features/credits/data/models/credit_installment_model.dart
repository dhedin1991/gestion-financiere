import '../../domain/entities/credit_installment.dart';

class CreditInstallmentModel extends CreditInstallment {
  const CreditInstallmentModel({
    super.id,
    required super.creditId,
    required super.dueDate,
    required super.amount,
    required super.status,
    super.paymentDate,
    required super.createdAt,
    required super.updatedAt,
  });

  static InstallmentStatus _statusFromString(String value) {
    switch (value) {
      case 'payee':
        return InstallmentStatus.payee;
      case 'en_retard':
        return InstallmentStatus.enRetard;
      case 'en_attente':
      default:
        return InstallmentStatus.enAttente;
    }
  }

  static String _statusToString(InstallmentStatus status) {
    switch (status) {
      case InstallmentStatus.payee:
        return 'payee';
      case InstallmentStatus.enRetard:
        return 'en_retard';
      case InstallmentStatus.enAttente:
        return 'en_attente';
    }
  }

  factory CreditInstallmentModel.fromMap(Map<String, dynamic> map) {
    return CreditInstallmentModel(
      id: map['id'] as int?,
      creditId: map['credit_id'] as int,
      dueDate: DateTime.parse(map['due_date'] as String),
      amount: (map['amount'] as num).toDouble(),
      status: _statusFromString(map['status'] as String),
      paymentDate: map['payment_date'] != null
          ? DateTime.parse(map['payment_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'credit_id': creditId,
      'due_date': dueDate.toIso8601String(),
      'amount': amount,
      'status': _statusToString(status),
      'payment_date': paymentDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CreditInstallmentModel.fromEntity(CreditInstallment installment) {
    return CreditInstallmentModel(
      id: installment.id,
      creditId: installment.creditId,
      dueDate: installment.dueDate,
      amount: installment.amount,
      status: installment.status,
      paymentDate: installment.paymentDate,
      createdAt: installment.createdAt,
      updatedAt: installment.updatedAt,
    );
  }
}
