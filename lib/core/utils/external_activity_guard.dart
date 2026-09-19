/// Signale que l'app ouvre volontairement une activité externe (sélecteur
/// de fichier, feuille de partage...).
///
/// Pendant ce temps, l'app passe en arrière-plan côté système, mais ce
/// n'est pas une vraie sortie de l'app : on ne doit donc pas la
/// reverrouiller au retour (sinon l'utilisateur retombe sur l'écran de
/// mot de passe au milieu d'un export ou d'une restauration).
class ExternalActivityGuard {
  ExternalActivityGuard._();

  static int _depth = 0;

  static bool get isActive => _depth > 0;

  static Future<T> run<T>(Future<T> Function() action) async {
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
    }
  }
}
