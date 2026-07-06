enum PatrimoineCategory {
  immobilier,
  vehicule,
  materiel,
  autre,
}

class PatrimoineItem {
  final int? id;
  final String nom;
  final PatrimoineCategory categorie;
  final double valeurEstimee;
  final String devise;
  final DateTime? dateAcquisition;
  final String? description;
  final String? localisation;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PatrimoineItem({
    this.id,
    required this.nom,
    required this.categorie,
    required this.valeurEstimee,
    required this.devise,
    this.dateAcquisition,
    this.description,
    this.localisation,
    required this.createdAt,
    required this.updatedAt,
  });

  PatrimoineItem copyWith({
    int? id,
    String? nom,
    PatrimoineCategory? categorie,
    double? valeurEstimee,
    String? devise,
    DateTime? dateAcquisition,
    String? description,
    String? localisation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatrimoineItem(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      categorie: categorie ?? this.categorie,
      valeurEstimee: valeurEstimee ?? this.valeurEstimee,
      devise: devise ?? this.devise,
      dateAcquisition: dateAcquisition ?? this.dateAcquisition,
      description: description ?? this.description,
      localisation: localisation ?? this.localisation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
