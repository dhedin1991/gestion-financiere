import 'package:flutter/material.dart';

/// Ligne de points représentant la saisie du PIN, avec une animation de
/// secousse douce (translation horizontale oscillante) quand [shake] passe
/// à true — signal visuel immédiat de code incorrect, plus élégant qu'un
/// simple message d'erreur.
class PinDots extends StatefulWidget {
  final int length;
  final int filledCount;
  final bool shake;
  final VoidCallback? onShakeComplete;

  const PinDots({
    super.key,
    required this.length,
    required this.filledCount,
    required this.shake,
    this.onShakeComplete,
  });

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _offset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onShakeComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;

    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offset.value, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.length, (i) {
          final filled = i < widget.filledCount;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: filled ? 16 : 14,
            height: filled ? 16 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? (widget.shake ? errorColor : color) : Colors.transparent,
              border: Border.all(
                color: widget.shake ? errorColor : color,
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }
}
