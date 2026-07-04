import '../../domain/entities/budget.dart';

/// Modèle de données pour Budget : sait se convertir vers/depuis
/// le format Map utilisé par sqflite (lignes de la table SQLite).
class BudgetModel extends Budget {
  const BudgetModel({
    super.id,
    super.name,
    super.categoryId,
    required super.amount,
    required super.period,
    required super.startDate,
    super.currency,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Construit un BudgetModel à partir d'une ligne SQLite (Map).
  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      name: map['name'] as String?,
      categoryId: map['category_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      period: _periodFromString(map['period'] as String),
      startDate: DateTime.parse(map['start_date'] as String),
      currency: map['currency'] as String? ?? 'XOF',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convertit ce modèle en Map pour l'insertion/mise à jour SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category_id': categoryId,
      'amount': amount,
      'period': _periodToString(period),
      'start_date': startDate.toIso8601String(),
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crée un BudgetModel à partir d'une entité Budget (couche domain).
  factory BudgetModel.fromEntity(Budget budget) {
    return BudgetModel(
      id: budget.id,
      name: budget.name,
      categoryId: budget.categoryId,
      amount: budget.amount,
      period: budget.period,
      startDate: budget.startDate,
      currency: budget.currency,
      createdAt: budget.createdAt,
      updatedAt: budget.updatedAt,
    );
  }

  static BudgetPeriod _periodFromString(String value) {
    return BudgetPeriod.values.firstWhere(
      (p) => p.name == value,
      orElse: () => BudgetPeriod.mensuel,
    );
  }

  static String _periodToString(BudgetPeriod period) => period.name;
}
