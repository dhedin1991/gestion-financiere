import '../../../../core/utils/money.dart';
import '../../domain/entities/account.dart';

/// Modèle "brut" qui sait se convertir en Map SQLite et inversement.
///
/// Sépare volontairement l'entité métier (Account) du format de stockage :
/// si demain on change de moteur (drift, Cloud...), seul ce Mapper change.
class AccountModel {
  static Account fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      bankName: map['bank_name'] as String?,
      type: _typeFromString(map['account_type'] as String),
      currency: map['currency'] as String? ?? 'XOF',
      initialBalance: Money.fromCents((map['initial_balance'] as num).toInt()),
      currentBalance: Money.fromCents((map['current_balance'] as num).toInt()),
      color: map['color'] as int?,
      icon: map['icon'] as String?,
      isArchived: (map['is_archived'] as int) == 1,
      entityId: map['entity_id'] as int?,
      role: map['role'] as String?,
      alertWarning: map['alert_warning'] == null ? null : Money.fromCents((map['alert_warning'] as num).toInt()),
      alertCritical: map['alert_critical'] == null ? null : Money.fromCents((map['alert_critical'] as num).toInt()),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(Account account) {
    return {
      if (account.id != null) 'id': account.id,
      'name': account.name,
      'bank_name': account.bankName,
      'account_type': account.type.name,
      'currency': account.currency,
      'initial_balance': Money.toCents(account.initialBalance),
      'current_balance': Money.toCents(account.currentBalance),
      'color': account.color,
      'icon': account.icon,
      'is_archived': account.isArchived ? 1 : 0,
      'entity_id': account.entityId,
      'role': account.role,
      'alert_warning': account.alertWarning == null ? null : Money.toCents(account.alertWarning!),
      'alert_critical': account.alertCritical == null ? null : Money.toCents(account.alertCritical!),
      'created_at': account.createdAt.toIso8601String(),
      'updated_at': account.updatedAt.toIso8601String(),
    };
  }

  static AccountType _typeFromString(String value) {
    return AccountType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => AccountType.autre,
    );
  }
}
