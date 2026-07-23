import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());
