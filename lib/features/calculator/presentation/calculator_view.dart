import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/navigation/app_back_button.dart';
import '../../../core/navigation/app_menu_button.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/expression_evaluator.dart';

/// Ouvre la calculatrice par-dessus la page en cours (fenêtre sur PC,
/// panneau plein écran sur téléphone) : accessible de partout, sans perdre
/// ce qu'on était en train de faire.
Future<void> showCalculator(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 760;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
          child: const CalculatorView(),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: const CalculatorView(),
    ),
  );
}

/// Page plein écran (entrée « Calculatrice » du menu).
class CalculatorPage extends StatelessWidget {
  const CalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Calculatrice'),
        actions: const [AppMenuButton()],
      ),
      body: const SafeArea(child: CalculatorView()),
    );
  }
}

class _HistoryEntry {
  final String expression;
  final String result;
  final DateTime at;
  _HistoryEntry(this.expression, this.result, this.at);

  Map<String, dynamic> toJson() => {'e': expression, 'r': result, 't': at.toIso8601String()};
  static _HistoryEntry fromJson(Map<String, dynamic> j) =>
      _HistoryEntry(j['e'] as String, j['r'] as String, DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime.now());
}

/// Calculatrice complète : opérations, pourcentages, racines, puissances,
/// fonctions scientifiques, mémoire (MC MR M+ M−) et historique conservé.
class CalculatorView extends StatefulWidget {
  const CalculatorView({super.key});

  @override
  State<CalculatorView> createState() => _CalculatorViewState();
}

class _CalculatorViewState extends State<CalculatorView> {
  static const _historyKey = 'calc_history_v1';
  static const _memoryKey = 'calc_memory_v1';
  static const _modeKey = 'calc_scientific_v1';
  static const _degKey = 'calc_degrees_v1';

  String _expr = '';
  String? _error;
  bool _justEvaluated = false;
  bool _scientific = false;
  bool _degrees = true;
  bool _inverse = false; // 2nde : sin → asin, etc.
  double _memory = 0;
  double _ans = 0;
  final List<_HistoryEntry> _history = [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final raw = prefs.getString(_historyKey);
      final list = <_HistoryEntry>[];
      if (raw != null) {
        for (final e in jsonDecode(raw) as List) {
          list.add(_HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(list);
        _memory = prefs.getDouble(_memoryKey) ?? 0;
        _scientific = prefs.getBool(_modeKey) ?? false;
        _degrees = prefs.getBool(_degKey) ?? true;
        if (_history.isNotEmpty) {
          _ans = double.tryParse(_history.first.result.replaceAll(',', '.')) ?? 0;
        }
      });
    } catch (_) {
      // Pas de stockage disponible : la calculatrice fonctionne quand même.
    }
  }

  void _persist() {
    try {
      _prefs?.setString(_historyKey, jsonEncode(_history.take(60).map((e) => e.toJson()).toList()));
      _prefs?.setDouble(_memoryKey, _memory);
      _prefs?.setBool(_modeKey, _scientific);
      _prefs?.setBool(_degKey, _degrees);
    } catch (_) {}
  }

  ExpressionEvaluator get _evaluator => ExpressionEvaluator(degrees: _degrees, ans: _ans);

  /// Valeur courante : résultat de l'expression, ou null si invalide / vide.
  double? get _currentValue {
    if (_expr.isEmpty) return null;
    try {
      return _evaluator.evaluate(_expr);
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────── saisie ─────────────────────────

  static const _ops = ['+', '−', '×', '÷', '^'];

  bool get _endsWithOp => _expr.isNotEmpty && _ops.contains(_expr[_expr.length - 1]);

  void _set(String expr, {bool evaluated = false}) {
    setState(() {
      _expr = expr;
      _error = null;
      _justEvaluated = evaluated;
    });
  }

  void _digit(String d) {
    if (_justEvaluated) {
      _set(d);
    } else {
      _set(_expr + d);
    }
  }

  void _decimal() {
    if (_justEvaluated) {
      _set('0,');
      return;
    }
    final seg = RegExp(r'[0-9,]*$').stringMatch(_expr) ?? '';
    if (seg.contains(',')) return;
    _set(seg.isEmpty ? '${_expr}0,' : '$_expr,');
  }

  void _operator(String op) {
    if (_expr.isEmpty) {
      if (op == '−') _set('−');
      return;
    }
    if (_endsWithOp) {
      final last = _expr[_expr.length - 1];
      if (op == '−' && (last == '×' || last == '÷' || last == '^')) {
        _set('$_expr−');
      } else {
        _set(_expr.substring(0, _expr.length - 1) + op);
      }
      return;
    }
    if (_expr.endsWith('(') && op != '−') return;
    _set('$_expr$op');
  }

  void _openParen() {
    if (_justEvaluated) {
      _set('(');
    } else {
      _set('$_expr(');
    }
  }

  void _closeParen() {
    final open = '('.allMatches(_expr).length - ')'.allMatches(_expr).length;
    if (open > 0 && !_endsWithOp && !_expr.endsWith('(')) _set('$_expr)');
  }

  void _postfix(String s) {
    if (_expr.isEmpty || _endsWithOp || _expr.endsWith('(')) return;
    _set('$_expr$s', evaluated: false);
  }

  /// Fonction à argument : « sin( », « √( »… Si un résultat vient d'être
  /// calculé, il devient l'argument (sin(30) en tapant 30 puis = puis sin).
  void _function(String name) {
    if (_justEvaluated && _expr.isNotEmpty) {
      _set('$name$_expr)');
    } else {
      _set('$_expr$name');
    }
  }

  void _constant(String c) {
    if (_justEvaluated) {
      _set(c);
    } else {
      _set('$_expr$c');
    }
  }

  void _square() => _postfix('^2');

  void _reciprocal() {
    if (_expr.isEmpty) return;
    _set('1÷($_expr)');
  }

  void _negate() {
    if (_expr.isEmpty) {
      _set('−');
      return;
    }
    final m = RegExp(r'\d+(?:,\d+)?$').firstMatch(_expr);
    if (m == null) return;
    final start = m.start;
    if (start == 0) {
      _set('−$_expr');
      return;
    }
    final before = _expr[start - 1];
    if (before == '−' && (start == 1 || _ops.contains(_expr[start - 2]) || _expr[start - 2] == '(')) {
      _set(_expr.substring(0, start - 1) + _expr.substring(start)); // retire le « − » unaire
    } else if (before == '−') {
      _set('${_expr.substring(0, start - 1)}+${_expr.substring(start)}');
    } else if (before == '+') {
      _set('${_expr.substring(0, start - 1)}−${_expr.substring(start)}');
    } else {
      _set('${_expr.substring(0, start)}−${_expr.substring(start)}');
    }
  }

  void _backspace() {
    if (_justEvaluated) {
      _set('');
      return;
    }
    if (_expr.isEmpty) return;
    // Supprime un nom de fonction entier (« sin( ») d'un seul coup.
    final m = RegExp(r'(√\(|∛\(|[a-z]+\(|ans)$').firstMatch(_expr);
    _set(m != null ? _expr.substring(0, m.start) : _expr.substring(0, _expr.length - 1));
  }

  void _clear() => _set('');

  void _equals() {
    if (_expr.isEmpty) return;
    try {
      final v = _evaluator.evaluate(_expr);
      final result = ExpressionEvaluator.plain(v);
      setState(() {
        _history.insert(0, _HistoryEntry(_expr, result, DateTime.now()));
        if (_history.length > 60) _history.removeLast();
        _ans = ExpressionEvaluator.clean(v);
        _expr = result;
        _error = null;
        _justEvaluated = true;
      });
      _persist();
    } on CalcError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Calcul impossible');
    }
  }

  // ───────────────────────── mémoire ─────────────────────────

  void _memoryAdd(int sign) {
    final v = _currentValue;
    if (v == null) {
      setState(() => _error = 'Rien à mémoriser');
      return;
    }
    setState(() {
      _memory += sign * v;
      _error = null;
    });
    _persist();
  }

  void _memoryRecall() {
    final text = ExpressionEvaluator.plain(_memory);
    if (_justEvaluated || _expr.isEmpty) {
      _set(text);
    } else {
      _set('$_expr$text');
    }
  }

  void _memoryClear() {
    setState(() => _memory = 0);
    _persist();
  }

  // ───────────────────────── clavier physique ─────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _equals();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.delete) {
      _clear();
      return KeyEventResult.handled;
    }
    final c = event.character;
    if (c == null || c.isEmpty) return KeyEventResult.ignored;
    switch (c) {
      case '0': case '1': case '2': case '3': case '4':
      case '5': case '6': case '7': case '8': case '9':
        _digit(c);
      case '.' || ',':
        _decimal();
      case '+':
        _operator('+');
      case '-':
        _operator('−');
      case '*':
        _operator('×');
      case '/':
        _operator('÷');
      case '^':
        _operator('^');
      case '(':
        _openParen();
      case ')':
        _closeParen();
      case '%':
        _postfix('%');
      case '!':
        _postfix('!');
      case '=':
        _equals();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ───────────────────────── affichage ─────────────────────────

  Future<void> _copy() async {
    final v = _currentValue;
    if (v == null) return;
    await Clipboard.setData(ClipboardData(text: ExpressionEvaluator.plain(v)));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Résultat copié'), duration: Duration(seconds: 1)),
    );
  }

  void _useHistory(_HistoryEntry e) {
    _set(e.result, evaluated: true);
  }

  void _clearHistory() {
    setState(_history.clear);
    _persist();
  }

  void _openHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.6,
        child: _HistoryList(
          entries: _history,
          onPick: (e) {
            Navigator.of(ctx).pop();
            _useHistory(e);
          },
          onClear: () {
            Navigator.of(ctx).pop();
            _clearHistory();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 700;
        final calc = _buildCalculator(context, wide);
        if (!wide) return calc;
        return Row(children: [
          Expanded(flex: 3, child: calc),
          VerticalDivider(width: 1, color: context.appColors.border),
          SizedBox(
            width: 260,
            child: _HistoryList(entries: _history, onPick: _useHistory, onClear: _clearHistory),
          ),
        ]);
      }),
    );
  }

  Widget _buildCalculator(BuildContext context, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final preview = (!_justEvaluated && _expr.isNotEmpty) ? _currentValue : null;

    final display = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(children: [
            if (_memory != 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('M ${ExpressionEvaluator.pretty(_memory)}', style: TextStyle(fontSize: 11, color: scheme.primary)),
              ),
            const Spacer(),
            if (_scientific)
              Text(_degrees ? 'DEG' : 'RAD', style: TextStyle(fontSize: 11, color: colors.muted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _expr.isEmpty ? '0' : _expr,
              maxLines: 1,
              style: amountTextStyle(
                fontSize: _justEvaluated ? 34 : 24,
                fontWeight: _justEvaluated ? FontWeight.w700 : FontWeight.w500,
                color: _expr.isEmpty ? colors.muted : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 22,
            child: _error != null
                ? Text(_error!, style: TextStyle(color: colors.negative, fontSize: 13))
                : Text(
                    preview == null ? '' : '= ${ExpressionEvaluator.pretty(preview)}',
                    style: amountTextStyle(fontSize: 16, color: colors.muted),
                  ),
          ),
        ],
      ),
    );

    final toolbar = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('Scientifique'),
          selected: _scientific,
          onSelected: (v) {
            setState(() => _scientific = v);
            _persist();
          },
        ),
        if (_scientific)
          ChoiceChip(
            label: Text(_degrees ? 'Degrés' : 'Radians'),
            selected: true,
            onSelected: (_) {
              setState(() => _degrees = !_degrees);
              _persist();
            },
          ),
        IconButton(
          tooltip: 'Copier le résultat',
          icon: const Icon(Icons.copy_outlined, size: 20),
          onPressed: _copy,
        ),
        if (!wide)
          IconButton(
            tooltip: 'Historique',
            icon: Badge(
              isLabelVisible: _history.isNotEmpty,
              label: Text('${_history.length}'),
              child: const Icon(Icons.history, size: 22),
            ),
            onPressed: _openHistorySheet,
          ),
      ],
    );

    Widget row(List<Widget> keys) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SizedBox(
            height: 52,
            child: Row(children: [
              for (var i = 0; i < keys.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: keys[i]),
              ],
            ]),
          ),
        );

    Widget num(String d) => _Key(d, () => _digit(d), kind: _KeyKind.number);
    Widget op(String s, [VoidCallback? f]) => _Key(s, f ?? () => _operator(s), kind: _KeyKind.operator);
    Widget fn(String label, VoidCallback f) => _Key(label, f, kind: _KeyKind.function);

    final memoryRow = row([
      fn('MC', _memoryClear),
      fn('MR', _memoryRecall),
      fn('M+', () => _memoryAdd(1)),
      fn('M−', () => _memoryAdd(-1)),
    ]);

    final inv = _inverse;
    final sciRows = <Widget>[
      row([
        fn(inv ? '1ʳᵉ' : '2ⁿᵈ', () => setState(() => _inverse = !_inverse)),
        fn(inv ? 'asin' : 'sin', () => _function(inv ? 'asin(' : 'sin(')),
        fn(inv ? 'acos' : 'cos', () => _function(inv ? 'acos(' : 'cos(')),
        fn(inv ? 'atan' : 'tan', () => _function(inv ? 'atan(' : 'tan(')),
        fn('π', () => _constant('π')),
      ]),
      row([
        fn('√', () => _function('√(')),
        fn('∛', () => _function('∛(')),
        fn('x²', _square),
        fn('xʸ', () => _operator('^')),
        fn('e', () => _constant('e')),
      ]),
      row([
        fn('ln', () => _function('ln(')),
        fn('log', () => _function('log(')),
        fn('eˣ', () => _function('exp(')),
        fn('n!', () => _postfix('!')),
        fn('1/x', _reciprocal),
      ]),
      row([
        fn('(', _openParen),
        fn(')', _closeParen),
        fn('|x|', () => _function('abs(')),
        fn('Rép', () => _constant('ans')),
        fn('arr.', () => _function('round(')),
      ]),
    ];

    final keypad = <Widget>[
      row([
        _Key('C', _clear, kind: _KeyKind.danger),
        _Key('⌫', _backspace, kind: _KeyKind.function),
        _Key('%', () => _postfix('%'), kind: _KeyKind.function),
        op('÷'),
      ]),
      row([num('7'), num('8'), num('9'), op('×')]),
      row([num('4'), num('5'), num('6'), op('−')]),
      row([num('1'), num('2'), num('3'), op('+')]),
      row([
        _Key('±', _negate, kind: _KeyKind.function),
        num('0'),
        _Key(',', _decimal, kind: _KeyKind.number),
        _Key('=', _equals, kind: _KeyKind.accent),
      ]),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          const SizedBox(height: 6),
          display,
          const SizedBox(height: 10),
          memoryRow,
          if (_scientific) ...sciRows,
          ...keypad,
        ],
      ),
    );
  }
}

enum _KeyKind { number, operator, function, accent, danger }

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _KeyKind kind;
  const _Key(this.label, this.onTap, {required this.kind});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (Color bg, Color fg) = switch (kind) {
      _KeyKind.number => (scheme.surfaceContainerHighest.withValues(alpha: 0.55), scheme.onSurface),
      _KeyKind.operator => (scheme.primary.withValues(alpha: 0.14), scheme.primary),
      _KeyKind.function => (colors.panel2, scheme.onSurface),
      _KeyKind.accent => (scheme.primary, scheme.onPrimary),
      _KeyKind.danger => (colors.negative.withValues(alpha: 0.14), colors.negative),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: FittedBox(
            child: Text(
              label,
              style: TextStyle(
                fontSize: kind == _KeyKind.function ? 15 : 20,
                fontWeight: kind == _KeyKind.number ? FontWeight.w500 : FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<_HistoryEntry> entries;
  final ValueChanged<_HistoryEntry> onPick;
  final VoidCallback onClear;
  const _HistoryList({required this.entries, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(children: [
            const Expanded(child: Text('Historique', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
            TextButton.icon(
              onPressed: entries.isEmpty ? null : onClear,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Effacer'),
            ),
          ]),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text('Aucun calcul pour le moment', style: TextStyle(color: colors.muted)))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return ListTile(
                      dense: true,
                      title: Text(e.expression, style: TextStyle(color: colors.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '= ${ExpressionEvaluator.pretty(double.tryParse(e.result.replaceAll(',', '.')) ?? 0)}',
                        style: amountTextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      onTap: () => onPick(e),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
