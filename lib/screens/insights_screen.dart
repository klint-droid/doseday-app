import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _db = DatabaseService.instance;
  List<Medication>? _meds;
  List<DoseLog> _logs = [];

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
    final meds = await _db.getMedications();
    final logs = await _db.getAllLogs();
    if (mounted) {
      setState(() {
        _meds = meds;
        _logs = logs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meds = _meds;
    if (meds == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final today = dateKey(DateTime.now());
    final todayLogs = _logs.where((l) => l.scheduledDate == today).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final taken = _logs.where((l) => l.status == DoseStatus.taken).length;
    final skipped = _logs.where((l) => l.status == DoseStatus.skipped).length;
    final missed = _logs.where((l) => l.status == DoseStatus.missed).length;
    final recorded = taken + skipped + missed;
    final rate = recorded == 0 ? 0.0 : taken / recorded;
    final refill = meds.where((m) => m.isActive && m.needsRefill).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 115),
            children: [
              // Header
              Text(
                'ANALYTICS & LOGS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Dose History & Breakdown',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 16),

              // 3D Bird Mascot Companion Summary Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE5F3EA), Color(0xFFCBE6D4)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFB8DEC5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/mascot_3d_bird.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset('assets/images/app_logo.png'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(rate * 100).round()}% Adherence Score',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recorded == 0
                                ? 'No doses recorded yet. Add a medication and log your doses to build your adherence history.'
                                : 'Based on $recorded logged doses ($taken taken, $skipped skipped, $missed missed).',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2D533E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4 Bento Stat Cards
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Doses Taken',
                      value: '$taken',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Missed',
                      value: '$missed',
                      icon: Icons.error_outline_rounded,
                      color: AppColors.missed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Skipped',
                      value: '$skipped',
                      icon: Icons.remove_circle_outline_rounded,
                      color: AppColors.skipped,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Refills Needed',
                      value: '$refill',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              _weekCard(),
              const SizedBox(height: 18),
              _todayCard(todayLogs, meds),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekCard() {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 Days Trend',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 3),
          Text(
            'Daily adherence completion across your routine',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                final key = dateKey(d);
                final dayLogs = _logs.where((l) => l.scheduledDate == key);
                final total = dayLogs.length;
                final t = dayLogs.where((l) => l.status == DoseStatus.taken).length;
                final r = total == 0 ? 0.0 : t / total;
                final isToday = key == dateKey(now);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        total == 0 ? '0/0' : '$t/$total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: r),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Container(
                          width: 24,
                          height: 8 + 78 * v,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: isToday
                                ? AppColors.pinkColor
                                : (r >= .8
                                    ? AppColors.primary
                                    : r >= .5
                                        ? AppColors.skipped
                                        : AppColors.missed),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekdayLetter(d),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                          color: isToday ? AppColors.pinkColor : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(List<DoseLog> todayLogs, List<Medication> meds) => AppCard(
        padding: const EdgeInsets.all(18),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Logged Activity",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            if (todayLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No doses have been logged yet today. Tap a dose on Home or Plan to record it.',
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 13),
                ),
              )
            else
              ...todayLogs.map((l) {
                final med = meds.where((m) => m.id == l.medicationId).firstOrNull;
                final color = AppColors.forStatus(l.status);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconBadge(
                    icon: AppColors.iconForStatus(l.status),
                    color: color,
                    size: 40,
                  ),
                  title: Text(
                    med?.name ?? 'Medication',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(formatTime(l.scheduledTime)),
                  trailing: StatusPill(label: l.status, color: color),
                );
              }),
          ],
        ),
      );
}
