import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'display_prefs.dart';

/// Applique le zoom global (75–150 %) et la taille du texte choisis dans
/// Paramètres > Affichage, à toute l'application (y compris les boîtes de
/// dialogue, qui vivent dans le même arbre).
Widget displayBuilder(BuildContext context, Widget? child) {
  return DisplayScope(child: child ?? const SizedBox.shrink());
}

class DisplayScope extends ConsumerWidget {
  final Widget child;
  const DisplayScope({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(displayPrefsProvider);
    final mq = MediaQuery.of(context);
    final zoom = prefs.zoom / 100.0;
    final textScaler = TextScaler.linear(prefs.textSize.scale);

    if (prefs.zoom == 100) {
      return MediaQuery(data: mq.copyWith(textScaler: textScaler), child: child);
    }

    final w = mq.size.width;
    final h = mq.size.height;
    final inner = mq.copyWith(
      size: Size(w / zoom, h / zoom),
      padding: mq.padding / zoom,
      viewPadding: mq.viewPadding / zoom,
      viewInsets: mq.viewInsets / zoom,
      textScaler: textScaler,
    );
    return SizedBox(
      width: w,
      height: h,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: w / zoom,
          maxWidth: w / zoom,
          minHeight: h / zoom,
          maxHeight: h / zoom,
          child: Transform.scale(
            scale: zoom,
            alignment: Alignment.topLeft,
            child: MediaQuery(data: inner, child: child),
          ),
        ),
      ),
    );
  }
}
