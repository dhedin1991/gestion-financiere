import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import 'audit_log_providers.dart';

/// Écrit une entrée dans le journal d'audit sans jamais faire échouer
/// l'action métier qui l'a déclenchée (le journal est un filet de traçabilité,
/// pas une condition de réussite).
Future<void> logAudit(
  Ref ref, {
  required String entityType,
  int entityId = 0,
  required String action,
  String? oldValue,
  String? newValue,
}) async {
  try {
    await ref.read(auditLogDaoProvider).log(
          entityType: entityType,
          entityId: entityId,
          action: action,
          oldValue: oldValue,
          newValue: newValue,
        );
  } catch (e, st) {
    AppLogger.error('Écriture du journal d\'audit impossible', name: 'audit', error: e, stackTrace: st);
  }
}
