enum DebtType { dette, creance }

class Debt {
  final int? id;
  final DebtType type;
  final String personName;
  final String? description;
  final double totalAmount;
  final String currency;
  final int? accountId;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double paidAmount; // calculé, pas stocké en base

  const Debt({
    this.id,
    required this.type,
    required this.personName,
    this.description,
    required this.totalAmount,
    this.currency = 'XOF',
    this.accountId,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.paidAmount = 0,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isSettled => remainingAmount <= 0.0001;

  Debt copyWith({
    int? id,
    DebtType? type,
    String? personName,
    String? description,
    double? totalAmount,
    String? currency,
    int? accountId,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? paidAmount,
  }) {
    return Debt(
      id: id ?? this.id,
      type: type ?? this.type,
      personName: personName ?? this.personName,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}

class DebtPayment {
  final int? id;
  final int debtId;
  final double amount;
  final DateTime paymentDate;
  final String? note;
  final DateTime createdAt;

  const DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    this.note,
    required this.createdAt,
  });
}
