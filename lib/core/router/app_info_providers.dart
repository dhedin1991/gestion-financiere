import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';
import 'app_info_service.dart';

final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  final appDatabase = ref.watch(appDatabaseProvider);
  return AppInfoService(appDatabase);
});

final appUsageStatsProvider = FutureProvider.autoDispose<AppUsageStats>((ref) async {
  final service = ref.watch(appInfoServiceProvider);
  return service.computeStats();
});
