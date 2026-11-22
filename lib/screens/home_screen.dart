import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/notifications_sheet.dart';
import 'medication_form.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

typedef _Slot = ({Medication med, String time});

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenMedications,
    required this.onOpenHistory,
    required this.onAddMedication,
  });

  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenMedications;
  final VoidCallback onOpenHistory;
  final VoidCallback onAddMedication;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;
  UserProfile? _profile;
  List<Medication> _medications = [];
  List<DoseLog> _todayLogs = [];
  List<DoseLog> _allLogs = [];
  int _refillCount = 0;
  String _selectedPeriod = 'Day'; // Day, Week, Month

  @override
  void initState() {
    super.initState();
    _db.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _db.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await _db.markPastDosesMissed();
    final profile = await _db.getUserProfile();
    final meds = await _db.getMedications(activeOnly: true);
    final todayLogs = await _db.getLogsForDate(dateKey(DateTime.now()));
    final allLogs = await _db.getAllLogs();
    final refill = await _db.getRefillCount();
    if (mounted) {
      setState(() {
        _profile = profile;
        _medications = meds;
        _todayLogs = todayLogs;
        _allLogs = allLogs;
        _refillCount = refill;
      });
    }
  }

  DoseLog? _logFor(_Slot s) => _todayLogs
      .where((l) => l.medicationId == s.med.id && l.scheduledTime == s.time)
      .firstOrNull;

  int _computeStreakDays() {
    if (_allLogs.isEmpty) return 0;
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final d = dateKey(DateTime(now.year, now.month, now.day - i));
      final dayLogs = _allLogs.where((l) => l.scheduledDate == d).toList();
      if (dayLogs.isEmpty) {
        if (i == 0) continue;
        break;
      }
      final anyTaken = dayLogs.any((l) => l.status == DoseStatus.taken);
      if (anyTaken) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, ';
    if (hour < 18) return 'Good afternoon, ';
    return 'Good evening, ';
  }

  String _firstName() {
    final raw = _profile?.name.trim() ?? '';
    if (raw.isEmpty) {
      return 'there';
    }
    return raw.split(' ').first;
  }

  String _formattedHeaderDate(DateTime d) {
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  Future<void> _quickMarkDose(_Slot s, String status) async {
    final today = dateKey(DateTime.now());
    await _db.recordDose(
      medication: s.med,
      date: today,
      time: s.time,
      status: status,
    );
    if (status == DoseStatus.taken && s.med.id != null) {
      await NotificationService.instance.checkAndNotifyLowStock(s.med.id!);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('✓ ${s.med.name} (${formatTime(s.time)}) marked as $status'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// "Talk to DoseDay" natural-language quick logger inspired by "Talk to Tarsi"
  Future<void> _showTalkToDoseDaySheet() async {
    final controller = TextEditingController();
    final presets = [
      'Amoxicillin 500mg 08:00',
      'Vitamin D3 1000IU 09:00',
      'Losartan 50mg 20:00',
      'Metformin 500mg 12:30',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      'assets/images/mascot_3d_bird.png',
                      errorBuilder: (_, _, _) => Image.asset('assets/images/app_logo.png'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Talk to DoseDay AI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Type a medicine & time to add it in seconds',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. "Amoxicillin 500mg 08:00" or "Vitamin C 1 tab"',
                  prefixIcon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                  fillColor: AppColors.surfaceSubtle,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Try quick examples:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets
                    .map(
                      (p) => ActionChip(
                        label: Text(
                          p,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        backgroundColor: AppColors.primaryContainer,
                        side: BorderSide.none,
                        onPressed: () => controller.text = p,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async {
                    final raw = controller.text.trim();
                    if (raw.isEmpty) return;
                    Navigator.pop(ctx);
                    await _parseAndSaveQuickMed(raw);
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Instant Add & Schedule Alarm'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _parseAndSaveQuickMed(String input) async {
    // Parse time like "08:00" or "8am" or "20:00"
    String parsedTime = '08:00';
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(input);
    if (timeMatch != null) {
      final h = int.tryParse(timeMatch.group(1)!) ?? 8;
      final m = int.tryParse(timeMatch.group(2)!) ?? 0;
      parsedTime = '${h.clamp(0, 23).toString().padLeft(2, '0')}:${m.clamp(0, 59).toString().padLeft(2, '0')}';
    }

    // Parse dosage like "500mg" or "1 tab"
    String dosage = '1';
    String unit = 'tablet(s)';
    final doseMatch = RegExp(r'(\d+)\s*(mg|ml|tab|cap|IU)', caseSensitive: false).firstMatch(input);
    if (doseMatch != null) {
      dosage = doseMatch.group(1)!;
      final u = doseMatch.group(2)!.toLowerCase();
      if (u == 'mg') unit = 'mg';
      if (u == 'ml') unit = 'mL';
      if (u.startsWith('cap')) unit = 'capsule(s)';
    }

    // Clean name
    String name = input
        .replaceAll(RegExp(r'\d{1,2}:\d{2}'), '')
        .replaceAll(RegExp(r'\d+\s*(mg|ml|tab|tablet|cap|IU)', caseSensitive: false), '')
        .trim();
    if (name.isEmpty) name = input;

    final med = Medication(
      name: name,
      dosage: dosage,
      dosageUnit: unit,
      instructions: 'Logged via Talk to DoseDay',
      startDate: dateKey(DateTime.now()),
      stockQuantity: 30,
      refillThreshold: 5,
      times: [parsedTime],
    );
    final saved = await _db.saveMedication(med);
    await NotificationService.instance.scheduleMedication(saved);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Added ${saved.name} (${saved.doseLabel}) at ${formatTime(parsedTime)}'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _showDoseActionSheet(_Slot s) {
    final log = _logFor(s);
    final isTaken = log?.status == DoseStatus.taken;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.med.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        '${s.med.doseLabel} • Scheduled for ${formatTime(s.time)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _quickMarkDose(
                        s,
                        isTaken ? DoseStatus.skipped : DoseStatus.taken,
                      );
                    },
                    icon: Icon(isTaken ? Icons.undo_rounded : Icons.check_circle_rounded),
                    label: Text(isTaken ? 'Mark Skipped' : 'Take Dose Now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await NotificationService.instance.scheduleSnooze(
                        s.med,
                        s.time,
                        minutes: 10,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⏰ Snoozed ${s.med.name} for 10 minutes'),
                            backgroundColor: AppColors.primaryDark,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.snooze_rounded),
                    label: const Text('Snooze 10m'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showMedicationForm(context, medication: s.med);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Medication Details & Stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dateKey(now);
    final nowTime = timeKey(now);

    final slots = <_Slot>[
      for (final m in _medications)
        if (m.isScheduledOn(today))
          for (final t in m.times) (med: m, time: t),
    ]..sort((a, b) => a.time.compareTo(b.time));

    final takenCount = slots.where((s) => _logFor(s)?.status == DoseStatus.taken).length;
    final skippedCount = slots.where((s) => _logFor(s)?.status == DoseStatus.skipped).length;
    final totalCount = slots.length;
    final overdueSlots = slots
        .where((s) => _logFor(s) == null && s.time.compareTo(nowTime) <= 0)
        .toList();
    final pendingCount = totalCount - takenCount - skippedCount;

    // Percentages for the Donut Chart Card (0% when empty)
    final int takenPct = totalCount == 0 ? 0 : ((takenCount / totalCount) * 100).round();
    final int pendingPct = totalCount == 0 ? 0 : ((pendingCount / totalCount) * 100).round();
    final int skippedPct = totalCount == 0 ? 0 : (100 - takenPct - pendingPct).clamp(0, 100);

    final streakDays = _computeStreakDays();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            // 1. Scenic Nature Header with 3D Bird Mascot, Speech Bubble, Streak & Action Capsule
            _buildScenicTarsiHeader(
              now: now,
              streakDays: streakDays,
              overdueCount: overdueSlots.length,
              takenCount: takenCount,
              totalCount: totalCount,
            ),

            // 2. Crisp Dashboard Body below Scenic Header
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions row
                  _buildQuickActionsSection(),

                  const SizedBox(height: 18),

                  // Side-by-Side Bento Summary Cards (Donut Breakdown + Today Day/Week/Month Card)
                  _buildBentoSummaryRow(
                    takenPct: takenPct,
                    pendingPct: pendingPct,
                    skippedPct: skippedPct,
                    takenCount: takenCount,
                    totalCount: totalCount,
                  ),

                  if (_refillCount > 0) ...[
                    const SizedBox(height: 16),
                    _buildRefillBanner(),
                  ],

                  const SizedBox(height: 24),

                  // "Doses due" Section
                  _buildDosesDueSection(
                    slots: slots,
                    now: now,
                    nowTime: nowTime,
                    takenCount: takenCount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the exact Tarsi Scenic Header (Top streak flame badge, notification/people/settings pill,
  /// Date & "Good morning, Bryl!" greeting, Mascot on the left, White speech bubble on the right)
  Widget _buildScenicTarsiHeader({
    required DateTime now,
    required int streakDays,
    required int overdueCount,
    required int takenCount,
    required int totalCount,
  }) {
    String assistantMessage;
    if (overdueCount > 0) {
      assistantMessage =
          "You have $overdueCount dose${overdueCount == 1 ? '' : 's'} due right now. Let's take a look and log them to keep your streak going!";
    } else if (_refillCount > 0) {
      assistantMessage =
          "You've gone low on stock for $_refillCount medicine${_refillCount == 1 ? '' : 's'} this week. Let's check your cabinet before running out.";
    } else if (totalCount > 0) {
      assistantMessage =
          "You've completed $takenCount of $totalCount scheduled doses today. Tap here to review your daily timeline.";
    } else {
      assistantMessage =
          "Your medication schedule is empty. Tap the + button below or tap here to add your first reminder!";
    }

    return SizedBox(
      height: 332,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 1. Scenic Rice Terraces / Green Hills Background Illustration
          Positioned.fill(
            child: CustomPaint(
              painter: _ScenicNatureBannerPainter(),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/images/scenic_header_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomRight,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          // 2. Top Bar + Date & Greeting inside SafeArea
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar: Streak Flame Circle (left) + Bell / Caregiver / Settings Capsule (right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Streak Flame Circle with Orange Number Badge
                      GestureDetector(
                        onTap: widget.onOpenHistory,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD6E3DA),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Color(0xFFFF6B2C),
                                  size: 26,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Text(
                                  '$streakDays',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right Capsule Pill: Bell + People (Profile) + Settings Gear
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFD4E2D9),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Notifications & Alarms',
                              onPressed: () => NotificationsSheet.show(context),
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    Icons.notifications_none_rounded,
                                    color: AppColors.primary,
                                    size: 23,
                                  ),
                                  if (overdueCount > 0 || _refillCount > 0)
                                    Positioned(
                                      top: 1,
                                      right: 1,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEA580C),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Profile & Caregiver',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              ),
                              icon: const Icon(
                                Icons.people_outline_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Settings',
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: AppColors.background,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                                ),
                                builder: (_) => const SizedBox(
                                  height: 620,
                                  child: SettingsScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Uppercase Date String (e.g. THURSDAY, SEPTEMBER 17)
                  Text(
                    _formattedHeaderDate(now),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: const Color(0xFF1F3528),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Greeting Headline: "Good morning, Bryl!"
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        color: const Color(0xFF13261B),
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: _greetingPrefix(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: '${_firstName()}!',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Full-Bodied 3D Owl Bird Mascot standing flush at bottom-left of Scenic Header
          Positioned(
            left: 8,
            bottom: -4,
            child: GestureDetector(
              onTap: _showTalkToDoseDaySheet,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.94, end: 1.0),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
                child: SizedBox(
                  width: 138,
                  height: 158,
                  child: Image.asset(
                    'assets/images/mascot_3d_bird.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. White Speech Bubble Card on the right of the 3D Bird Mascot
          Positioned(
            left: 138,
            right: 18,
            bottom: 18,
            child: GestureDetector(
              onTap: overdueCount > 0
                  ? widget.onOpenSchedule
                  : (_refillCount > 0
                      ? widget.onOpenMedications
                      : _showTalkToDoseDaySheet),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Left Speech Tail Triangle pointing at the 3D Bird
                  Positioned(
                    left: -9,
                    bottom: 22,
                    child: CustomPaint(
                      size: const Size(12, 16),
                      painter: _SpeechTailPainter(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF18281F).withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DoseDay',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assistantMessage,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            height: 1.38,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF4A5950),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// GCash + Tarsi "Quick actions" horizontal squircle icon grid
  Widget _buildQuickActionsSection() {
    final actions = [
      (
        label: 'Log Dose',
        icon: Icons.fact_check_outlined,
        onTap: widget.onOpenSchedule,
      ),
      (
        label: 'Cabinet',
        icon: Icons.pie_chart_outline_rounded,
        onTap: widget.onOpenMedications,
      ),
      (
        label: 'Goals',
        icon: Icons.flag_outlined,
        onTap: widget.onOpenHistory,
      ),
      (
        label: 'Refills',
        icon: Icons.receipt_long_outlined,
        onTap: widget.onOpenMedications,
      ),
      (
        label: 'Planned',
        icon: Icons.event_available_outlined,
        onTap: widget.onOpenSchedule,
      ),
      (
        label: 'Talk AI',
        icon: Icons.chat_bubble_outline_rounded,
        onTap: _showTalkToDoseDaySheet,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick actions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
            InkWell(
              onTap: widget.onAddMedication,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.edit_outlined,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final a = actions[i];
              return GestureDetector(
                onTap: a.onTap,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderLight, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.025),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          a.icon,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Two Side-by-Side Bento Summary Cards matching the Tarsi screenshot:
  /// Left: Multi-segment Donut Breakdown (`95%` + legend + `Tap to view breakdown >`)
  /// Right: `Today` Card with upward green metric, downward dark metric, and `Day | Week | Month` toggle
  Widget _buildBentoSummaryRow({
    required int takenPct,
    required int pendingPct,
    required int skippedPct,
    required int takenCount,
    required int totalCount,
  }) {
    // Compute metrics for Day / Week / Month (0 when empty)
    final displayTaken = _selectedPeriod == 'Day'
        ? takenCount
        : _selectedPeriod == 'Week'
            ? _allLogs.where((l) => l.status == DoseStatus.taken).take(7).length
            : _allLogs.where((l) => l.status == DoseStatus.taken).length;
    final totalStock = _medications.fold<int>(0, (sum, m) => sum + m.stockQuantity);
    final periodTitle = _selectedPeriod == 'Day'
        ? 'Today'
        : _selectedPeriod == 'Week'
            ? 'This Week'
            : 'This Month';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Card: Donut Breakdown Card
        Expanded(
          child: GestureDetector(
            onTap: widget.onOpenHistory,
            child: Container(
              height: 170,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Tarsi Pink/Amber/Blue Multi-Segment Donut Chart
                      SizedBox(
                        width: 78,
                        height: 78,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(78, 78),
                              painter: _TarsiDonutPainter(
                                primaryPct: takenPct / 100.0,
                                secondaryPct: pendingPct / 100.0,
                                tertiaryPct: skippedPct / 100.0,
                              ),
                            ),
                            Text(
                              '$takenPct%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _donutLegendRow(
                              icon: Icons.check_circle_rounded,
                              bg: AppColors.pinkBg,
                              color: AppColors.pinkColor,
                              text: '$takenPct%',
                            ),
                            const SizedBox(height: 6),
                            _donutLegendRow(
                              icon: Icons.schedule_rounded,
                              bg: AppColors.peachBg,
                              color: AppColors.peachColor,
                              text: '$pendingPct%',
                            ),
                            const SizedBox(height: 6),
                            _donutLegendRow(
                              icon: Icons.inventory_2_rounded,
                              bg: AppColors.blueBg,
                              color: AppColors.blueColor,
                              text: '$skippedPct%',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tap to view breakdown',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Right Card: Today / Week / Month Summary Card
        Expanded(
          child: Container(
            height: 170,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  periodTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$displayTaken Doses Taken',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_down_rounded,
                          size: 16,
                          color: AppColors.pinkColor,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$totalStock Pills Left',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Day | Week | Month Segmented Pill Toggle
                Container(
                  height: 32,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: ['Day', 'Week', 'Month'].map((period) {
                      final active = _selectedPeriod == period;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPeriod = period),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              period,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: active ? Colors.white : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _donutLegendRow({
    required IconData icon,
    required Color bg,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  /// "Doses due" Section matching "Payments due" from the Tarsi screenshot
  Widget _buildDosesDueSection({
    required List<_Slot> slots,
    required DateTime now,
    required String nowTime,
    required int takenCount,
  }) {
    const monthsShort = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final currentMonth = monthsShort[now.month - 1];

    final totalDosesDisplay = slots.length;
    final remainingCount = (slots.length - takenCount).clamp(0, 99);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: "Doses due" + "TOTAL DUE" on the right
        InkWell(
          onTap: widget.onOpenSchedule,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doses due',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalDosesDisplay doses scheduled today',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$remainingCount Left Today',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    'TOTAL DUE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // White Container Card holding the Dose Due Rows
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: slots.isNotEmpty
              ? Column(
                  children: [
                    for (int i = 0; i < slots.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: AppColors.borderLight),
                      _buildLiveDoseDueRow(
                        slots[i],
                        index: i,
                        monthLabel: currentMonth,
                        dayNumber: '${now.day}',
                        now: now,
                        nowTime: nowTime,
                      ),
                    ],
                  ],
                )
              : _buildShowcaseDoseDueRows(now),
        ),
      ],
    );
  }

  Widget _buildLiveDoseDueRow(
    _Slot s, {
    required int index,
    required String monthLabel,
    required String dayNumber,
    required DateTime now,
    required String nowTime,
  }) {
    final log = _logFor(s);
    final status = log?.status;
    final isTaken = status == DoseStatus.taken;
    final isSkipped = status == DoseStatus.skipped;
    final isOverdue = status == null && s.time.compareTo(nowTime) <= 0;

    String chipLabel;
    Color chipBg;
    Color chipFg;

    final hm = parseTime(s.time);
    if (isTaken) {
      chipLabel = 'Completed ✓';
      chipBg = AppColors.mintBg;
      chipFg = AppColors.mintColor;
    } else if (isSkipped) {
      chipLabel = 'Skipped';
      chipBg = AppColors.yellowBg;
      chipFg = AppColors.amberColor;
    } else if (isOverdue) {
      int minsLate = 15;
      if (hm != null) {
        final dt = DateTime(now.year, now.month, now.day, hm.$1, hm.$2);
        minsLate = now.difference(dt).inMinutes.abs();
      }
      chipLabel = minsLate < 60
          ? '${minsLate.clamp(1, 59)}m overdue'
          : '${(minsLate / 60).floor()} hrs overdue';
      chipBg = AppColors.overdueBg;
      chipFg = AppColors.overdueText;
    } else {
      int minsLeft = 120;
      if (hm != null) {
        final dt = DateTime(now.year, now.month, now.day, hm.$1, hm.$2);
        minsLeft = dt.difference(now).inMinutes.abs();
      }
      chipLabel = minsLeft < 60
          ? 'In ${minsLeft}m'
          : '${(minsLeft / 60).ceil()} hrs left';
      chipBg = const Color(0xFFF1F4F2);
      chipFg = AppColors.textMuted;
    }

    final brandBadges = [
      (bg: const Color(0xFF0056B3), icon: Icons.medication_rounded),
      (bg: const Color(0xFF2D6A4F), icon: Icons.sunny),
      (bg: const Color(0xFFD90429), icon: Icons.favorite_rounded),
      (bg: const Color(0xFF7209B7), icon: Icons.vaccines_rounded),
    ];
    final badge = brandBadges[index % brandBadges.length];

    return InkWell(
      onTap: () => _showDoseActionSheet(s),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Left Date Squircle Badge matching "SEP 12" in the Tarsi screenshot
            Container(
              width: 52,
              height: 56,
              decoration: BoxDecoration(
                color: isOverdue ? AppColors.overdueBg : const Color(0xFFF4F6F5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isOverdue ? AppColors.overdueText : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    dayNumber,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isOverdue ? AppColors.overdueText : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Middle Column: Brand circle + Overdue/Time pill on top, Medication Name on bottom
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: badge.bg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          badge.icon,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          chipLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: chipFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.med.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right Column: Scheduled Time + Dosage/Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(s.time),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isTaken ? 'TAKEN ✓' : '${s.med.doseLabel.toUpperCase()} • DUE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isTaken ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state when no medications are scheduled yet
  Widget _buildShowcaseDoseDueRows(DateTime now) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No doses due today',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your schedule is empty. Tap + below to add your first medication reminder.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.onAddMedication,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add First Medication'),
          ),
        ],
      ),
    );
  }

  Widget _buildRefillBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.overdueBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.overdueText,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_refillCount medicine(s) need a refill soon.',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.overdueText,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onOpenMedications,
              child: Text(
                'Restock',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Custom Painter that draws the lush Philippine rice-terraces & layered sage hills
/// behind the greeting and mascot, matching the Tarsi screenshot header.
class _ScenicNatureBannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Soft morning sage sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFEBF5EE),
          Color(0xFFD5EBDC),
          Color(0xFFB7DEC4),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Distant misty mountain ridge
    final distantMountain = Path()
      ..moveTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.25, h * 0.42, w * 0.55, h * 0.52)
      ..quadraticBezierTo(w * 0.80, h * 0.36, w, h * 0.45)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      distantMountain,
      Paint()..color = const Color(0xFFB3DABF).withValues(alpha: 0.7),
    );

    // 3. Midground terraced green hills on the right
    final midHill = Path()
      ..moveTo(0, h * 0.72)
      ..cubicTo(w * 0.3, h * 0.62, w * 0.58, h * 0.48, w, h * 0.50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      midHill,
      Paint()..color = const Color(0xFF83BE95),
    );

    // Subtle rice-terrace steps on the right hillside
    final terracePaint = Paint()
      ..color = const Color(0xFF9AD0A9).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    for (int i = 0; i < 4; i++) {
      final yOff = h * (0.54 + i * 0.045);
      final p = Path()
        ..moveTo(w * 0.52, yOff + 10)
        ..quadraticBezierTo(w * 0.76, yOff - 6, w, yOff);
      canvas.drawPath(p, terracePaint);
    }

    // 4. Foreground rich emerald hill
    final foreHill = Path()
      ..moveTo(0, h * 0.80)
      ..quadraticBezierTo(w * 0.35, h * 0.68, w * 0.75, h * 0.78)
      ..quadraticBezierTo(w * 0.90, h * 0.82, w, h * 0.75)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      foreHill,
      Paint()..color = const Color(0xFF4D8F66),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Speech bubble left-pointing tail triangle
class _SpeechTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Multi-segment Donut Chart Painter matching the Tarsi 95% Pink/Amber/Blue donut ring
class _TarsiDonutPainter extends CustomPainter {
  const _TarsiDonutPainter({
    required this.primaryPct,
    required this.secondaryPct,
    required this.tertiaryPct,
  });

  final double primaryPct;
  final double secondaryPct;
  final double tertiaryPct;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.5;
    final rect = Offset.zero & size;
    final insetRect = rect.deflate(strokeWidth / 2);

    final trackPaint = Paint()
      ..color = const Color(0xFFF3F5F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(insetRect, 0, math.pi * 2, false, trackPaint);

    double startAngle = -math.pi / 2;
    const gap = 0.06;

    void drawSegment(double pct, Color color) {
      if (pct <= 0.005) return;
      final sweep = math.max(0.08, (math.pi * 2 * pct) - gap);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(insetRect, startAngle, sweep, false, paint);
      startAngle += sweep + gap;
    }

    // 1. Primary segment (Tarsi vibrant rose/magenta #EC4899)
    drawSegment(primaryPct, AppColors.pinkColor);
    // 2. Secondary segment (Warm coral/amber #FF6B2C)
    drawSegment(secondaryPct, AppColors.peachColor);
    // 3. Tertiary segment (Sky blue #007DFE)
    drawSegment(tertiaryPct, AppColors.blueColor);
  }

  @override
  bool shouldRepaint(covariant _TarsiDonutPainter old) =>
      old.primaryPct != primaryPct ||
      old.secondaryPct != secondaryPct ||
      old.tertiaryPct != tertiaryPct;
}
