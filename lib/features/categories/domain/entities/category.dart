enum CategoryType { revenu, depense }

class AppCategory {
  final int id;
  final String name;
  final CategoryType type;
  final int? parentId;
  final int? color;
  final String? icon;
  final bool isDefault;

  const AppCategory({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.color,
    this.icon,
    this.isDefault = false,
  });

  static CategoryType typeFromString(String value) =>
      value == 'revenu' ? CategoryType.revenu : CategoryType.depense;
}
