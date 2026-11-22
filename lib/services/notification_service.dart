import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../utils/formatters.dart';
import 'database_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Notifier triggered whenever the user taps a notification or action in the system shade
  final ValueNotifier<String?> onNotificationTapped = ValueNotifier<String?>(null);

  static const _channelId = 'doseday_medication_alerts_v6';
  static const _channelName = 'DoseDay Medication Reminders';
  static const _channelDesc = 'High-priority audible & interactive alerts for scheduled medication doses';

  static const _silentChannelId = 'doseday_medication_silent_v6';
  static const _silentChannelName = 'DoseDay Silent Medication Reminders';
  static const _silentChannelDesc = 'Silent or vibration-only alerts for scheduled medication doses';

  // Action IDs for interactive notification buttons
  static const actionTakeDose = 'take_dose';
  static const actionSnooze10 = 'snooze_10';
  static const actionSkipDose = 'skip_dose';

  Future<NotificationDetails> _buildDetails({
    bool includeActions = true,
    bool? overrideSound,
    bool? overrideVibration,
  }) async {
    bool playSound = true;
    bool enableVibration = true;
    try {
      final profile = await DatabaseService.instance.getUserProfile();
      playSound = overrideSound ?? profile.soundEnabled;
      enableVibration = overrideVibration ?? profile.vibrationEnabled;
    } catch (_) {}

    final actions = includeActions
        ? <AndroidNotificationAction>[
            const AndroidNotificationAction(
              actionTakeDose,
              '✓ Take Dose',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              actionSnooze10,
              '⏰ Snooze 10m',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              actionSkipDose,
              '✕ Skip',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ]
        : null;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        playSound ? _channelId : _silentChannelId,
        playSound ? _channelName : _silentChannelName,
        channelDescription: playSound ? _channelDesc : _silentChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: enableVibration,
        vibrationPattern: enableVibration ? Int64List.fromList([0, 500, 250, 500]) : null,
        playSound: playSound,
        sound: playSound ? const RawResourceAndroidNotificationSound('reminder_sound') : null,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        actions: actions,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        sound: playSound ? 'reminder_sound.wav' : null,
      ),
    );
  }

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
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Create high-priority Android notification channels
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        for (final oldId in [
          'medication_reminders',
          'medication_reminders_sound_v1',
          'medication_reminders_sound_v2',
          'medication_reminders_alarm_v2',
          'medication_reminders_alarm_v3',
          'medication_reminders_alarm_v4',
          'doseday_medication_alerts_v5',
        ]) {
          try {
            await androidPlugin.deleteNotificationChannel(oldId);
          } catch (_) {}
        }

        final audibleChannel = AndroidNotificationChannel(
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
        await androidPlugin.createNotificationChannel(audibleChannel);

        const silentChannel = AndroidNotificationChannel(
          _silentChannelId,
          _silentChannelName,
          description: _silentChannelDesc,
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(silentChannel);
      }

      // Check if app was opened by tapping a notification
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final response = launchDetails.notificationResponse;
        if (response != null) {
          await _handleNotificationResponse(response);
        }
      }

      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload ?? '';
    final actionId = response.actionId;
    debugPrint('Notification response: action=$actionId payload=$payload');

    // Parse payload format: "medicationId|HH:mm|yyyy-MM-dd"
    final parts = payload.split('|');
    if (parts.length >= 3) {
      final medId = int.tryParse(parts[0]);
      final timeStr = parts[1];
      final dateStr = parts[2];

      if (medId != null) {
        try {
          final meds = await DatabaseService.instance.getMedications();
          final med = meds.where((m) => m.id == medId).firstOrNull;
          if (med != null) {
            if (actionId == actionTakeDose) {
              await DatabaseService.instance.recordDose(
                medication: med,
                date: dateStr,
                time: timeStr,
                status: DoseStatus.taken,
              );
              await checkAndNotifyLowStock(med.id!);
              onNotificationTapped.value = 'taken|${med.name}|$timeStr';
              return;
            } else if (actionId == actionSkipDose) {
              await DatabaseService.instance.recordDose(
                medication: med,
                date: dateStr,
                time: timeStr,
                status: DoseStatus.skipped,
              );
              onNotificationTapped.value = 'skipped|${med.name}|$timeStr';
              return;
            } else if (actionId == actionSnooze10) {
              await scheduleSnooze(med, timeStr, minutes: 10);
              onNotificationTapped.value = 'snoozed|${med.name}|10';
              return;
            }
          }
        } catch (e) {
          debugPrint('Action handling failed: $e');
        }
      }
    }

    onNotificationTapped.value = payload.isNotEmpty ? payload : 'tapped';
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_ready) return false;
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        return enabled ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!_ready) return false;
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final canExact = await android.canScheduleExactNotifications();
        return canExact ?? true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<int> getPendingNotificationCount() async {
    if (!_ready) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_ready) return false;
    bool? granted;
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
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
  Future<void> scheduleMedication(Medication medication) async {
    if (!_ready || medication.id == null) return;
    await cancelMedication(medication.id!);
    if (!medication.isActive) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tzNow = tz.TZDateTime.now(tz.local);
    final details = await _buildDetails(includeActions: true);

    for (var dayOffset = 0; dayOffset < 14; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final dayStr = dateKey(targetDate);

      if (!medication.isScheduledOn(dayStr)) continue;

      for (var timeIndex = 0;
          timeIndex < medication.times.length && timeIndex < 10;
          timeIndex++) {
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

        if (!scheduledTime.isAfter(tzNow)) continue;

        final notificationId = _idFor(medication.id!, dayOffset, timeIndex);
        final title = '💊 Time for ${medication.name}';
        final body =
            '${medication.doseLabel}${medication.instructions.isNotEmpty ? ' • ${medication.instructions}' : ''} (${formatTime(medication.times[timeIndex])})';
        final payload = '${medication.id}|${medication.times[timeIndex]}|$dayStr';

        try {
          await _plugin.zonedSchedule(
            notificationId,
            title,
            body,
            scheduledTime,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
        } catch (e) {
          try {
            await _plugin.zonedSchedule(
              notificationId,
              title,
              body,
              scheduledTime,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: payload,
            );
          } catch (e2) {
            debugPrint('Failed to schedule alarm: $e2');
          }
        }
      }
    }
  }

  /// Schedules a snoozed exact reminder X minutes from now
  Future<void> scheduleSnooze(
    Medication medication,
    String originalTime, {
    int minutes = 10,
  }) async {
    if (!_ready) return;
    final tzNow = tz.TZDateTime.now(tz.local);
    final snoozeTarget = tzNow.add(Duration(minutes: minutes));
    final todayStr = dateKey(DateTime.now());
    final snoozeId = 900000 + ((medication.id ?? 1) % 9000) * 10 + (minutes % 10);
    final details = await _buildDetails(includeActions: true);
    final payload = '${medication.id ?? 0}|$originalTime|$todayStr';

    try {
      await _plugin.zonedSchedule(
        snoozeId,
        '⏰ Snoozed: ${medication.name}',
        'Reminder snoozed for $minutes min • Take ${medication.doseLabel}',
        snoozeTarget,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          snoozeId,
          '⏰ Snoozed: ${medication.name}',
          'Reminder snoozed for $minutes min • Take ${medication.doseLabel}',
          snoozeTarget,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  /// Checks if a medication's remaining stock is at or below its refill threshold
  /// and fires a proactive refill notification.
  Future<void> checkAndNotifyLowStock(int medicationId) async {
    if (!_ready) return;
    try {
      final meds = await DatabaseService.instance.getMedications(activeOnly: true);
      final med = meds.where((m) => m.id == medicationId).firstOrNull;
      if (med != null && med.needsRefill) {
        final details = await _buildDetails(includeActions: false);
        await _plugin.show(
          880000 + (med.id! % 10000),
          '📦 Low Stock Alert: ${med.name}',
          'Only ${med.stockQuantity} ${med.dosageUnit} left (refill threshold: ${med.refillThreshold}). Tap to restock soon!',
          details,
          payload: 'refill|${med.id}',
        );
      }
    } catch (_) {}
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
    final details = await _buildDetails(includeActions: true);
    await _plugin.show(
      0,
      '💊 DoseDay Smart Reminder',
      'Audible chime, vibration & quick actions (Take / Snooze / Skip) are active!',
      details,
      payload: 'test_notification',
    );
  }

  /// Schedules an exact alarm 5 seconds in the future so the user can lock
  /// their screen or close the app and verify background alarm delivery.
  Future<void> scheduleDelayedTest({int seconds = 5}) async {
    if (!_ready) return;
    await requestPermissions();
    final details = await _buildDetails(includeActions: true);
    final target = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    try {
      await _plugin.zonedSchedule(
        999991,
        '🔔 Closed-App Exact Alarm Test',
        'Success! Your device woke up on time after $seconds seconds.',
        target,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'test_delayed_alarm',
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        999991,
        '🔔 Closed-App Exact Alarm Test',
        'Success! Your device triggered the scheduled alarm after $seconds seconds.',
        target,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'test_delayed_alarm',
      );
    }
  }

  int _idFor(int medicationId, int dayOffset, int timeIndex) =>
      ((medicationId % 1000) * 1000) + (dayOffset * 10) + timeIndex;
}
