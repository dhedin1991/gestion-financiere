import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/account.dart';

/// Niveau d'alerte visuelle d'un solde.
enum AlertLevel { ok, warning, critical }

/// Seuils par défaut (modifiables dans Paramètres > Comptes, et surchargeables
/// compte par compte dans la fiche du compte).
class BalanceThresholds {
  final double warning;
  final double critical;
  const BalanceThresholds({this.warning = 15000, this.critical = 10000});
}

class BalanceThresholdsController extends StateNotifier<BalanceThresholds> {
  BalanceThresholdsController() : super(const BalanceThresholds()) {
    _load();
  }

  static const _kWarning = 'alert_warning_default';
  static const _kCritical = 'alert_critical_default';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = BalanceThresholds(
        warning: p.getDouble(_kWarning) ?? 15000,
        critical: p.getDouble(_kCritical) ?? 10000,
      );
    } catch (_) {}
  }

  Future<void> set({required double warning, required double critical}) async {
    final w = warning < critical ? critical : warning;
    state = BalanceThresholds(warning: w, critical: critical);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kWarning, w);
      await p.setDouble(_kCritical, critical);
    } catch (_) {}
  }
}

final balanceThresholdsProvider =
    StateNotifierProvider<BalanceThresholdsController, BalanceThresholds>((ref) => BalanceThresholdsController());

AlertLevel alertLevelFor(Account a, BalanceThresholds t) {
  final critical = a.alertCritical ?? t.critical;
  final warning = a.alertWarning ?? t.warning;
  if (a.currentBalance <= critical) return AlertLevel.critical;
  if (a.currentBalance <= warning) return AlertLevel.warning;
  return AlertLevel.ok;
}

Color alertColor(BuildContext context, AlertLevel level) {
  final c = context.appColors;
  switch (level) {
    case AlertLevel.critical:
      return c.negative;
    case AlertLevel.warning:
      return c.warning;
    case AlertLevel.ok:
      return c.positive;
  }
}

String alertLabel(AlertLevel level) {
  switch (level) {
    case AlertLevel.critical:
      return 'Solde critique';
    case AlertLevel.warning:
      return 'Solde faible';
    case AlertLevel.ok:
      return 'Liquidités suffisantes';
  }
}
