import 'package:flutter/material.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../services/database_service.dart';
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

  String _selectedFilter = 'All'; // All, To-do, Taken, Skipped/Missed
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
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${s.med.name} marked as $status'),
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
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'To do') return status == null;
      if (_selectedFilter == 'Taken') return status == DoseStatus.taken;
      if (_selectedFilter == 'Skipped') {
        return status == DoseStatus.skipped || status == DoseStatus.missed;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar matching Figma
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  const Text(
                    "Today's Schedule",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  // Notification bell with purple dot (tappable for Notifications & Alerts)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => NotificationsSheet.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 22,
                              color: AppColors.text,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
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
            ),

            // Week range and prev/next week navigation header
            _buildWeekHeader(),

            const SizedBox(height: 4),

            // Horizontal Date Picker Strip (Monday to Sunday, swipeable between weeks)
            _buildDateStrip(),

            const SizedBox(height: 14),

            // Filter Chips (All, To-do, Taken, Skipped)
            _buildFilterChips(),

            const SizedBox(height: 12),

            // Doses List
            Expanded(
              child: _busy
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PastelIconBadge(
                                  icon: Icons.calendar_today_rounded,
                                  bg: AppColors.primaryContainer,
                                  color: AppColors.primary,
                                  size: 60,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  slots.isEmpty
                                      ? 'No doses scheduled'
                                      : 'No doses match "$_selectedFilter"',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  slots.isEmpty
                                      ? 'Add medication or select another date.'
                                      : 'Change filter to view other doses.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildDoseCard(
                            filtered[i],
                            isToday: isToday,
                            nowTime: nowTime,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // Computes the Monday (start of week) for a given week offset
  DateTime _mondayForOffset(int offset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // In Dart DateTime, Monday is 1, Sunday is 7
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

  // Week range label + prev/next week chevron buttons + Today reset button
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
            Icons.calendar_month_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            _formatWeekRange(monday),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          // Jump to Today button if not currently viewing today
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
                child: const Text(
                  'Today',
                  style: TextStyle(
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

  // Horizontal Date Strip: Always starts Monday -> Sunday, swipeable to restart next/prev week
  Widget _buildDateStrip() {
    return SizedBox(
      height: 94,
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
          // Always exactly 7 days: Monday (index 0) through Sunday (index 6)
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

  // Individual Day Card in the 7-day Monday to Sunday strip
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
                    color: AppColors.primary.withValues(alpha: .35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .025),
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
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              weekdays[d.weekday - 1],
              style: TextStyle(
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

  // Filter Chips matching Figma pill filters
  Widget _buildFilterChips() {
    const filters = ['All', 'To do', 'Taken', 'Skipped'];
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
                color: active ? AppColors.primary : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
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

  // Dose card matching Figma screen_tasks.png
  Widget _buildDoseCard(_Slot s, {required bool isToday, required String nowTime}) {
    final log = _logFor(s);
    final status = log?.status;
    final isDone = status == DoseStatus.taken;
    final isDue = isToday && status == null && s.time.compareTo(nowTime) <= 0;

    final pillLabel = isDone
        ? 'Done'
        : isDue
            ? 'Due now'
            : status == DoseStatus.skipped
                ? 'Skipped'
                : status == DoseStatus.missed
                    ? 'Missed'
                    : 'To-do';

    final pillStatus = isDone
        ? 'taken'
        : isDue
            ? 'skipped' // amber
            : status == DoseStatus.skipped
                ? 'skipped'
                : status == DoseStatus.missed
                    ? 'missed'
                    : 'todo';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 18,
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
                          : 'Scheduled Dose',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.med.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Pastel briefcase / pill icon matching Figma top right
              PastelIconBadge(
                icon: Icons.medication_rounded,
                bg: isDone ? AppColors.mintBg : AppColors.pinkBg,
                color: isDone ? AppColors.mintColor : AppColors.pinkColor,
                size: 36,
                radius: 10,
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              FigmaStatusPill(label: pillLabel, status: pillStatus),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Record dose',
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                onSelected: (v) => _mark(s, v),
                itemBuilder: (_) => [
                  if (!isDone)
                    const PopupMenuItem(
                      value: DoseStatus.taken,
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline, color: AppColors.mintColor),
                        title: Text('Mark as Taken'),
                      ),
                    ),
                  if (status != DoseStatus.skipped)
                    const PopupMenuItem(
                      value: DoseStatus.skipped,
                      child: ListTile(
                        leading: Icon(Icons.remove_circle_outline, color: AppColors.amberColor),
                        title: Text('Mark as Skipped'),
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
}
