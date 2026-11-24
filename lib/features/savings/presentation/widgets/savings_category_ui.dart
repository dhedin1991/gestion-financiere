import 'package:flutter/material.dart';

import '../../../../core/widgets/classeur.dart';
import '../../domain/entities/savings.dart';

/// Libellé, icône et couleur de chaque catégorie d'épargne.
extension SavingsCategoryUi on SavingsCategory {
  String get label {
    switch (this) {
      case SavingsCategory.urgence:
        return 'Fonds d\'urgence';
      case SavingsCategory.projet:
        return 'Projets';
      case SavingsCategory.voyage:
        return 'Voyages';
      case SavingsCategory.immobilier:
        return 'Achat immobilier';
      case SavingsCategory.education:
        return 'Études et formation';
      case SavingsCategory.vehicule:
        return 'Véhicule';
      case SavingsCategory.evenement:
        return 'Fêtes et événements';
      case SavingsCategory.retraite:
        return 'Retraite';
      case SavingsCategory.sante:
        return 'Santé';
      case SavingsCategory.libre:
        return 'Épargne libre';
    }
  }

  IconData get icon {
    switch (this) {
      case SavingsCategory.urgence:
        return Icons.health_and_safety_outlined;
      case SavingsCategory.projet:
        return Icons.flag_outlined;
      case SavingsCategory.voyage:
        return Icons.flight_takeoff;
      case SavingsCategory.immobilier:
        return Icons.home_outlined;
      case SavingsCategory.education:
        return Icons.school_outlined;
      case SavingsCategory.vehicule:
        return Icons.directions_car_outlined;
      case SavingsCategory.evenement:
        return Icons.celebration_outlined;
      case SavingsCategory.retraite:
        return Icons.beach_access_outlined;
      case SavingsCategory.sante:
        return Icons.favorite_border;
      case SavingsCategory.libre:
        return Icons.savings_outlined;
    }
  }

  Color get color {
    switch (this) {
      case SavingsCategory.urgence:
        return const Color(0xFFF43F5E);
      case SavingsCategory.projet:
        return const Color(0xFF4C8DFF);
      case SavingsCategory.voyage:
        return const Color(0xFF06B6D4);
      case SavingsCategory.immobilier:
        return const Color(0xFF8E7CF0);
      case SavingsCategory.education:
        return const Color(0xFFF59E0B);
      case SavingsCategory.vehicule:
        return const Color(0xFF78716C);
      case SavingsCategory.evenement:
        return const Color(0xFFD946EF);
      case SavingsCategory.retraite:
        return const Color(0xFF65A30D);
      case SavingsCategory.sante:
        return const Color(0xFFEC4899);
      case SavingsCategory.libre:
        return const Color(0xFF2EBD85);
    }
  }

  ClasseurCategory get classeur => ClasseurCategory(name, label, icon, color);
}

/// Toutes les catégories, dans l'ordre du classeur (« libre » en dernier).
final List<ClasseurCategory> kSavingsClasseur = [for (final c in SavingsCategory.values) c.classeur];
