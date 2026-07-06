enum InstallmentStatus {
  enAttente,
  payee,
  enRetard,
}

class CreditInstallment {
  final int? id;
  final int creditId;
  final DateTime dueDate;
  final double amount;
  final InstallmentStatus status;
  final DateTime? paymentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditInstallment({
    this.id,
    required this.creditId,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paymentDate,
    required this.createdAt,
    required this.updatedAt,
  });

  CreditInstallment copyWith({
    int? id,
    int? creditId,
    DateTime? dueDate,
    double? amount,
    InstallmentStatus? status,
    DateTime? paymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditInstallment(
      id: id ?? this.id,
      creditId: creditId ?? this.creditId,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
