import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
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

    final label = transaction.description?.isNotEmpty == true
        ? transaction.description!
        : (categoryName ?? (isIncome ? 'Revenu' : 'Dépense'));

    return Semantics(
      label: '$label, ${isIncome ? 'crédit' : 'débit'} de ${formatter.format(transaction.amount)}, '
          '$accountName, le ${dateFormatter.format(transaction.transactionDate)}',
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$accountName · ${dateFormatter.format(transaction.transactionDate)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${formatter.format(transaction.amount)}',
            style: amountTextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ),
    );
  }
}
