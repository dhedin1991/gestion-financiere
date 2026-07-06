import '../../domain/entities/patrimoine_item.dart';

class PatrimoineItemModel extends PatrimoineItem {
  const PatrimoineItemModel({
    super.id,
    required super.nom,
    required super.categorie,
    required super.valeurEstimee,
    required super.devise,
    super.dateAcquisition,
    super.description,
    super.localisation,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PatrimoineItemModel.fromMap(Map<String, dynamic> map) {
    return PatrimoineItemModel(
      id: map['id'] as int?,
      nom: map['name'] as String,
      categorie: PatrimoineCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => PatrimoineCategory.autre,
      ),
      valeurEstimee: (map['estimated_value'] as num).toDouble(),
      devise: map['currency'] as String,
      dateAcquisition: map['acquisition_date'] != null
          ? DateTime.parse(map['acquisition_date'] as String)
          : null,
      description: map['description'] as String?,
      localisation: map['location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': nom,
      'category': categorie.name,
      'estimated_value': valeurEstimee,
      'currency': devise,
      'acquisition_date': dateAcquisition?.toIso8601String(),
      'description': description,
      'location': localisation,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PatrimoineItemModel.fromEntity(PatrimoineItem item) {
    return PatrimoineItemModel(
      id: item.id,
      nom: item.nom,
      categorie: item.categorie,
      valeurEstimee: item.valeurEstimee,
      devise: item.devise,
      dateAcquisition: item.dateAcquisition,
      description: item.description,
      localisation: item.localisation,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}
