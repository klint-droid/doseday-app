import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _exactAlarmsEnabled = true;
  int _pendingAlarmCount = 0;
  String _selectedTab = 'All'; // All, Due, Upcoming, Taken, Refills
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
    final exact = await NotificationService.instance.canScheduleExactAlarms();
    final pendingCount = await NotificationService.instance.getPendingNotificationCount();
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
        _exactAlarmsEnabled = exact;
        _pendingAlarmCount = pendingCount;
        _medications = meds;
        _todayLogs = logMap;
        _profile = profile;
        _loading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.instance.requestPermissions();
    final exact = await NotificationService.instance.canScheduleExactAlarms();
    if (mounted) {
      setState(() {
        _notificationsEnabled = granted;
        _exactAlarmsEnabled = exact;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? '✓ Notifications & exact alarm permissions granted!'
                : '⚠️ Notifications disabled. Please allow in device settings.',
          ),
          backgroundColor: granted ? AppColors.primary : AppColors.missed,
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showTest();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Test alert sent with Take / Snooze / Skip actions!'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _sendDelayedTest() async {
    await NotificationService.instance.scheduleDelayedTest(seconds: 5);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Alarm scheduled for 5s from now! Lock your phone to test.'),
          backgroundColor: AppColors.primaryDark,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _rescheduleAll() async {
    await NotificationService.instance.rescheduleAll(_medications);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Synced $_pendingAlarmCount exact alarms across ${_medications.length} medicine(s)',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _recordDoseAction(Medication med, String timeStr, String status) async {
    final todayKey = dateKey(DateTime.now());
    await DatabaseService.instance.recordDose(
      medication: med,
      date: todayKey,
      time: timeStr,
      status: status,
    );
    if (status == DoseStatus.taken && med.id != null) {
      await NotificationService.instance.checkAndNotifyLowStock(med.id!);
    }
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${med.name} (${formatTime(timeStr)}) marked as $status'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _snoozeReminder(Medication med, String timeStr, int minutes) async {
    await NotificationService.instance.scheduleSnooze(med, timeStr, minutes: minutes);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ Snoozed ${med.name} for $minutes minutes'),
          backgroundColor: AppColors.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _quickRestock(Medication med) async {
    if (med.id == null) return;
    await DatabaseService.instance.addRefill(med.id!, 30);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📦 Added +30 ${med.dosageUnit} to ${med.name}'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _toggleSound(bool val) async {
    final updated = _profile.copyWith(soundEnabled: val);
    await DatabaseService.instance.saveUserProfile(updated);
    setState(() => _profile = updated);
    await NotificationService.instance.rescheduleAll(_medications);
  }

  Future<void> _toggleVibration(bool val) async {
    final updated = _profile.copyWith(vibrationEnabled: val);
    await DatabaseService.instance.saveUserProfile(updated);
    setState(() => _profile = updated);
    await NotificationService.instance.rescheduleAll(_medications);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = dateKey(now);

    final reminderItems = <Map<String, dynamic>>[];
    for (final med in _medications) {
      if (!med.isScheduledOn(todayStr)) continue;
      for (final t in med.times) {
        final key = '${med.id}-$t';
        final log = _todayLogs[key];
        final timeHm = parseTime(t);
        bool isPast = false;
        int minutesDiff = 0;
        if (timeHm != null) {
          final reminderDt = DateTime(now.year, now.month, now.day, timeHm.$1, timeHm.$2);
          isPast = now.isAfter(reminderDt);
          minutesDiff = reminderDt.difference(now).inMinutes;
        }

        final isTaken = log?.status == DoseStatus.taken;
        final isSkipped = log?.status == DoseStatus.skipped;
        final isDue = !isTaken && !isSkipped && isPast;

        reminderItems.add({
          'medication': med,
          'time': t,
          'log': log,
          'isPast': isPast,
          'isTaken': isTaken,
          'isSkipped': isSkipped,
          'isDue': isDue,
          'minutesDiff': minutesDiff,
        });
      }
    }

    reminderItems.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

    final lowStockMeds = _medications.where((m) => m.needsRefill).toList();

    final filteredItems = reminderItems.where((item) {
      if (_selectedTab == 'All') return true;
      if (_selectedTab == 'Due') return item['isDue'] == true;
      if (_selectedTab == 'Upcoming') {
        return item['isTaken'] == false && item['isSkipped'] == false && item['isDue'] == false;
      }
      if (_selectedTab == 'Taken') return item['isTaken'] == true;
      return true;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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

          // Tarsi-style Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification & Alarm Center',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_pendingAlarmCount active OS alarms • Interactive actions',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      // System Diagnostics & Permission Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled
                              ? const Color(0xFFE9F7EF)
                              : const Color(0xFFFFF4E8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _notificationsEnabled
                                ? const Color(0xFFB8E6C9)
                                : const Color(0xFFFFD8A8),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _notificationsEnabled
                                        ? Icons.verified_rounded
                                        : Icons.warning_amber_rounded,
                                    color: _notificationsEnabled
                                        ? AppColors.primary
                                        : AppColors.amberColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _notificationsEnabled
                                            ? 'Exact Closed-App Alarms Ready'
                                            : 'Notification Permission Required',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _notificationsEnabled
                                            ? 'Alarms ring with custom chime & Take/Snooze buttons even when closed.'
                                            : 'Grant permission so DoseDay can wake your device on time.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_notificationsEnabled || !_exactAlarmsEnabled)
                                  FilledButton(
                                    onPressed: _requestPermission,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text('Enable'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Status badges row
                            Row(
                              children: [
                                _diagPill(
                                  icon: Icons.notifications_rounded,
                                  label: _notificationsEnabled ? 'Alerts: ON' : 'Alerts: OFF',
                                  ok: _notificationsEnabled,
                                ),
                                const SizedBox(width: 8),
                                _diagPill(
                                  icon: Icons.alarm_on_rounded,
                                  label: _exactAlarmsEnabled ? 'Exact Alarm: ON' : 'Exact: Check',
                                  ok: _exactAlarmsEnabled,
                                ),
                                const SizedBox(width: 8),
                                _diagPill(
                                  icon: Icons.schedule_rounded,
                                  label: '$_pendingAlarmCount Queued',
                                  ok: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Quick Test & Sync Action Row
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _sendTestNotification,
                              icon: const Icon(Icons.notifications_active_rounded, size: 17),
                              label: const Text(
                                'Instant Test',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryContainer,
                                foregroundColor: AppColors.primaryDark,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _sendDelayedTest,
                              icon: const Icon(Icons.timer_outlined, size: 17),
                              label: const Text(
                                '5s Lock Test',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Sync All Alarms',
                            onPressed: _rescheduleAll,
                            style: IconButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
                          ),
                        ],
                      ),

                      // Low Stock Alerts Banner if any
                      if (lowStockMeds.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(
                              Icons.inventory_2_rounded,
                              size: 18,
                              color: AppColors.overdueText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Refill Alerts (${lowStockMeds.length})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...lowStockMeds.map(
                          (m) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.overdueBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${m.name} is running low',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: AppColors.overdueText,
                                        ),
                                      ),
                                      Text(
                                        '${m.stockQuantity} ${m.dosageUnit} left (Alert threshold: ${m.refillThreshold})',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _quickRestock(m),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text(
                                    '+30 Stock',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Filter Tabs for Today's Reminders
                      Row(
                        children: [
                          Text(
                            "Today's Dose Queue",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${reminderItems.length} total',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Due', 'Upcoming', 'Taken'].map((tab) {
                            final active = _selectedTab == tab;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(tab),
                                selected: active,
                                onSelected: (_) => setState(() => _selectedTab = tab),
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                labelStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : AppColors.text,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: active ? AppColors.primary : AppColors.border,
                                  ),
                                ),
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (filteredItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.notifications_paused_rounded,
                                size: 38,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No reminders in "$_selectedTab"',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All scheduled medication alerts for this filter are clear.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredItems.map((item) {
                          final med = item['medication'] as Medication;
                          final timeStr = item['time'] as String;
                          final isTaken = item['isTaken'] as bool;
                          final isSkipped = item['isSkipped'] as bool;
                          final isDue = item['isDue'] as bool;
                          final minutesDiff = item['minutesDiff'] as int;

                          Color badgeBg;
                          Color badgeFg;
                          String statusText;

                          if (isTaken) {
                            badgeBg = AppColors.mintBg;
                            badgeFg = AppColors.mintColor;
                            statusText = 'Taken ✓';
                          } else if (isSkipped) {
                            badgeBg = AppColors.yellowBg;
                            badgeFg = AppColors.amberColor;
                            statusText = 'Skipped';
                          } else if (isDue) {
                            badgeBg = AppColors.overdueBg;
                            badgeFg = AppColors.overdueText;
                            final minsLate = minutesDiff.abs();
                            statusText = minsLate < 60
                                ? '${minsLate}m overdue'
                                : '${(minsLate / 60).floor()}h overdue';
                          } else {
                            badgeBg = AppColors.primaryContainer;
                            badgeFg = AppColors.primary;
                            statusText = minutesDiff <= 60
                                ? 'In ${minutesDiff}m'
                                : 'In ${(minutesDiff / 60).round()}h';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDue
                                    ? AppColors.overdueText.withValues(alpha: 0.35)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDue
                                            ? AppColors.overdueBg
                                            : AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        formatTime(timeStr),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12.5,
                                          color: isDue
                                              ? AppColors.overdueText
                                              : AppColors.primary,
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
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          Text(
                                            '${med.doseLabel}${med.instructions.isNotEmpty ? ' • ${med.instructions}' : ''}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isTaken) ...[
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: AppColors.borderLight),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _actionChip(
                                        icon: Icons.check_rounded,
                                        label: 'Take Now',
                                        bg: AppColors.primary,
                                        fg: Colors.white,
                                        onTap: () => _recordDoseAction(
                                          med,
                                          timeStr,
                                          DoseStatus.taken,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _actionChip(
                                        icon: Icons.snooze_rounded,
                                        label: 'Snooze 10m',
                                        bg: AppColors.primaryContainer,
                                        fg: AppColors.primaryDark,
                                        onTap: () => _snoozeReminder(med, timeStr, 10),
                                      ),
                                      const SizedBox(width: 8),
                                      _actionChip(
                                        icon: Icons.close_rounded,
                                        label: 'Skip',
                                        bg: AppColors.surfaceSubtle,
                                        fg: AppColors.textMuted,
                                        onTap: () => _recordDoseAction(
                                          med,
                                          timeStr,
                                          DoseStatus.skipped,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 22),

                      // Notification Preferences
                      Text(
                        'Alarm Sound & Haptics',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
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
                              title: Text(
                                'Custom Soothing Chime',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Play 44.1kHz audible alarm when a dose is due',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              value: _profile.soundEnabled,
                              activeThumbColor: AppColors.primary,
                              onChanged: _toggleSound,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            SwitchListTile(
                              title: Text(
                                'Haptic Vibration Pattern',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Double-pulse vibration when reminder triggers',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
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

  Widget _diagPill({required IconData icon, required String label, required bool ok}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: ok ? AppColors.primary : AppColors.amberColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
