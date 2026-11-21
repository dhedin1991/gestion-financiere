import '../../../../core/utils/money.dart';
import '../../domain/entities/transaction.dart';

class TransactionModel {
  static FinancialTransaction fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int?,
      type: (map['type'] as String) == 'revenu' ? TransactionType.revenu : TransactionType.depense,
      amount: Money.fromCents((map['amount'] as num).toInt()),
      currency: map['currency'] as String? ?? 'XOF',
      description: map['description'] as String?,
      paymentMethod: map['payment_method'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      transferGroup: (map['transfer_group'] as num?)?.toInt(),
      kind: map['kind'] as String?,
      refId: (map['ref_id'] as num?)?.toInt(),
    );
  }

  static Map<String, dynamic> toMap(FinancialTransaction t) {
    return {
      if (t.id != null) 'id': t.id,
      'account_id': t.accountId,
      'category_id': t.categoryId,
      'type': t.type == TransactionType.revenu ? 'revenu' : 'depense',
      'amount': Money.toCents(t.amount),
      'currency': t.currency,
      'description': t.description,
      'payment_method': t.paymentMethod,
      'transaction_date': t.transactionDate.toIso8601String(),
      'created_at': t.createdAt.toIso8601String(),
      'updated_at': t.updatedAt.toIso8601String(),
      'transfer_group': t.transferGroup,
      'kind': t.kind,
      'ref_id': t.refId,
    };
  }
}
