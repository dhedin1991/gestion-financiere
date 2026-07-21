import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../budgets/presentation/providers/budget_providers.dart';
import '../../../credits/presentation/providers/credit_providers.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../data/notification_service.dart';
import '../../data/reminder_sync_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final reminderSyncServiceProvider = Provider<ReminderSyncService>((ref) {
  return ReminderSyncService(
    notifications: ref.watch(notificationServiceProvider),
    creditRepository: ref.watch(creditRepositoryProvider),
    debtRepository: ref.watch(debtRepositoryProvider),
    budgetRepository: ref.watch(budgetRepositoryProvider),
  );
});

/// Lu une seule fois au démarrage de l'app (dans main.dart) pour
/// déclencher la resynchronisation des rappels. `keepAlive` pour ne pas
/// le relancer à chaque rebuild du widget qui l'observe.
final reminderBootstrapProvider = FutureProvider<void>((ref) async {
  ref.keepAlive();
  await ref.watch(reminderSyncServiceProvider).syncAll();
});
