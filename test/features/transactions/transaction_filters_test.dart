import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/transactions/domain/entities/transaction.dart';
import 'package:gestion_financiere/features/transactions/presentation/providers/transaction_providers.dart';

void main() {
  group('TransactionFilters.isActive', () {
    test('faux quand aucun filtre n\'est appliqué', () {
      expect(const TransactionFilters().isActive, isFalse);
    });

    test('vrai avec une recherche texte non vide', () {
      expect(const TransactionFilters(search: 'loyer').isActive, isTrue);
    });

    test('faux avec une recherche texte vide ou seulement des espaces', () {
      expect(const TransactionFilters(search: '   ').isActive, isFalse);
    });

    test('vrai avec un filtre de compte, catégorie ou type', () {
      expect(const TransactionFilters(accountId: 1).isActive, isTrue);
      expect(const TransactionFilters(categoryId: 2).isActive, isTrue);
      expect(const TransactionFilters(type: TransactionType.revenu).isActive, isTrue);
    });

    test('copyWith remet un filtre à null via la fonction fournie', () {
      const initial = TransactionFilters(accountId: 5);
      final cleared = initial.copyWith(accountId: () => null);
      expect(cleared.accountId, isNull);
    });

    test('copyWith sans argument conserve les valeurs existantes', () {
      const initial = TransactionFilters(search: 'abc', accountId: 3);
      final unchanged = initial.copyWith();
      expect(unchanged.search, 'abc');
      expect(unchanged.accountId, 3);
    });
  });
}
