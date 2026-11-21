import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../../../core/utils/app_format.dart';

String frequencyLabel(RecurrenceFrequency f) {
  switch (f) {
    case RecurrenceFrequency.hebdomadaire:
      return 'Chaque semaine';
    case RecurrenceFrequency.mensuelle:
      return 'Chaque mois';
    case RecurrenceFrequency.annuelle:
      return 'Chaque année';
  }
}

class RecurringTile extends StatelessWidget {
  final RecurringTransaction recurring;
  final String accountName;
  final VoidCallback? onTap;

  const RecurringTile({
    super.key,
    required this.recurring,
    required this.accountName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = recurring.type == TransactionType.revenu;
    final color = isIncome ? Colors.green : Colors.red;
    final formatter = AppFormat.currency(symbol: recurring.currency);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Opacity(
      opacity: recurring.active ? 1 : 0.5,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.autorenew, color: color, size: 20),
        ),
        title: Text(recurring.description?.isNotEmpty == true ? recurring.description! : accountName),
        subtitle: Text(
          '${frequencyLabel(recurring.frequency)} — prochaine le ${dateFmt.format(recurring.nextDueDate)}'
          '${recurring.active ? '' : ' (en pause)'}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${formatter.format(recurring.amount)}',
          style: amountTextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
