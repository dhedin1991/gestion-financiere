import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Enveloppe autour de flutter_local_notifications : init, permissions,
/// planification et annulation. Les IDs de notification sont dérivés de
/// façon déterministe (voir ReminderSyncService) pour pouvoir les annuler
/// individuellement sans avoir à tout retenir en base.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  static const _channel = AndroidNotificationDetails(
    'rappels_financiers',
    'Rappels financiers',
    channelDescription: 'Échéances de crédits/dettes et alertes de budget',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showNow({required int id, required String title, required String body}) async {
    await init();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Annule toutes les notifications d'une catégorie donnée (une plage
  /// d'IDs réservée — voir ReminderSyncService._idFor) avant de
  /// replanifier, pour éviter les doublons ou les rappels obsolètes
  /// (ex: dette soldée entre-temps).
  Future<void> cancelRange(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }
}
