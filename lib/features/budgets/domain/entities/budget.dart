/// Période sur laquelle un budget s'applique.
enum BudgetPeriod {
  hebdomadaire,
  mensuel,
  annuel,
}

/// Représente un budget : soit global (toutes catégories confondues),
/// soit lié à une catégorie précise (categoryId non nul).
class Budget {
  final int? id;
  final String? name;
  final int? categoryId;
  final double amount;
  final BudgetPeriod period;
  final DateTime startDate;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    this.id,
    this.name,
    this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    this.currency = 'XOF',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Un budget est "global" quand il ne cible aucune catégorie précise.
  bool get isGlobal => categoryId == null;

  Budget copyWith({
    int? id,
    String? name,
    int? categoryId,
    double? amount,
    BudgetPeriod? period,
    DateTime? startDate,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
