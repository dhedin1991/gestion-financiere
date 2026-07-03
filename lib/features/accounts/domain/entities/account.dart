/// Types de comptes personnalisables (l'utilisateur peut en créer d'autres
/// via les paramètres de personnalisation prévus au cahier des charges).
enum AccountType { courant, epargne, mobileMoney, especes, autre }

/// Entité métier "Compte".
///
/// IMPORTANT (Clean Architecture) : cette classe ne connaît RIEN de SQLite,
/// ni de Flutter. C'est un objet Dart pur. C'est ce qui permet de tester
/// le métier sans base de données, et de changer de moteur de stockage
/// plus tard sans toucher au Domain.
class Account {
  final int? id;
  final String name;
  final String? bankName;
  final AccountType type;
  final String currency; // XOF, EUR, USD, NGN, GHS...
  final double initialBalance;
  final double currentBalance;
  final int? color;
  final String? icon;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    this.id,
    required this.name,
    this.bankName,
    required this.type,
    this.currency = 'XOF',
    required this.initialBalance,
    required this.currentBalance,
    this.color,
    this.icon,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Account copyWith({
    int? id,
    String? name,
    String? bankName,
    AccountType? type,
    String? currency,
    double? initialBalance,
    double? currentBalance,
    int? color,
    String? icon,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
