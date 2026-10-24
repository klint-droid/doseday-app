import 'package:flutter/material.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _loading = true;
  bool _notificationsEnabled = true;
  List<Medication> _medications = [];
  Map<String, DoseLog> _todayLogs = {};
  UserProfile _profile = const UserProfile();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final enabled = await NotificationService.instance.areNotificationsEnabled();
    final meds = await DatabaseService.instance.getMedications(activeOnly: true);
    final todayKey = dateKey(DateTime.now());
    final logs = await DatabaseService.instance.getLogsForDate(todayKey);
    final profile = await DatabaseService.instance.getUserProfile();

    final logMap = <String, DoseLog>{};
    for (final l in logs) {
      logMap['${l.medicationId}-${l.scheduledTime}'] = l;
    }

    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _medications = meds;
        _todayLogs = logMap;
        _profile = profile;
        _loading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.instance.requestPermissions();
    if (mounted) {
      setState(() => _notificationsEnabled = granted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? '✓ Notifications permission granted!'
                : '⚠️ Notifications disabled. Please allow in device settings.',
          ),
          backgroundColor: granted ? AppColors.mintColor : AppColors.missed,
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showTest();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Test notification sent! Check your notification bar.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _rescheduleAll() async {
    await NotificationService.instance.rescheduleAll(_medications);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Rescheduled alerts for ${_medications.length} active medication(s)',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _toggleSound(bool val) async {
    final updated = _profile.copyWith(soundEnabled: val);
    await DatabaseService.instance.saveUserProfile(updated);
    setState(() => _profile = updated);
  }

  Future<void> _toggleVibration(bool val) async {
    final updated = _profile.copyWith(vibrationEnabled: val);
    await DatabaseService.instance.saveUserProfile(updated);
    setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Flatten all scheduled reminders for today
    final reminderItems = <Map<String, dynamic>>[];
    for (final med in _medications) {
      for (final t in med.times) {
        final key = '${med.id}-$t';
        final log = _todayLogs[key];
        final timeHm = parseTime(t);
        bool isPast = false;
        if (timeHm != null) {
          final reminderDt = DateTime(now.year, now.month, now.day, timeHm.$1, timeHm.$2);
          isPast = now.isAfter(reminderDt);
        }

        reminderItems.add({
          'medication': med,
          'time': t,
          'log': log,
          'isPast': isPast,
        });
      }
    }

    // Sort by scheduled time
    reminderItems.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications & Alerts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Dose reminders and delivery status',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Content body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      // Permission banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled
                              ? const Color(0xFFF0FAF3)
                              : const Color(0xFFFFF8EE),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _notificationsEnabled
                                ? const Color(0xFFBCE7CB)
                                : const Color(0xFFFFE0B2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _notificationsEnabled
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              color: _notificationsEnabled
                                  ? AppColors.mintColor
                                  : const Color(0xFFE67E22),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _notificationsEnabled
                                        ? 'Notifications are Active'
                                        : 'Notification Permission Needed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: _notificationsEnabled
                                          ? const Color(0xFF1E7E34)
                                          : const Color(0xFFB95000),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _notificationsEnabled
                                        ? 'Dose alarms will ring at your scheduled times.'
                                        : 'Allow DoseDay to show notifications on this device.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _notificationsEnabled
                                          ? const Color(0xFF2E633B)
                                          : const Color(0xFF8A5300),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_notificationsEnabled)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _requestPermission,
                                child: const Text(
                                  'Enable',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Quick action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _sendTestNotification,
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text(
                                'Send Test Alert',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _rescheduleAll,
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: const Text(
                                'Sync Alarms',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Scheduled Reminders Section
                      Row(
                        children: [
                          const Text(
                            "Today's Scheduled Reminders",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${reminderItems.length} reminder(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (reminderItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.alarm_off_rounded,
                                size: 40,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'No Scheduled Reminders Today',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add a medication with dose times to receive alerts.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...reminderItems.map((item) {
                          final med = item['medication'] as Medication;
                          final timeStr = item['time'] as String;
                          final DoseLog? log = item['log'] as DoseLog?;
                          final isPast = item['isPast'] as bool;

                          final isTaken = log?.status == DoseStatus.taken;
                          final isMissed = log?.status == DoseStatus.missed || (log == null && isPast);

                          Color badgeBg;
                          Color badgeFg;
                          String statusText;
                          IconData statusIcon;

                          if (isTaken) {
                            badgeBg = const Color(0xFFE8F8EE);
                            badgeFg = AppColors.mintColor;
                            statusText = 'Taken';
                            statusIcon = Icons.check_circle_rounded;
                          } else if (isMissed) {
                            badgeBg = const Color(0xFFFFECEB);
                            badgeFg = AppColors.missed;
                            statusText = 'Missed';
                            statusIcon = Icons.warning_rounded;
                          } else {
                            badgeBg = AppColors.primaryLight;
                            badgeFg = AppColors.primary;
                            statusText = 'Scheduled';
                            statusIcon = Icons.access_time_filled_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTaken
                                    ? const Color(0xFFD6F2DF)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1EDFD),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    formatTime(timeStr),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        med.doseLabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 14, color: badgeFg),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 20),

                      // Notification Preferences
                      const Text(
                        'Alert Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text(
                                'Sound Alert',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              subtitle: const Text(
                                'Play reminder chime on scheduled dose',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                              value: _profile.soundEnabled,
                              activeThumbColor: AppColors.primary,
                              onChanged: _toggleSound,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            SwitchListTile(
                              title: const Text(
                                'Vibrate Phone',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              subtitle: const Text(
                                'Vibrate device when dose is due',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                              value: _profile.vibrationEnabled,
                              activeThumbColor: AppColors.primary,
                              onChanged: _toggleVibration,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
