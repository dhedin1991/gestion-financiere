enum TransactionType { revenu, depense }

/// Entité pure représentant une transaction financière (revenu ou dépense).
class FinancialTransaction {
  final int? id;
  final int accountId;
  final int? categoryId;
  final TransactionType type;
  final double amount; // toujours positif ; le signe est déduit de `type`
  final String currency;
  final String? description;
  final String? paymentMethod;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialTransaction({
    this.id,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.amount,
    this.currency = 'XOF',
    this.description,
    this.paymentMethod,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Impact réel sur le solde du compte (négatif pour une dépense).
  double get signedAmount => type == TransactionType.depense ? -amount : amount;

  FinancialTransaction copyWith({
    int? id,
    int? accountId,
    int? categoryId,
    TransactionType? type,
    double? amount,
    String? currency,
    String? description,
    String? paymentMethod,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
