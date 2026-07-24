import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/audit_log_dao.dart';

final auditLogDaoProvider = Provider<AuditLogDao>((ref) {
  return AuditLogDao(ref.watch(appDatabaseProvider));
});

final auditLogEntriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(auditLogDaoProvider).recent();
});
