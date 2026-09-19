import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/core/utils/month_math.dart';

void main() {
  group('addMonthsClamped', () {
    test('31 janvier + 1 mois = 28 février (année non bissextile), pas le 3 mars', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('31 janvier + 1 mois = 29 février (année bissextile)', () {
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('le jour d\'ancrage est retrouvé après un mois court', () {
      final feb = addMonthsClamped(DateTime(2026, 1, 31), 1, anchorDay: 31);
      expect(feb, DateTime(2026, 2, 28));
      final mar = addMonthsClamped(feb, 1, anchorDay: 31);
      expect(mar, DateTime(2026, 3, 31));
      final apr = addMonthsClamped(mar, 1, anchorDay: 31);
      expect(apr, DateTime(2026, 4, 30));
    });

    test('passage d\'année', () {
      expect(addMonthsClamped(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(addMonthsClamped(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 31));
    });

    test('+12 mois conserve le jour (29 février bissextile -> 28 février)', () {
      expect(addMonthsClamped(DateTime(2028, 2, 29), 12), DateTime(2029, 2, 28));
    });
  });
}
