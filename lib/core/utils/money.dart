/// Utilitaires pour manipuler des montants monétaires.
///
/// Depuis la migration de schéma v13, les montants sont stockés en base
/// sous forme d'**entiers (centimes)** plutôt qu'en flottant (`REAL`) :
/// c'est la correction définitive du problème de dérive d'arrondi identifié
/// à l'audit (0.1 + 0.2 != 0.3 en IEEE-754). Un entier ne souffre d'aucune
/// imprécision, quel que soit le nombre d'opérations cumulées.
///
/// Toute la couche `data/models` convertit :
///   - à l'écriture (`toMap`) : unités → centimes via [toCents] ;
///   - à la lecture (`fromMap`) : centimes → unités via [fromCents].
/// Le reste de l'application (domaine, UI, calculs) continue de manipuler
/// des `double` en unités normales (ex: 1500.0 XOF) — seule la couche de
/// persistance connaît l'existence des centimes.
class Money {
  Money._();

  /// Convertit un montant en unités (ex: 1500.5) en centimes entiers
  /// (150050), pour le stockage en base.
  static int toCents(double amount) => (amount * 100).round();

  /// Convertit des centimes entiers stockés en base en montant en unités.
  static double fromCents(int cents) => cents / 100.0;

  /// Comme [toCents], mais accepte une valeur potentiellement nulle
  /// (pratique pour les champs optionnels type `montant_cible`).
  static int? toCentsOrNull(double? amount) {
    if (amount == null) return null;
    return toCents(amount);
  }

  /// Comme [fromCents], mais accepte une valeur potentiellement nulle.
  static double? fromCentsOrNull(int? cents) {
    if (cents == null) return null;
    return fromCents(cents);
  }

  /// Arrondit un montant à 2 décimales (centimes). Conservé pour les
  /// calculs intermédiaires en mémoire (ex: intérêts, répartitions) où
  /// on manipule encore des `double` avant conversion en centimes.
  static double round(double amount) {
    return double.parse(amount.toStringAsFixed(2));
  }

  /// Comme [round], mais accepte une valeur potentiellement nulle.
  static double? roundOrNull(double? amount) {
    if (amount == null) return null;
    return round(amount);
  }

  /// Compare deux montants en tenant compte d'une tolérance d'arrondi,
  /// pour éviter les faux positifs du type `0.1 + 0.2 == 0.3 -> false`.
  static bool equals(double a, double b, {double epsilon = 0.005}) {
    return (a - b).abs() < epsilon;
  }
}
