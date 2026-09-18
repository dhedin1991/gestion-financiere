import '../../../../core/utils/money.dart';
import '../../domain/entities/net_worth_snapshot.dart';

class NetWorthSnapshotModel extends NetWorthSnapshot {
  const NetWorthSnapshotModel({
    super.id,
    required super.snapshotDate,
    required super.totalAccounts,
    required super.totalSavings,
    required super.totalPatrimoine,
    required super.totalReceivables,
    required super.totalDebts,
    required super.totalCreditsRemaining,
    required super.netWorth,
    required super.createdAt,
  });

  factory NetWorthSnapshotModel.fromMap(Map<String, dynamic> map) {
    return NetWorthSnapshotModel(
      id: map['id'] as int?,
      snapshotDate: DateTime.parse(map['snapshot_date'] as String),
      totalAccounts: Money.fromCents((map['total_accounts'] as num).toInt()),
      totalSavings: Money.fromCents((map['total_savings'] as num).toInt()),
      totalPatrimoine: Money.fromCents((map['total_patrimoine'] as num).toInt()),
      totalReceivables: Money.fromCents((map['total_receivables'] as num).toInt()),
      totalDebts: Money.fromCents((map['total_debts'] as num).toInt()),
      totalCreditsRemaining: Money.fromCents((map['total_credits_remaining'] as num).toInt()),
      netWorth: Money.fromCents((map['net_worth'] as num).toInt()),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'snapshot_date': snapshotDate.toIso8601String().split('T').first,
      'total_accounts': Money.toCents(totalAccounts),
      'total_savings': Money.toCents(totalSavings),
      'total_patrimoine': Money.toCents(totalPatrimoine),
      'total_receivables': Money.toCents(totalReceivables),
      'total_debts': Money.toCents(totalDebts),
      'total_credits_remaining': Money.toCents(totalCreditsRemaining),
      'net_worth': Money.toCents(netWorth),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
