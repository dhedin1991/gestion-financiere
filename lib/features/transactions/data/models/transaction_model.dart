import '../../domain/entities/transaction.dart';

class TransactionModel {
  static FinancialTransaction fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int?,
      type: (map['type'] as String) == 'revenu' ? TransactionType.revenu : TransactionType.depense,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'XOF',
      description: map['description'] as String?,
      paymentMethod: map['payment_method'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(FinancialTransaction t) {
    return {
      if (t.id != null) 'id': t.id,
      'account_id': t.accountId,
      'category_id': t.categoryId,
      'type': t.type == TransactionType.revenu ? 'revenu' : 'depense',
      'amount': t.amount,
      'currency': t.currency,
      'description': t.description,
      'payment_method': t.paymentMethod,
      'transaction_date': t.transactionDate.toIso8601String(),
      'created_at': t.createdAt.toIso8601String(),
      'updated_at': t.updatedAt.toIso8601String(),
    };
  }
}
