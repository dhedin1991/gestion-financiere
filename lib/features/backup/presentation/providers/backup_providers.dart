import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auto_backup_service.dart';
import '../../data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

final autoBackupServiceProvider = Provider<AutoBackupService>((ref) => AutoBackupService());

/// Lance une sauvegarde automatique silencieuse si la dernière remonte à
/// plus de 7 jours (voir AutoBackupService). Lu une seule fois au démarrage,
/// comme reminderBootstrapProvider et recurringGenerationBootstrapProvider.
final autoBackupBootstrapProvider = FutureProvider<void>((ref) async {
  ref.keepAlive();
  await ref.watch(autoBackupServiceProvider).runIfDue();
});

/// Date du dernier export manuel, pour afficher un rappel si elle est
/// ancienne (voir BackupPage). `autoDispose` : relu à chaque ouverture de
/// l'écran, donc à jour juste après un export.
final lastExportDateProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  return ref.watch(backupServiceProvider).lastExportDate();
});
