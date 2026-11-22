import 'dart:async';
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
  Timer? _foregroundMonitorTimer;
  final Set<String> _firedForegroundKeys = <String>{};

  /// Notifier triggered whenever the user taps a notification or action in the system shade
  final ValueNotifier<String?> onNotificationTapped = ValueNotifier<String?>(null);

  static const _channelId = 'doseday_medication_alerts_v7';
  static const _channelName = 'DoseDay Medication Reminders';
  static const _channelDesc = 'High-priority audible & interactive alerts for scheduled medication doses';

  static const _fallbackChannelId = 'doseday_medication_default_v7';
  static const _fallbackChannelName = 'DoseDay Default Sound Reminders';
  static const _fallbackChannelDesc = 'High-priority system sound alerts for scheduled medication doses';

  static const _silentChannelId = 'doseday_medication_silent_v7';
  static const _silentChannelName = 'DoseDay Silent Medication Reminders';
  static const _silentChannelDesc = 'Silent or vibration-only alerts for scheduled medication doses';

  // Action IDs for interactive notification buttons
  static const actionTakeDose = 'take_dose';
  static const actionSnooze10 = 'snooze_10';
  static const actionSkipDose = 'skip_dose';

  Future<NotificationDetails> _buildDetails({
    bool includeActions = true,
    bool useCustomSound = true,
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

    final String activeChannelId = !playSound
        ? _silentChannelId
        : (useCustomSound ? _channelId : _fallbackChannelId);
    final String activeChannelName = !playSound
        ? _silentChannelName
        : (useCustomSound ? _channelName : _fallbackChannelName);
    final String activeChannelDesc = !playSound
        ? _silentChannelDesc
        : (useCustomSound ? _channelDesc : _fallbackChannelDesc);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        activeChannelId,
        activeChannelName,
        channelDescription: activeChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: enableVibration,
        vibrationPattern: enableVibration ? Int64List.fromList([0, 500, 250, 500]) : null,
        playSound: playSound,
        sound: (playSound && useCustomSound)
            ? const RawResourceAndroidNotificationSound('reminder_sound')
            : null,
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
        sound: (playSound && useCustomSound) ? 'reminder_sound.wav' : null,
      ),
    );
  }

  Future<void> _ensureInitialized() async {
    if (!_ready) {
      await initialize();
    }
  }

  /// Sets up time zones, channels, and foreground monitor.
  Future<void> initialize() async {
    if (_ready) return;
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

      _ready = true;

      // Create high-priority Android notification channels
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
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
        } catch (e) {
          debugPrint('Custom sound channel error: $e');
        }

        try {
          final fallbackChannel = AndroidNotificationChannel(
            _fallbackChannelId,
            _fallbackChannelName,
            description: _fallbackChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          );
          await androidPlugin.createNotificationChannel(fallbackChannel);
        } catch (_) {}

        try {
          const silentChannel = AndroidNotificationChannel(
            _silentChannelId,
            _silentChannelName,
            description: _silentChannelDesc,
            importance: Importance.high,
            playSound: false,
            enableVibration: true,
          );
          await androidPlugin.createNotificationChannel(silentChannel);
        } catch (_) {}
      }

      // Check if app was opened by tapping a notification
      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          final response = launchDetails.notificationResponse;
          if (response != null) {
            await _handleNotificationResponse(response);
          }
        }
      } catch (_) {}

      _startForegroundAlarmMonitor();
    } catch (e) {
      debugPrint('Notifications initialization error: $e');
    }
  }

  /// Periodically checks every 10 seconds while the app is running so that any
  /// due dose triggers reliably even on devices that restrict background alarms.
  void _startForegroundAlarmMonitor() {
    _foregroundMonitorTimer?.cancel();
    _foregroundMonitorTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final now = DateTime.now();
        final todayStr = dateKey(now);
        final currentHm = timeKey(now);
        final meds = await DatabaseService.instance.getMedications(activeOnly: true);
        if (meds.isEmpty) return;
        final logs = await DatabaseService.instance.getLogsForDate(todayStr);

        for (final med in meds) {
          if (med.id == null || !med.isScheduledOn(todayStr)) continue;
          for (var i = 0; i < med.times.length; i++) {
            final t = med.times[i];
            if (t == currentHm) {
              final fireKey = '$todayStr-${med.id}-$t';
              if (_firedForegroundKeys.contains(fireKey)) continue;
              _firedForegroundKeys.add(fireKey);

              final alreadyLogged = logs.any(
                (l) => l.medicationId == med.id && l.scheduledTime == t,
              );
              if (!alreadyLogged) {
                final notifId = _idFor(med.id!, 0, i);
                await _safeShow(
                  id: notifId,
                  title: '💊 Time for ${med.name}',
                  body:
                      '${med.doseLabel}${med.instructions.isNotEmpty ? ' • ${med.instructions}' : ''} (${formatTime(t)})',
                  payload: '${med.id}|$t|$todayStr',
                );
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _safeShow({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool includeActions = true,
  }) async {
    await _ensureInitialized();
    try {
      final details = await _buildDetails(
        includeActions: includeActions,
        useCustomSound: true,
      );
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('Custom sound show failed ($e), falling back to default sound:');
      try {
        final fallbackDetails = await _buildDetails(
          includeActions: includeActions,
          useCustomSound: false,
        );
        await _plugin.show(id, title, body, fallbackDetails, payload: payload);
      } catch (e2) {
        debugPrint('Fallback show failed: $e2');
      }
    }
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required String payload,
    bool includeActions = true,
  }) async {
    await _ensureInitialized();

    for (final useCustomSound in [true, false]) {
      final details = await _buildDetails(
        includeActions: includeActions,
        useCustomSound: useCustomSound,
      );
      for (final mode in [
        AndroidScheduleMode.alarmClock,
        AndroidScheduleMode.exactAllowWhileIdle,
        AndroidScheduleMode.inexactAllowWhileIdle,
      ]) {
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledTime,
            details,
            androidScheduleMode: mode,
            payload: payload,
          );
          return; // Successfully scheduled!
        } catch (e) {
          debugPrint('zonedSchedule failed (customSound=$useCustomSound, mode=$mode): $e');
        }
      }
    }
  }

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload ?? '';
    final actionId = response.actionId;
    debugPrint('Notification response: action=$actionId payload=$payload');

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
    await _ensureInitialized();
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
    await _ensureInitialized();
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
    await _ensureInitialized();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> requestPermissions() async {
    await _ensureInitialized();
    bool? granted;
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        granted = await android.requestNotificationsPermission();
      } catch (e) {
        debugPrint('requestNotificationsPermission error: $e');
      }
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
    return granted ?? (await areNotificationsEnabled());
  }

  /// Schedules exact alarms for each active medication dose over the next 14 days.
  Future<void> scheduleMedication(Medication medication) async {
    await _ensureInitialized();
    if (medication.id == null) return;

    final enabled = await areNotificationsEnabled();
    if (!enabled) {
      await requestPermissions();
    }

    await cancelMedication(medication.id!);
    if (!medication.isActive) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tzNow = tz.TZDateTime.now(tz.local);

    for (var dayOffset = 0; dayOffset < 14; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final dayStr = dateKey(targetDate);

      if (!medication.isScheduledOn(dayStr)) continue;

      for (var timeIndex = 0;
          timeIndex < medication.times.length && timeIndex < 10;
          timeIndex++) {
        final hm = parseTime(medication.times[timeIndex]);
        if (hm == null) continue;

        final localTarget = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hm.$1,
          hm.$2,
        );

        final diffSeconds = localTarget.difference(now).inSeconds;

        tz.TZDateTime scheduledTime;
        if (diffSeconds > 0) {
          scheduledTime = tzNow.add(Duration(seconds: diffSeconds));
        } else if (dayOffset == 0 && diffSeconds >= -60) {
          // User scheduled a dose for the current minute! Fire in 3 seconds.
          scheduledTime = tzNow.add(const Duration(seconds: 3));
        } else {
          // Dose time is already in the past for today
          continue;
        }

        final notificationId = _idFor(medication.id!, dayOffset, timeIndex);
        final title = '💊 Time for ${medication.name}';
        final body =
            '${medication.doseLabel}${medication.instructions.isNotEmpty ? ' • ${medication.instructions}' : ''} (${formatTime(medication.times[timeIndex])})';
        final payload = '${medication.id}|${medication.times[timeIndex]}|$dayStr';

        await _safeZonedSchedule(
          id: notificationId,
          title: title,
          body: body,
          scheduledTime: scheduledTime,
          payload: payload,
          includeActions: true,
        );
      }
    }
  }

  /// Schedules a snoozed exact reminder X minutes from now
  Future<void> scheduleSnooze(
    Medication medication,
    String originalTime, {
    int minutes = 10,
  }) async {
    await _ensureInitialized();
    final tzNow = tz.TZDateTime.now(tz.local);
    final snoozeTarget = tzNow.add(Duration(minutes: minutes));
    final todayStr = dateKey(DateTime.now());
    final snoozeId = 900000 + ((medication.id ?? 1) % 9000) * 10 + (minutes % 10);
    final payload = '${medication.id ?? 0}|$originalTime|$todayStr';

    await _safeZonedSchedule(
      id: snoozeId,
      title: '⏰ Snoozed: ${medication.name}',
      body: 'Reminder snoozed for $minutes min • Take ${medication.doseLabel}',
      scheduledTime: snoozeTarget,
      payload: payload,
      includeActions: true,
    );
  }

  /// Checks if a medication's remaining stock is at or below its refill threshold
  /// and fires a proactive refill notification.
  Future<void> checkAndNotifyLowStock(int medicationId) async {
    await _ensureInitialized();
    try {
      final meds = await DatabaseService.instance.getMedications(activeOnly: true);
      final med = meds.where((m) => m.id == medicationId).firstOrNull;
      if (med != null && med.needsRefill) {
        await _safeShow(
          id: 880000 + (med.id! % 10000),
          title: '📦 Low Stock Alert: ${med.name}',
          body:
              'Only ${med.stockQuantity} ${med.dosageUnit} left (refill threshold: ${med.refillThreshold}). Tap to restock soon!',
          payload: 'refill|${med.id}',
          includeActions: false,
        );
      }
    } catch (_) {}
  }

  Future<void> rescheduleAll(List<Medication> medications) async {
    await _ensureInitialized();
    await _plugin.cancelAll();
    for (final m in medications) {
      await scheduleMedication(m);
    }
  }

  Future<void> cancelMedication(int medicationId) async {
    await _ensureInitialized();
    final prefix = (medicationId % 1000) * 1000;
    for (var d = 0; d < 20; d++) {
      for (var t = 0; t < 10; t++) {
        await _plugin.cancel(prefix + (d * 10) + t);
      }
    }
  }

  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  Future<void> showTest() async {
    await _ensureInitialized();
    await requestPermissions();
    await _safeShow(
      id: 0,
      title: '💊 DoseDay Smart Reminder',
      body: 'Audible chime, vibration & quick actions (Take / Snooze / Skip) are active!',
      payload: 'test_notification',
      includeActions: true,
    );
  }

  /// Schedules an exact alarm 5 seconds in the future so the user can lock
  /// their screen or close the app and verify background alarm delivery.
  Future<void> scheduleDelayedTest({int seconds = 5}) async {
    await _ensureInitialized();
    await requestPermissions();
    final target = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _safeZonedSchedule(
      id: 999991,
      title: '🔔 Closed-App Exact Alarm Test',
      body: 'Success! Your device woke up on time after $seconds seconds.',
      scheduledTime: target,
      payload: 'test_delayed_alarm',
      includeActions: true,
    );
  }

  int _idFor(int medicationId, int dayOffset, int timeIndex) =>
      ((medicationId % 1000) * 1000) + (dayOffset * 10) + timeIndex;
}
