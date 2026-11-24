import 'dart:math' as math;

/// Erreur de calcul avec un message lisible en français.
class CalcError implements Exception {
  final String message;
  const CalcError(this.message);
  @override
  String toString() => message;
}

/// Évaluateur d'expressions de la calculatrice (sans dépendance externe).
///
/// Gère : + − × ÷, puissance (^), pourcentage (50 %), factorielle (n!),
/// parenthèses (fermées automatiquement si oubliées), multiplication
/// implicite (2π, 3(4+1)), constantes (pi, e, ans) et fonctions
/// scientifiques (sqrt, cbrt, sin, cos, tan, asin, acos, atan, sinh, cosh,
/// tanh, ln, log, exp, abs, floor, ceil, round).
///
/// Pourcentage « de caisse » : `200 + 10 %` donne 220 et `200 − 10 %` donne
/// 180 (le pourcentage s'applique au premier nombre) ; `50 % × 200` donne 100.
class ExpressionEvaluator {
  /// Angles en degrés (true) ou en radians (false) pour sin/cos/tan.
  final bool degrees;

  /// Dernier résultat, accessible par `ans`.
  final double ans;

  ExpressionEvaluator({this.degrees = true, this.ans = 0});

  late String _s;
  int _i = 0;

  static const _functions = {
    'sqrt', 'cbrt', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan',
    'sinh', 'cosh', 'tanh', 'ln', 'log', 'exp', 'abs', 'floor', 'ceil', 'round',
  };

  /// Normalise les symboles saisis (×, ÷, −, virgule, √, π...).
  static String normalize(String input) {
    return input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll(',', '.')
        .replaceAll('√', 'sqrt')
        .replaceAll('∛', 'cbrt')
        .replaceAll('π', 'pi')
        .replaceAll(RegExp(r'[\s  ]'), '')
        .toLowerCase();
  }

  /// Calcule l'expression. Lève [CalcError] si elle est invalide.
  double evaluate(String input) {
    var s = normalize(input);
    if (s.isEmpty) throw const CalcError('Expression vide');
    // Ferme les parenthèses laissées ouvertes.
    final open = '('.allMatches(s).length - ')'.allMatches(s).length;
    if (open > 0) s += ')' * open;
    _s = s;
    _i = 0;
    final r = _expr();
    if (_i < _s.length) {
      throw CalcError('Caractère inattendu « ${_s[_i]} »');
    }
    return _check(r);
  }

  double _check(double v) {
    if (v.isNaN) throw const CalcError('Résultat indéfini');
    if (v.isInfinite) throw const CalcError('Résultat trop grand');
    return v;
  }

  bool _peekIs(String c) => _i < _s.length && _s[_i] == c;

  double _expr() {
    var value = _term().$1;
    while (_i < _s.length && (_s[_i] == '+' || _s[_i] == '-')) {
      final op = _s[_i++];
      final (rhs, rhsPct) = _term();
      // « base ± x % » : le pourcentage porte sur la base.
      final operand = rhsPct ? value * rhs : rhs;
      value = op == '+' ? value + operand : value - operand;
    }
    return value;
  }

  /// Retourne (valeur, vrai si le terme est un simple pourcentage « x % »).
  (double, bool) _term() {
    var (value, pct) = _unary();
    var factors = 1;
    while (_i < _s.length) {
      final c = _s[_i];
      if (c == '*' || c == '/') {
        _i++;
        final (rhs, _) = _unary();
        if (c == '*') {
          value *= rhs;
        } else {
          if (rhs == 0) throw const CalcError('Division par zéro');
          value /= rhs;
        }
        factors++;
      } else if (c == '(' || _startsName() || _startsNumber()) {
        // Multiplication implicite : 2(3), 2pi, 3sqrt(4).
        final (rhs, _) = _unary();
        value *= rhs;
        factors++;
      } else {
        break;
      }
    }
    return (value, pct && factors == 1);
  }

  bool _startsName() => _i < _s.length && RegExp(r'[a-z]').hasMatch(_s[_i]);
  bool _startsNumber() => _i < _s.length && RegExp(r'[0-9.]').hasMatch(_s[_i]);

  (double, bool) _unary() {
    if (_peekIs('-')) {
      _i++;
      final (v, _) = _unary();
      return (-v, false);
    }
    if (_peekIs('+')) {
      _i++;
      return _unary();
    }
    return _power();
  }

  (double, bool) _power() {
    final (base, pct) = _postfix();
    if (_peekIs('^')) {
      _i++;
      final (exp, _) = _unary(); // associativité à droite, exposant signé permis
      if (base < 0 && exp != exp.roundToDouble()) {
        throw const CalcError('Puissance non réelle');
      }
      return (math.pow(base, exp).toDouble(), false);
    }
    return (base, pct);
  }

  (double, bool) _postfix() {
    var value = _primary();
    var pct = false;
    while (_i < _s.length) {
      if (_s[_i] == '!') {
        _i++;
        value = _factorial(value);
        pct = false;
      } else if (_s[_i] == '%') {
        _i++;
        value = value / 100;
        pct = true;
      } else {
        break;
      }
    }
    return (value, pct);
  }

  double _factorial(double v) {
    if (v < 0 || v != v.roundToDouble()) {
      throw const CalcError('Factorielle : entier positif attendu');
    }
    if (v > 170) throw const CalcError('Résultat trop grand');
    var r = 1.0;
    for (var k = 2; k <= v.toInt(); k++) {
      r *= k;
    }
    return r;
  }

  double _primary() {
    if (_i >= _s.length) throw const CalcError('Expression incomplète');
    final c = _s[_i];
    if (c == '(') {
      _i++;
      final v = _expr();
      if (!_peekIs(')')) throw const CalcError('Parenthèse manquante');
      _i++;
      return v;
    }
    if (RegExp(r'[0-9.]').hasMatch(c)) return _number();
    if (RegExp(r'[a-z]').hasMatch(c)) return _nameOrCall();
    throw CalcError('Caractère inattendu « $c »');
  }

  double _number() {
    final start = _i;
    while (_i < _s.length && RegExp(r'[0-9.]').hasMatch(_s[_i])) {
      _i++;
    }
    // Notation scientifique : 1e5, 2.5e-3 (seulement si un chiffre suit).
    if (_i < _s.length && _s[_i] == 'e') {
      var j = _i + 1;
      if (j < _s.length && (_s[j] == '+' || _s[j] == '-')) j++;
      if (j < _s.length && RegExp(r'[0-9]').hasMatch(_s[j])) {
        _i = j;
        while (_i < _s.length && RegExp(r'[0-9]').hasMatch(_s[_i])) {
          _i++;
        }
      }
    }
    final text = _s.substring(start, _i);
    final v = double.tryParse(text);
    if (v == null) throw CalcError('Nombre invalide « $text »');
    return v;
  }

  double _nameOrCall() {
    final start = _i;
    while (_i < _s.length && RegExp(r'[a-z0-9]').hasMatch(_s[_i])) {
      // Une constante collée à un nombre (« pi2 ») s'arrête au chiffre.
      if (RegExp(r'[0-9]').hasMatch(_s[_i])) break;
      _i++;
    }
    var name = _s.substring(start, _i);
    if (!_known(name)) {
      // « pie » → pi × e : on garde le plus long nom connu en début de mot.
      for (var len = name.length - 1; len >= 1; len--) {
        if (_known(name.substring(0, len))) {
          name = name.substring(0, len);
          _i = start + len;
          break;
        }
      }
    }
    switch (name) {
      case 'pi':
        return math.pi;
      case 'e':
        return math.e;
      case 'ans':
        return ans;
    }
    if (_functions.contains(name)) {
      if (!_peekIs('(')) {
        // « sqrt9 » : accepte un argument sans parenthèses.
        final (arg, _) = _unary();
        return _apply(name, arg);
      }
      _i++;
      final arg = _expr();
      if (!_peekIs(')')) throw const CalcError('Parenthèse manquante');
      _i++;
      return _apply(name, arg);
    }
    throw CalcError('Fonction inconnue « $name »');
  }

  bool _known(String n) => n == 'pi' || n == 'e' || n == 'ans' || _functions.contains(n);

  double _toRad(double x) => degrees ? x * math.pi / 180 : x;
  double _fromRad(double x) => degrees ? x * 180 / math.pi : x;

  double _apply(String fn, double x) {
    switch (fn) {
      case 'sqrt':
        if (x < 0) throw const CalcError('Racine d\'un nombre négatif');
        return math.sqrt(x);
      case 'cbrt':
        return x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
      case 'sin':
        return math.sin(_toRad(x));
      case 'cos':
        return math.cos(_toRad(x));
      case 'tan':
        final r = _toRad(x);
        if (math.cos(r).abs() < 1e-12) throw const CalcError('Tangente indéfinie');
        return math.tan(r);
      case 'asin':
        if (x < -1 || x > 1) throw const CalcError('asin : valeur entre -1 et 1');
        return _fromRad(math.asin(x));
      case 'acos':
        if (x < -1 || x > 1) throw const CalcError('acos : valeur entre -1 et 1');
        return _fromRad(math.acos(x));
      case 'atan':
        return _fromRad(math.atan(x));
      case 'sinh':
        return (math.exp(x) - math.exp(-x)) / 2;
      case 'cosh':
        return (math.exp(x) + math.exp(-x)) / 2;
      case 'tanh':
        final a = math.exp(x), b = math.exp(-x);
        return (a - b) / (a + b);
      case 'ln':
        if (x <= 0) throw const CalcError('Logarithme : nombre positif attendu');
        return math.log(x);
      case 'log':
        if (x <= 0) throw const CalcError('Logarithme : nombre positif attendu');
        return math.log(x) / math.ln10;
      case 'exp':
        return math.exp(x);
      case 'abs':
        return x.abs();
      case 'floor':
        return x.floorToDouble();
      case 'ceil':
        return x.ceilToDouble();
      case 'round':
        return x.roundToDouble();
    }
    throw CalcError('Fonction inconnue « $fn »');
  }

  /// Arrondit le bruit de calcul flottant (sin(180°) = 1,2e-16 → 0).
  static double clean(double v) {
    if (v.abs() < 1e-12) return 0;
    return double.parse(v.toStringAsPrecision(12));
  }

  /// Nombre → texte brut sans séparateur de milliers, virgule décimale.
  static String plain(double v) {
    final c = clean(v);
    if (c == c.roundToDouble() && c.abs() < 1e15) {
      return c.toInt().toString();
    }
    var t = c.toString();
    if (t.contains('e')) return t.replaceAll('.', ',');
    if (t.contains('.')) {
      t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return t.replaceAll('.', ',');
  }

  /// Nombre → texte d'affichage avec espaces entre milliers (1 234 567,89).
  static String pretty(double v) {
    final p = plain(v);
    if (p.contains('e')) return p;
    final neg = p.startsWith('-');
    final body = neg ? p.substring(1) : p;
    final parts = body.split(',');
    final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
    return '${neg ? '-' : ''}$intPart${parts.length > 1 ? ',${parts[1]}' : ''}';
  }
}
