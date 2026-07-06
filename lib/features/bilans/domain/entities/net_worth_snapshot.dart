class NetWorthSnapshot {
  final int? id;
  final DateTime snapshotDate;
  final double totalAccounts;
  final double totalSavings;
  final double totalPatrimoine;
  final double totalReceivables;
  final double totalDebts;
  final double totalCreditsRemaining;
  final double netWorth;
  final DateTime createdAt;

  const NetWorthSnapshot({
    this.id,
    required this.snapshotDate,
    required this.totalAccounts,
    required this.totalSavings,
    required this.totalPatrimoine,
    required this.totalReceivables,
    required this.totalDebts,
    required this.totalCreditsRemaining,
    required this.netWorth,
    required this.createdAt,
  });
}
