import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';
import '../utils/formatters.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Notifier triggered whenever the user taps a notification in the system shade
  final ValueNotifier<String?> onNotificationTapped = ValueNotifier<String?>(null);

  static const _channelId = 'doseday_medication_alerts_v5';
  static const _channelName = 'DoseDay Medication Reminders';
  static const _channelDesc = 'Audible high-priority alerts for scheduled medication doses';

  static final NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('reminder_sound'),
      channelShowBadge: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'reminder_sound.wav',
    ),
  );

  /// Sets up time zones and the plugin. Permissions are requested separately
  /// (after the first frame) so the app UI is visible behind the prompt.
  Future<void> initialize() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        debugPrint('Could not resolve device timezone ($e), fallback to Asia/Manila');
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Manila'));
        } catch (_) {
          tz.setLocalLocation(tz.local);
        }
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked in shade: ${response.payload}');
          onNotificationTapped.value = response.payload ?? 'tapped';
        },
      );

      // Create high-priority Android notification channel with sound & vibration
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Clean up legacy channel IDs to ensure fresh sound & alarm priority registration
        for (final oldId in [
          'medication_reminders',
          'medication_reminders_sound_v1',
          'medication_reminders_sound_v2',
          'medication_reminders_alarm_v2',
          'medication_reminders_alarm_v3',
          'medication_reminders_alarm_v4',
        ]) {
          try {
            await androidPlugin.deleteNotificationChannel(oldId);
          } catch (_) {}
        }

        final channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
          sound: const RawResourceAndroidNotificationSound('reminder_sound'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
        await androidPlugin.createNotificationChannel(channel);
      }

      // Check if app was opened by tapping a notification
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        debugPrint('App launched from notification payload: $payload');
        onNotificationTapped.value = payload ?? 'launched_from_notification';
      }

      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        return enabled ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_ready) return false;
    bool? granted;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = await android.requestNotificationsPermission();
      try {
        final canExact = await android.canScheduleExactNotifications();
        if (canExact == false) {
          await android.requestExactAlarmsPermission();
        }
      } catch (e) {
        debugPrint('Exact alarms request: $e');
      }
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
    }
    return granted ?? false;
  }

  /// Schedules exact alarms for each active medication dose over the next 14 days.
  /// Individual timestamped exact alarms ensure notifications fire reliably even
  /// when the app is completely closed/terminated on modern Android.
  Future<void> scheduleMedication(Medication medication) async {
    if (!_ready || medication.id == null) return;
    await cancelMedication(medication.id!);
    if (!medication.isActive) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tzNow = tz.TZDateTime.now(tz.local);

    // Schedule exact occurrences for the upcoming 14 days
    for (var dayOffset = 0; dayOffset < 14; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final dayStr = dateKey(targetDate);

      // Verify medication is scheduled on this specific date (honors start & end dates)
      if (!medication.isScheduledOn(dayStr)) continue;

      for (var timeIndex = 0; timeIndex < medication.times.length && timeIndex < 10; timeIndex++) {
        final hm = parseTime(medication.times[timeIndex]);
        if (hm == null) continue;

        final scheduledTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hm.$1,
          hm.$2,
        );

        // Do not schedule doses that are already in the past
        if (!scheduledTime.isAfter(tzNow)) continue;

        final notificationId = _idFor(medication.id!, dayOffset, timeIndex);

        try {
          await _plugin.zonedSchedule(
            notificationId,
            '💊 Time to take ${medication.name}',
            '${medication.doseLabel}${medication.instructions.isNotEmpty ? ' • ${medication.instructions}' : ''}',
            scheduledTime,
            _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: '${medication.id}|${medication.times[timeIndex]}|$dayStr',
          );
        } catch (e) {
          debugPrint('exactAllowWhileIdle failed ($e), falling back to inexact:');
          try {
            await _plugin.zonedSchedule(
              notificationId,
              '💊 Time to take ${medication.name}',
              '${medication.doseLabel}${medication.instructions.isNotEmpty ? ' • ${medication.instructions}' : ''}',
              scheduledTime,
              _details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: '${medication.id}|${medication.times[timeIndex]}|$dayStr',
            );
          } catch (e2) {
            debugPrint('Failed to schedule alarm: $e2');
          }
        }
      }
    }
  }

  Future<void> rescheduleAll(List<Medication> medications) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    for (final m in medications) {
      await scheduleMedication(m);
    }
  }

  Future<void> cancelMedication(int medicationId) async {
    if (!_ready) return;
    final prefix = (medicationId % 1000) * 1000;
    for (var d = 0; d < 20; d++) {
      for (var t = 0; t < 10; t++) {
        await _plugin.cancel(prefix + (d * 10) + t);
      }
    }
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  Future<void> showTest() async {
    if (!_ready) return;
    await requestPermissions();
    await _plugin.show(
      0,
      '💊 DoseDay Reminder Alert',
      'Your dose notification alerts are working perfectly with sound & vibration!',
      _details,
      payload: 'test_notification',
    );
  }

  // Generates unique 32-bit int IDs for medication, day offset (0..19), and time index (0..9)
  int _idFor(int medicationId, int dayOffset, int timeIndex) =>
      ((medicationId % 1000) * 1000) + (dayOffset * 10) + timeIndex;
}
