import '../../domain/entities/credit.dart';

class CreditModel extends Credit {
  const CreditModel({
    super.id,
    required super.name,
    super.contractNumber,
    required super.principalAmount,
    required super.interestRate,
    required super.startDate,
    required super.durationMonths,
    required super.monthlyPayment,
    super.accountId,
    required super.currency,
    required super.status,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  static CreditStatus _statusFromString(String value) {
    switch (value) {
      case 'solde':
        return CreditStatus.solde;
      case 'actif':
      default:
        return CreditStatus.actif;
    }
  }

  static String _statusToString(CreditStatus status) {
    switch (status) {
      case CreditStatus.solde:
        return 'solde';
      case CreditStatus.actif:
        return 'actif';
    }
  }

  factory CreditModel.fromMap(Map<String, dynamic> map) {
    return CreditModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      contractNumber: map['contract_number'] as String?,
      principalAmount: (map['principal_amount'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      durationMonths: map['duration_months'] as int,
      monthlyPayment: (map['monthly_payment'] as num).toDouble(),
      accountId: map['account_id'] as int?,
      currency: map['currency'] as String,
      status: _statusFromString(map['status'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'contract_number': contractNumber,
      'principal_amount': principalAmount,
      'interest_rate': interestRate,
      'start_date': startDate.toIso8601String(),
      'duration_months': durationMonths,
      'monthly_payment': monthlyPayment,
      'account_id': accountId,
      'currency': currency,
      'status': _statusToString(status),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CreditModel.fromEntity(Credit credit) {
    return CreditModel(
      id: credit.id,
      name: credit.name,
      contractNumber: credit.contractNumber,
      principalAmount: credit.principalAmount,
      interestRate: credit.interestRate,
      startDate: credit.startDate,
      durationMonths: credit.durationMonths,
      monthlyPayment: credit.monthlyPayment,
      accountId: credit.accountId,
      currency: credit.currency,
      status: credit.status,
      notes: credit.notes,
      createdAt: credit.createdAt,
      updatedAt: credit.updatedAt,
    );
  }
}
