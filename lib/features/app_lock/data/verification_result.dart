/// Résultat d'une tentative de vérification (mot de passe ou code de
/// récupération), avec l'information nécessaire pour afficher un message
/// utile à l'utilisateur en cas d'échec ou de verrouillage temporaire.
class VerificationResult {
  final bool success;

  /// Vrai si l'appareil est actuellement verrouillé suite à trop
  /// d'échecs (indépendamment du résultat de cette tentative précise,
  /// qui n'a alors même pas été évaluée).
  final bool lockedOut;

  /// Secondes restantes avant de pouvoir retenter, si [lockedOut].
  final int lockoutRemainingSeconds;

  const VerificationResult({
    required this.success,
    this.lockedOut = false,
    this.lockoutRemainingSeconds = 0,
  });

  static const ok = VerificationResult(success: true);
  static const failed = VerificationResult(success: false);

  factory VerificationResult.lockout(int seconds) => VerificationResult(
        success: false,
        lockedOut: true,
        lockoutRemainingSeconds: seconds,
      );
}
