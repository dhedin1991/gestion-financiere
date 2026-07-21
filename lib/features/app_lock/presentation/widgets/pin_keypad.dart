import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clavier numérique 3x4 en cartes rondes avec effet "ripple" au tap,
/// plus soigné que le clavier système par défaut.
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 72);
              }
              if (key == 'back') {
                return _KeypadButton(
                  onTap: onBackspace,
                  child: const Icon(Icons.backspace_outlined, size: 24),
                );
              }
              return _KeypadButton(
                onTap: () => onDigit(key),
                child: Text(
                  key,
                  style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _KeypadButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
