import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/transaction.dart';

class TransactionTile extends StatelessWidget {
  final FinancialTransaction transaction;
  final String accountName;
  final String? categoryName;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.accountName,
    this.categoryName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.revenu;
    final color = isIncome ? const Color(0xFF16A085) : const Color(0xFFE74C3C);
    final formatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: transaction.currency,
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd MMM yyyy', 'fr_FR');

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        transaction.description?.isNotEmpty == true
            ? transaction.description!
            : (categoryName ?? (isIncome ? 'Revenu' : 'Dépense')),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$accountName · ${dateFormatter.format(transaction.transactionDate)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'}${formatter.format(transaction.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
