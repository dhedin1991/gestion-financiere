/// Entité métier représentant une Épargne.
///
/// Une épargne est toujours rattachée à un compte (accountId) : chaque
/// versement diminue le solde de ce compte, chaque retrait l'augmente.
/// targetAmount et targetDate sont optionnels : une épargne "libre"
/// (sans objectif précis) a ces deux champs à null.
class Savings {
  final int? id;
  final String name;
  final int accountId;
  final double? targetAmount;
  final DateTime? targetDate;
  final double currentBalance;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Savings({
    this.id,
    required this.name,
    required this.accountId,
    this.targetAmount,
    this.targetDate,
    this.currentBalance = 0,
    this.currency = 'XOF',
    required this.createdAt,
    required this.updatedAt,
  });

  /// true si l'utilisateur a défini un objectif (montant cible).
  bool get hasTarget => targetAmount != null && targetAmount! > 0;

  /// Progression vers l'objectif, entre 0.0 et 1.0 (null si pas d'objectif).
  double? get progress {
    if (!hasTarget) return null;
    final p = currentBalance / targetAmount!;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  Savings copyWith({
    int? id,
    String? name,
    int? accountId,
    double? targetAmount,
    DateTime? targetDate,
    double? currentBalance,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Savings(
      id: id ?? this.id,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      currentBalance: currentBalance ?? this.currentBalance,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum SavingsTransactionType { versement, retrait }

/// Un mouvement (versement ou retrait) sur une épargne.
class SavingsTransaction {
  final int? id;
  final int savingsId;
  final SavingsTransactionType type;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const SavingsTransaction({
    this.id,
    required this.savingsId,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  /// Montant signé : positif pour un versement (fait grossir l'épargne),
  /// négatif pour un retrait.
  double get signedAmount => type == SavingsTransactionType.versement ? amount : -amount;
}
