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
      initialBalance: (map['initial_balance'] as num).toDouble(),
      currentBalance: (map['current_balance'] as num).toDouble(),
      color: map['color'] as int?,
      icon: map['icon'] as String?,
      isArchived: (map['is_archived'] as int) == 1,
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
      'initial_balance': account.initialBalance,
      'current_balance': account.currentBalance,
      'color': account.color,
      'icon': account.icon,
      'is_archived': account.isArchived ? 1 : 0,
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
