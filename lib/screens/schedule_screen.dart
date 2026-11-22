import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/notifications_sheet.dart';

typedef _Slot = ({Medication med, String time});

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.onAddMedication});

  final VoidCallback onAddMedication;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _db = DatabaseService.instance;
  late DateTime _selectedDate;
  int _weekOffset = 0;
  late final PageController _weekPageController;
  static const int _initialWeekPage = 1000;

  String _selectedFilter = 'All'; // All, To do, Due Now, Completed
  List<Medication> _medications = [];
  List<DoseLog> _logs = [];
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weekPageController = PageController(initialPage: _initialWeekPage);
    _db.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    _db.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await _db.markPastDosesMissed();
    final meds = await _db.getMedications(activeOnly: true);
    final logs = await _db.getLogsForDate(dateKey(_selectedDate));
    if (mounted) {
      setState(() {
        _medications = meds;
        _logs = logs;
        _busy = false;
      });
    }
  }

  DoseLog? _logFor(_Slot s) => _logs
      .where((l) => l.medicationId == s.med.id && l.scheduledTime == s.time)
      .firstOrNull;

  Future<void> _mark(_Slot s, String status) async {
    await _db.recordDose(
      medication: s.med,
      date: dateKey(_selectedDate),
      time: s.time,
      status: status,
    );
    if (status == DoseStatus.taken && s.med.id != null) {
      await NotificationService.instance.checkAndNotifyLowStock(s.med.id!);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '${s.med.name} marked as $status',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = dateKey(_selectedDate);
    final now = DateTime.now();
    final isToday = dayKey == dateKey(now);
    final nowTime = timeKey(now);

    final slots = <_Slot>[
      for (final m in _medications)
        if (m.isScheduledOn(dayKey))
          for (final t in m.times) (med: m, time: t),
    ]..sort((a, b) => a.time.compareTo(b.time));

    final filtered = slots.where((s) {
      final log = _logFor(s);
      final status = log?.status;
      final isDone = status == DoseStatus.taken;
      final isDue = isToday && status == null && s.time.compareTo(nowTime) <= 0;

      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'To do') return status == null && !isDue;
      if (_selectedFilter == 'Due Now' || _selectedFilter == 'In Progress') {
        return isDue || status == null;
      }
      if (_selectedFilter == 'Completed' || _selectedFilter == 'Done') return isDone;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            _buildWeekHeader(),
            const SizedBox(height: 4),
            _buildDateStrip(),
            const SizedBox(height: 14),
            _buildFilterChips(),
            const SizedBox(height: 12),
            Expanded(
              child: _busy
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filtered.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildDoseCard(
                            filtered[i],
                            index: i,
                            isToday: isToday,
                            nowTime: nowTime,
                          ),
                        )
                      : slots.isNotEmpty
                          ? _buildNoFilterMatch()
                          : _buildDemoTasksList(isToday: isToday, nowTime: nowTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Text(
              '7-Day Dose Plan',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => NotificationsSheet.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight, width: 1.2),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 21,
                      color: AppColors.primary,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.peachColor,
                        shape: BoxShape.circle,
                      ),
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

  DateTime _mondayForOffset(int offset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    return thisMonday.add(Duration(days: offset * 7));
  }

  String _formatWeekRange(DateTime monday) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final sunday = monday.add(const Duration(days: 6));
    if (monday.year != sunday.year) {
      return '${monday.day} ${months[monday.month - 1]} ${monday.year} – ${sunday.day} ${months[sunday.month - 1]} ${sunday.year}';
    } else if (monday.month != sunday.month) {
      return '${monday.day} ${months[monday.month - 1]} – ${sunday.day} ${months[sunday.month - 1]}, ${monday.year}';
    } else {
      return '${monday.day} – ${sunday.day} ${months[monday.month - 1]}, ${monday.year}';
    }
  }

  Widget _buildWeekHeader() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = _mondayForOffset(_weekOffset);
    final isCurrentWeek = _weekOffset == 0;
    final isTodaySelected = dateKey(_selectedDate) == dateKey(today);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.date_range_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            _formatWeekRange(monday),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          if (!isCurrentWeek || !isTodaySelected)
            GestureDetector(
              onTap: () {
                setState(() {
                  _weekOffset = 0;
                  _selectedDate = today;
                  _busy = true;
                });
                _weekPageController.animateToPage(
                  _initialWeekPage,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                );
                _load();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Today',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () {
              _weekPageController.previousPage(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
          ),
          const SizedBox(width: 4),
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            onTap: () {
              _weekPageController.nextPage(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Icon(icon, size: 18, color: AppColors.text),
        ),
      ),
    );
  }

  Widget _buildDateStrip() {
    return SizedBox(
      height: 96,
      child: PageView.builder(
        controller: _weekPageController,
        onPageChanged: (page) {
          final newOffset = page - _initialWeekPage;
          setState(() {
            _weekOffset = newOffset;
            final newMonday = _mondayForOffset(newOffset);
            final weekdayIndex = _selectedDate.weekday - 1;
            _selectedDate = newMonday.add(Duration(days: weekdayIndex));
            _busy = true;
          });
          _load();
        },
        itemBuilder: (context, page) {
          final offset = page - _initialWeekPage;
          final monday = _mondayForOffset(offset);
          final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                for (final d in weekDays)
                  Expanded(
                    child: _buildDayCard(d),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCard(DateTime d) {
    final now = DateTime.now();
    final isToday = dateKey(d) == dateKey(now);
    final isSelected = dateKey(d) == dateKey(_selectedDate);

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = d;
          _busy = true;
        });
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
          border: isSelected
              ? null
              : Border.all(
                  color: isToday
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.borderLight,
                  width: isToday ? 1.4 : 1.0,
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              months[d.month - 1],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${d.day}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              weekdays[d.weekday - 1],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isToday ? AppColors.primary : AppColors.textMuted),
              ),
            ),
            if (isToday && !isSelected) ...[
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['All', 'To do', 'Due Now', 'Completed'];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final active = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                f,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoseCard(_Slot s, {required int index, required bool isToday, required String nowTime}) {
    final log = _logFor(s);
    final status = log?.status;
    final isDone = status == DoseStatus.taken;
    final isDue = isToday && status == null && s.time.compareTo(nowTime) <= 0;

    final pillLabel = isDone
        ? 'Taken ✓'
        : isDue
            ? 'Due Now'
            : status == DoseStatus.skipped
                ? 'Skipped'
                : 'Scheduled';

    final pillStatus = isDone
        ? 'done'
        : isDue
            ? 'in_progress'
            : status == DoseStatus.skipped
                ? 'skipped'
                : 'todo';

    final badges = [
      (bg: AppColors.primaryContainer, color: AppColors.primary, icon: Icons.medication_rounded),
      (bg: AppColors.peachBg, color: AppColors.peachColor, icon: Icons.wb_sunny_rounded),
      (bg: AppColors.pinkBg, color: AppColors.pinkColor, icon: Icons.favorite_outline_rounded),
      (bg: AppColors.blueBg, color: AppColors.blueColor, icon: Icons.nightlight_round),
    ];
    final b = badges[index % badges.length];

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 20,
      onTap: () => _mark(s, isDone ? DoseStatus.skipped : DoseStatus.taken),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.med.instructions.isNotEmpty
                          ? s.med.instructions
                          : 'Daily Prescription',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.med.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textMuted,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              PastelIconBadge(
                icon: b.icon,
                bg: b.bg,
                color: b.color,
                size: 36,
                radius: 11,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                '${formatTime(s.time)}  •  ${s.med.doseLabel}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              FigmaStatusPill(label: pillLabel, status: pillStatus),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Dose options',
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                onSelected: (v) async {
                  if (v == 'snooze') {
                    await NotificationService.instance.scheduleSnooze(s.med, s.time, minutes: 10);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⏰ Snoozed ${s.med.name} for 10 minutes'),
                          backgroundColor: AppColors.primaryDark,
                        ),
                      );
                    }
                  } else {
                    await _mark(s, v);
                  }
                },
                itemBuilder: (_) => [
                  if (!isDone)
                    PopupMenuItem(
                      value: DoseStatus.taken,
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                        title: Text('Mark as Taken', style: GoogleFonts.plusJakartaSans()),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'snooze',
                    child: ListTile(
                      leading: const Icon(Icons.snooze_rounded, color: AppColors.primaryDark),
                      title: Text('Snooze 10 mins', style: GoogleFonts.plusJakartaSans()),
                    ),
                  ),
                  if (status != DoseStatus.skipped)
                    PopupMenuItem(
                      value: DoseStatus.skipped,
                      child: ListTile(
                        leading: const Icon(Icons.remove_circle_outline, color: AppColors.amberColor),
                        title: Text('Mark as Skipped', style: GoogleFonts.plusJakartaSans()),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoTasksList({required bool isToday, required String nowTime}) {
    final demoDoses = [
      (
        category: 'Take after breakfast • Antibiotic course',
        title: 'Amoxicillin 500mg',
        time: '08:00 AM',
        status: 'done',
        label: 'Taken ✓',
        icon: Icons.medication_rounded,
        bg: AppColors.primaryContainer,
        color: AppColors.primary,
      ),
      (
        category: 'Daily morning supplement • With meal',
        title: 'Vitamin D3 + K2 (2000 IU)',
        time: '12:00 PM',
        status: 'in_progress',
        label: 'Due Now',
        icon: Icons.wb_sunny_rounded,
        bg: AppColors.peachBg,
        color: AppColors.peachColor,
      ),
      (
        category: 'Blood pressure maintenance • Evening',
        title: 'Losartan Potassium 50mg',
        time: '07:00 PM',
        status: 'todo',
        label: 'Scheduled',
        icon: Icons.favorite_outline_rounded,
        bg: AppColors.pinkBg,
        color: AppColors.pinkColor,
      ),
      (
        category: 'Before bedtime • Heart & omega wellness',
        title: 'Omega-3 Fish Oil 1000mg',
        time: '09:00 PM',
        status: 'todo',
        label: 'Scheduled',
        icon: Icons.nightlight_round,
        bg: AppColors.blueBg,
        color: AppColors.blueColor,
      ),
    ];

    final filteredDemo = demoDoses.where((t) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'To do') return t.status == 'todo';
      if (_selectedFilter == 'Due Now' || _selectedFilter == 'In Progress') {
        return t.status == 'in_progress';
      }
      if (_selectedFilter == 'Completed' || _selectedFilter == 'Done') return t.status == 'done';
      return true;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
      itemCount: filteredDemo.length,
      itemBuilder: (_, i) {
        final t = filteredDemo[i];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          radius: 20,
          onTap: widget.onAddMedication,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            decoration: t.status == 'done' ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textMuted,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PastelIconBadge(
                    icon: t.icon,
                    bg: t.bg,
                    color: t.color,
                    size: 36,
                    radius: 11,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    t.time,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  FigmaStatusPill(label: t.label, status: t.status),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoFilterMatch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.task_alt_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No doses in "$_selectedFilter"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Switch filter tabs above or tap + to add a new medication reminder.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
