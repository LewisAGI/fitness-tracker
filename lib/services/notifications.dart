import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'checkin_scheduler.dart';

class LocalNotifications implements NotificationPort {
  LocalNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String payload)? onPayload;
  var ready = false;

  Future<void> init({void Function(String payload)? onPayload}) async {
    this.onPayload = onPayload;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } on Object {
      tz.setLocalLocation(tz.getLocation('Europe/London'));
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          this.onPayload?.call(payload);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'checkins',
            'Check-ins',
            importance: Importance.high,
          ),
        );
    ready = true;
  }

  @override
  Future<void> cancel(int id) async {
    if (!ready) {
      return;
    }
    await _plugin.cancel(id);
  }

  @override
  Future<void> scheduleDaily(ScheduledSlot slot) async {
    if (!ready) {
      return;
    }
    final when = _nextInstance(slot.hour, slot.minute);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'checkins',
        'Check-ins',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      slot.id,
      slot.title,
      _body(slot),
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: slot.payload,
    );
  }

  String _body(ScheduledSlot slot) {
    final hour = slot.hour.toString().padLeft(2, '0');
    final minute = slot.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

@visibleForTesting
tz.TZDateTime nextCheckInForTest(int hour, int minute) {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/London'));
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
