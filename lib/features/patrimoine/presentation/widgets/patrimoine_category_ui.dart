import 'package:flutter/material.dart';

import '../../../../core/widgets/classeur.dart';
import '../../domain/entities/patrimoine_item.dart';

/// Libellé, icône et couleur de chaque catégorie du classeur de patrimoine.
extension PatrimoineCategoryUi on PatrimoineCategory {
  String get label {
    switch (this) {
      case PatrimoineCategory.immobilier:
        return 'Immobilier';
      case PatrimoineCategory.terrain:
        return 'Terrains';
      case PatrimoineCategory.vehicule:
        return 'Véhicules';
      case PatrimoineCategory.materiel:
        return 'Matériel professionnel';
      case PatrimoineCategory.electronique:
        return 'Électronique';
      case PatrimoineCategory.mobilier:
        return 'Mobilier';
      case PatrimoineCategory.bijoux:
        return 'Bijoux et objets de valeur';
      case PatrimoineCategory.placement:
        return 'Placements';
      case PatrimoineCategory.entreprise:
        return 'Parts d\'entreprise';
      case PatrimoineCategory.autre:
        return 'Autres biens';
    }
  }

  IconData get icon {
    switch (this) {
      case PatrimoineCategory.immobilier:
        return Icons.home_outlined;
      case PatrimoineCategory.terrain:
        return Icons.landscape_outlined;
      case PatrimoineCategory.vehicule:
        return Icons.directions_car_outlined;
      case PatrimoineCategory.materiel:
        return Icons.construction_outlined;
      case PatrimoineCategory.electronique:
        return Icons.devices_other_outlined;
      case PatrimoineCategory.mobilier:
        return Icons.chair_outlined;
      case PatrimoineCategory.bijoux:
        return Icons.diamond_outlined;
      case PatrimoineCategory.placement:
        return Icons.trending_up;
      case PatrimoineCategory.entreprise:
        return Icons.business_center_outlined;
      case PatrimoineCategory.autre:
        return Icons.category_outlined;
    }
  }

  Color get color {
    switch (this) {
      case PatrimoineCategory.immobilier:
        return const Color(0xFF4C8DFF);
      case PatrimoineCategory.terrain:
        return const Color(0xFF65A30D);
      case PatrimoineCategory.vehicule:
        return const Color(0xFFF59E0B);
      case PatrimoineCategory.materiel:
        return const Color(0xFF78716C);
      case PatrimoineCategory.electronique:
        return const Color(0xFF06B6D4);
      case PatrimoineCategory.mobilier:
        return const Color(0xFFA16207);
      case PatrimoineCategory.bijoux:
        return const Color(0xFFD946EF);
      case PatrimoineCategory.placement:
        return const Color(0xFF2EBD85);
      case PatrimoineCategory.entreprise:
        return const Color(0xFF8E7CF0);
      case PatrimoineCategory.autre:
        return const Color(0xFF94A3B8);
    }
  }

  ClasseurCategory get classeur => ClasseurCategory(name, label, icon, color);
}

/// Toutes les catégories, dans l'ordre du classeur.
final List<ClasseurCategory> kPatrimoineClasseur = [for (final c in PatrimoineCategory.values) c.classeur];
