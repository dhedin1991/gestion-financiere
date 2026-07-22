import '../../../transactions/domain/entities/transaction.dart';

enum RecurrenceFrequency { hebdomadaire, mensuelle, annuelle }

/// Modèle d'une transaction qui se répète automatiquement (loyer,
/// salaire, abonnement...). L'app génère la vraie transaction quand
/// [nextDueDate] est atteinte, puis avance cette date selon [frequency].
class RecurringTransaction {
  final int? id;
  final int accountId;
  final int? categoryId;
  final TransactionType type;
  final double amount;
  final String currency;
  final String? description;
  final RecurrenceFrequency frequency;
  final DateTime nextDueDate;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringTransaction({
    this.id,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.amount,
    this.currency = 'XOF',
    this.description,
    required this.frequency,
    required this.nextDueDate,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calcule la prochaine échéance après celle-ci, selon la fréquence.
  DateTime computeNextDueDate() {
    switch (frequency) {
      case RecurrenceFrequency.hebdomadaire:
        return nextDueDate.add(const Duration(days: 7));
      case RecurrenceFrequency.mensuelle:
        return DateTime(nextDueDate.year, nextDueDate.month + 1, nextDueDate.day);
      case RecurrenceFrequency.annuelle:
        return DateTime(nextDueDate.year + 1, nextDueDate.month, nextDueDate.day);
    }
  }

  RecurringTransaction copyWith({
    int? id,
    int? accountId,
    int? categoryId,
    TransactionType? type,
    double? amount,
    String? currency,
    String? description,
    RecurrenceFrequency? frequency,
    DateTime? nextDueDate,
    bool? active,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
