enum CreditStatus {
  actif,
  solde,
}

class Credit {
  final int? id;
  final String name;
  final String? contractNumber;
  final double principalAmount;
  final double interestRate;
  final DateTime startDate;
  final int durationMonths;
  final double monthlyPayment;
  final int? accountId;
  final String currency;
  final CreditStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Credit({
    this.id,
    required this.name,
    this.contractNumber,
    required this.principalAmount,
    required this.interestRate,
    required this.startDate,
    required this.durationMonths,
    required this.monthlyPayment,
    this.accountId,
    required this.currency,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Credit copyWith({
    int? id,
    String? name,
    String? contractNumber,
    double? principalAmount,
    double? interestRate,
    DateTime? startDate,
    int? durationMonths,
    double? monthlyPayment,
    int? accountId,
    String? currency,
    CreditStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Credit(
      id: id ?? this.id,
      name: name ?? this.name,
      contractNumber: contractNumber ?? this.contractNumber,
      principalAmount: principalAmount ?? this.principalAmount,
      interestRate: interestRate ?? this.interestRate,
      startDate: startDate ?? this.startDate,
      durationMonths: durationMonths ?? this.durationMonths,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      accountId: accountId ?? this.accountId,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
