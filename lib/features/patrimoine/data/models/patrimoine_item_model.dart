import '../../domain/entities/patrimoine_item.dart';

class PatrimoineItemModel extends PatrimoineItem {
  const PatrimoineItemModel({
    super.id,
    required super.nom,
    required super.categorie,
    required super.valeurEstimee,
    required super.devise,
    required super.dateAcquisition,
    super.description,
    super.localisation,
  });

  factory PatrimoineItemModel.fromMap(Map<String, dynamic> map) {
    return PatrimoineItemModel(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      categorie: PatrimoineCategory.values.firstWhere(
        (e) => e.name == map['categorie'],
        orElse: () => PatrimoineCategory.autre,
      ),
      valeurEstimee: (map['valeur_estimee'] as num).toDouble(),
      devise: map['devise'] as String,
      dateAcquisition: DateTime.parse(map['date_acquisition'] as String),
      description: map['description'] as String?,
      localisation: map['localisation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'categorie': categorie.name,
      'valeur_estimee': valeurEstimee,
      'devise': devise,
      'date_acquisition': dateAcquisition.toIso8601String(),
      'description': description,
      'localisation': localisation,
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
    );
  }
}
