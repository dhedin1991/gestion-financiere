import '../../../transactions/domain/entities/transaction.dart';
import '../../../../core/utils/month_math.dart';

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

  /// Jour du mois voulu à l'origine (ex. 31). Permet de retrouver le 31
  /// après un mois court (28 février) au lieu de rester bloqué sur le 28.
  final int? anchorDay;
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
    this.anchorDay,
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
        return addMonthsClamped(nextDueDate, 1, anchorDay: anchorDay);
      case RecurrenceFrequency.annuelle:
        return addMonthsClamped(nextDueDate, 12, anchorDay: anchorDay);
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
    int? anchorDay,
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
      anchorDay: anchorDay ?? this.anchorDay,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
