import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/app_logger.dart';

/// Enveloppe autour de flutter_local_notifications : init, permissions,
/// planification et annulation. Les IDs de notification sont dérivés de
/// façon déterministe (voir ReminderSyncService) pour pouvoir les annuler
/// individuellement sans avoir à tout retenir en base.
///
/// Les notifications ne sont disponibles que sur mobile (Android/iOS) :
/// le plugin ne gère pas Windows, on désactive proprement le service
/// plutôt que d'échouer silencieusement.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> init() {
    if (!isSupported || _initialized) return Future.value();
    // Appels simultanés : une seule initialisation, tous attendent la même.
    return _initializing ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      tzdata.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (e, st) {
      _initializing = null;
      AppLogger.error('Initialisation des notifications impossible',
          name: 'notifications', error: e, stackTrace: st);
    }
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
    if (!isSupported || when.isBefore(DateTime.now())) return;
    await init();
    if (!_initialized) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        // Mode « inexact » : ne demande AUCUNE permission d'alarme exacte
        // (refusée par défaut sur Android 14+). Pour un rappel d'échéance,
        // quelques minutes de décalage n'ont aucune importance.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      // Un rappel qui échoue ne doit jamais empêcher les autres d'être
      // programmés ni faire planter l'app.
      AppLogger.error('Planification du rappel $id impossible',
          name: 'notifications', error: e, stackTrace: st);
    }
  }

  Future<void> showNow({required int id, required String title, required String body}) async {
    if (!isSupported) return;
    await init();
    if (!_initialized) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
      );
    } catch (e, st) {
      AppLogger.error('Affichage de la notification $id impossible',
          name: 'notifications', error: e, stackTrace: st);
    }
  }

  Future<void> cancel(int id) async {
    if (!isSupported) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  /// Annule les notifications d'une liste d'IDs avant de replanifier, pour
  /// éviter les doublons ou les rappels obsolètes (ex: dette soldée
  /// entre-temps).
  Future<void> cancelRange(Iterable<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }
}
