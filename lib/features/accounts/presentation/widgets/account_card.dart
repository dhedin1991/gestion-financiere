import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/account.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;

  const AccountCard({super.key, required this.account, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: account.currency,
      decimalDigits: 0,
    );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(_iconFor(account.type), color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: theme.textTheme.titleMedium),
                    if (account.bankName != null)
                      Text(
                        account.bankName!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              Text(
                formatter.format(account.currentBalance),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AccountType type) {
    switch (type) {
      case AccountType.courant:
        return Icons.account_balance;
      case AccountType.epargne:
        return Icons.savings;
      case AccountType.mobileMoney:
        return Icons.phone_iphone;
      case AccountType.especes:
        return Icons.payments;
      case AccountType.autre:
        return Icons.wallet;
    }
  }
}
