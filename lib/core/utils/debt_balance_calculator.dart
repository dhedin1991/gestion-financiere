import '../../features/debts/domain/entities/debt.dart';

/// Calcule l'impact signé d'un paiement de dette/créance sur le solde du
/// compte lié.
///
/// - Dette ("je dois de l'argent") : payer fait sortir de l'argent du
///   compte → impact négatif.
/// - Créance ("on me doit de l'argent") : recevoir un paiement fait
///   entrer de l'argent sur le compte → impact positif.
///
/// [amount] doit toujours être positif (le montant du paiement lui-même,
/// jamais déjà signé) — c'est cette fonction qui décide du signe.
double signedDebtPaymentAmount({required DebtType type, required double amount}) {
  return type == DebtType.dette ? -amount : amount;
}

/// Calcule le montant à appliquer pour annuler un effet déjà appliqué au
/// solde (ex : suppression d'un paiement, ou d'une dette avec des
/// paiements déjà effectués). C'est simplement l'opposé de l'effet
/// d'origine — extrait en fonction séparée pour que l'intention
/// ("j'annule quelque chose") soit explicite au lieu d'un `-` isolé
/// perdu dans le code appelant.
double reverseSignedAmount(double appliedSignedAmount) => -appliedSignedAmount;
