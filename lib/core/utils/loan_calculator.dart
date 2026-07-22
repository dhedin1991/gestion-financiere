import 'dart:math' as math;

/// Calcule la mensualité théorique d'un crédit à taux fixe, selon la
/// formule d'amortissement bancaire classique :
///
///   PMT = P × r / (1 − (1 + r)^−n)
///
/// où P = capital emprunté, r = taux mensuel, n = nombre de mensualités.
/// Cas particulier r = 0 : la mensualité est simplement P / n (pas
/// d'intérêts à répartir).
///
/// Retourne null si les paramètres ne permettent pas un calcul valide
/// (capital ou durée nuls/négatifs, taux négatif).
double? calculateMonthlyPayment({
  required double? principal,
  required double? annualRatePercent,
  required int? durationMonths,
}) {
  if (principal == null || principal <= 0) return null;
  if (annualRatePercent == null || annualRatePercent < 0) return null;
  if (durationMonths == null || durationMonths <= 0) return null;

  if (annualRatePercent == 0) {
    return principal / durationMonths;
  }

  final monthlyRate = annualRatePercent / 100 / 12;
  return principal * monthlyRate / (1 - math.pow(1 + monthlyRate, -durationMonths));
}
