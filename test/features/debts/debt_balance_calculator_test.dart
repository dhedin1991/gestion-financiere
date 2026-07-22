import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/debt_balance_calculator.dart';
import 'package:gestion_financiere/features/debts/domain/entities/debt.dart';

void main() {
  group('signedDebtPaymentAmount', () {
    test('payer une dette retire de l\'argent du compte (négatif)', () {
      expect(
        signedDebtPaymentAmount(type: DebtType.dette, amount: 10000),
        -10000,
      );
    });

    test('recevoir un paiement de créance ajoute de l\'argent au compte (positif)', () {
      expect(
        signedDebtPaymentAmount(type: DebtType.creance, amount: 10000),
        10000,
      );
    });

    test('le montant en entrée est toujours positif, jamais déjà signé', () {
      // Le montant en entrée doit toujours être positif ; c'est la
      // fonction qui décide du signe, pas l'appelant.
      final result = signedDebtPaymentAmount(type: DebtType.dette, amount: 500);
      expect(result.isNegative, isTrue);
      expect(result.abs(), 500);
    });
  });

  group('reverseSignedAmount', () {
    test('inverse un montant positif', () {
      expect(reverseSignedAmount(10000), -10000);
    });

    test('inverse un montant négatif', () {
      expect(reverseSignedAmount(-10000), 10000);
    });

    test('scénario complet : annuler une dette partiellement payée '
        'redonne exactement l\'argent prélevé', () {
      // Reproduction du bug corrigé plus tôt : payer une dette de 30000
      // puis supprimer la dette doit redonner exactement 30000 au compte.
      const paid = 30000.0;
      final appliedWhenPaid = signedDebtPaymentAmount(type: DebtType.dette, amount: paid);
      expect(appliedWhenPaid, -30000); // l'argent était sorti du compte

      final reversal = reverseSignedAmount(appliedWhenPaid);
      expect(reversal, 30000); // la suppression doit le restituer intégralement
    });

    test('scénario complet équivalent pour une créance', () {
      const paid = 15000.0;
      final appliedWhenReceived = signedDebtPaymentAmount(type: DebtType.creance, amount: paid);
      expect(appliedWhenReceived, 15000); // l'argent était entré sur le compte

      final reversal = reverseSignedAmount(appliedWhenReceived);
      expect(reversal, -15000); // la suppression doit le retirer à nouveau
    });
  });
}
