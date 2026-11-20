import 'package:intl/intl.dart';

import '../display/display_prefs.dart';

/// Formatage des montants tenant compte des préférences d'affichage
/// (séparateur des milliers, mode confidentialité).
class AppNumberFormat {
  final String symbol;
  final int decimalDigits;
  final bool compact;
  const AppNumberFormat({this.symbol = '', this.decimalDigits = 0, this.compact = false});

  String format(num value) {
    final prefs = DisplayPrefs.current;
    if (prefs.hideAmounts) return '••••';
    final String body;
    if (compact) {
      body = NumberFormat.compact(locale: 'fr_FR').format(value);
    } else {
      final f = NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: decimalDigits);
      // Le séparateur de milliers fr_FR est une espace fine insécable.
      body = f.format(value).replaceAll(RegExp('[   ]'), prefs.separator.char);
    }
    if (symbol.isEmpty) return body;
    return '$body $symbol';
  }
}

class AppFormat {
  AppFormat._();

  static AppNumberFormat currency({String symbol = '', int decimalDigits = 0}) =>
      AppNumberFormat(symbol: symbol, decimalDigits: decimalDigits);

  static AppNumberFormat compactCurrency({String symbol = ''}) =>
      AppNumberFormat(symbol: symbol, compact: true);

  /// Montant sans devise.
  static String amount(num value) => const AppNumberFormat().format(value);
}
