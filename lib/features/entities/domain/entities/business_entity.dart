enum BusinessEntityType { personnel, professionnel }

/// Une "entité" au sens comptable : un dossier séparé (Personnel, ou une
/// société) dans lequel comptes/transactions/etc. sont regroupés. Un
/// seul utilisateur (toi) navigue entre plusieurs entités — ce n'est pas
/// un système multi-utilisateurs.
class BusinessEntity {
  final int? id;
  final String name;
  final BusinessEntityType type;
  final DateTime createdAt;

  const BusinessEntity({
    this.id,
    required this.name,
    required this.type,
    required this.createdAt,
  });
}
