import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/calculator/domain/expression_evaluator.dart';

void main() {
  double calc(String s, {bool deg = true, double ans = 0}) =>
      ExpressionEvaluator(degrees: deg, ans: ans).evaluate(s);

  group('arithmétique', () {
    test('priorités et parenthèses', () {
      expect(calc('2+3×4'), 14);
      expect(calc('(2+3)×4'), 20);
      expect(calc('10÷4'), 2.5);
      expect(calc('10−2−3'), 5);
      expect(calc('2^3^2'), 512); // associativité à droite
      expect(calc('-2^2'), -4);
      expect(calc('2^-1'), 0.5);
    });

    test('virgule décimale et parenthèse oubliée', () {
      expect(calc('1,5+2,25'), 3.75);
      expect(calc('(2+3'), 5);
    });

    test('multiplication implicite', () {
      expect(calc('2(3+1)'), 8);
      expect(calc('2π'), closeTo(6.283185307, 1e-9));
    });

    test('erreurs lisibles', () {
      expect(() => calc('1÷0'), throwsA(isA<CalcError>()));
      expect(() => calc('√(−4)'), throwsA(isA<CalcError>()));
      expect(() => calc('2+'), throwsA(isA<CalcError>()));
      expect(() => calc('abc'), throwsA(isA<CalcError>()));
      expect(() => calc(''), throwsA(isA<CalcError>()));
    });
  });

  group('pourcentages', () {
    test('à la façon d\'une caisse', () {
      expect(calc('200+10%'), 220);
      expect(calc('200−10%'), 180);
      expect(calc('50%×200'), 100);
      expect(calc('50%'), 0.5);
    });
  });

  group('scientifique', () {
    test('racines, puissances, factorielle', () {
      expect(calc('√(81)'), 9);
      expect(calc('sqrt(2)^2'), closeTo(2, 1e-12));
      expect(calc('cbrt(27)'), closeTo(3, 1e-12));
      expect(calc('cbrt(-8)'), closeTo(-2, 1e-12));
      expect(calc('5!'), 120);
      expect(calc('0!'), 1);
      expect(() => calc('2.5!'), throwsA(isA<CalcError>()));
    });

    test('trigonométrie en degrés et en radians', () {
      expect(ExpressionEvaluator.clean(calc('sin(30)')), closeTo(0.5, 1e-12));
      expect(ExpressionEvaluator.clean(calc('sin(180)')), 0);
      expect(calc('cos(0)'), 1);
      expect(calc('atan(1)'), closeTo(45, 1e-9));
      expect(calc('sin(pi/2)', deg: false), closeTo(1, 1e-12));
      expect(() => calc('tan(90)'), throwsA(isA<CalcError>()));
    });

    test('logarithmes, exponentielle, constantes, ans', () {
      expect(calc('ln(e)'), closeTo(1, 1e-12));
      expect(calc('log(1000)'), closeTo(3, 1e-12));
      expect(calc('exp(0)'), 1);
      expect(calc('ans×2', ans: 21), 42);
      expect(() => calc('ln(0)'), throwsA(isA<CalcError>()));
    });
  });

  group('affichage', () {
    test('formats', () {
      expect(ExpressionEvaluator.plain(0.1 + 0.2), '0,3');
      expect(ExpressionEvaluator.plain(1234567), '1234567');
      expect(ExpressionEvaluator.pretty(1234567.5), '1 234 567,5');
      expect(ExpressionEvaluator.pretty(-1500), '-1 500');
    });
  });
}
