import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Wraps flutter_local_notifications for the one thing this app needs
/// notifications for: alerting the user when their rest timer is done,
/// even if they've backgrounded the app. Scheduling is "inexact" so it
/// doesn't require the Android 12+ exact-alarm permission - a few
/// seconds of slack on a rest timer alert is a fine tradeoff for not
/// asking the user for an extra permission.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _restTimerNotificationId = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Toggled by SettingsManager; scheduling is a no-op while false.
  bool enabled = true;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleRestTimerDone(int seconds) async {
    if (!_initialized || !enabled) return;
    await cancelRestTimerNotification();
    try {
      await _plugin.zonedSchedule(
        _restTimerNotificationId,
        'Rest complete',
        'Time to start your next set.',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer',
            'Rest Timer',
            channelDescription: 'Alerts when your workout rest timer finishes',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Notification scheduling is a nice-to-have, not core
      // functionality - the in-app rest timer bar still works even if
      // the OS notification can't be scheduled for some reason.
    }
  }

  Future<void> cancelRestTimerNotification() async {
    if (!_initialized) return;
    await _plugin.cancel(_restTimerNotificationId);
  }
}
