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
      totalAccounts: (map['total_accounts'] as num).toDouble(),
      totalSavings: (map['total_savings'] as num).toDouble(),
      totalPatrimoine: (map['total_patrimoine'] as num).toDouble(),
      totalReceivables: (map['total_receivables'] as num).toDouble(),
      totalDebts: (map['total_debts'] as num).toDouble(),
      totalCreditsRemaining: (map['total_credits_remaining'] as num).toDouble(),
      netWorth: (map['net_worth'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'snapshot_date': snapshotDate.toIso8601String().split('T').first,
      'total_accounts': totalAccounts,
      'total_savings': totalSavings,
      'total_patrimoine': totalPatrimoine,
      'total_receivables': totalReceivables,
      'total_debts': totalDebts,
      'total_credits_remaining': totalCreditsRemaining,
      'net_worth': netWorth,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
