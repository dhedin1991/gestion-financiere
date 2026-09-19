/// Devise « principale » : celle utilisée par le plus grand nombre de comptes
/// (à égalité, XOF prioritaire, puis ordre alphabétique).
///
/// Les totaux de l'app (solde global, revenus/dépenses du mois, bilans)
/// n'additionnent que cette devise : additionner des XOF et des EUR sans
/// conversion donnerait un chiffre faux. La règle est la même côté SQL
/// (voir BilanDao) et côté Dart.
String pickMainCurrency(Iterable<String> currencies) {
  final counts = <String, int>{};
  for (final c in currencies) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  if (counts.isEmpty) return 'XOF';
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      if (a.key == 'XOF') return -1;
      if (b.key == 'XOF') return 1;
      return a.key.compareTo(b.key);
    });
  return entries.first.key;
}
