import 'package:flutter/material.dart';

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
        body: Center(child: CircularProgressIndicator()),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const PageHeader(title: 'Your insights', subtitle: 'A simple view of your medication routine.'),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: StatCard(title: 'Taken', value: '$taken', icon: Icons.check_circle_outline, color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(title: 'Missed', value: '$missed', icon: Icons.error_outline, color: AppColors.missed)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: StatCard(title: 'Skipped', value: '$skipped', icon: Icons.remove_circle_outline, color: AppColors.skipped)),
                const SizedBox(width: 10),
                Expanded(
                    child: StatCard(
                        title: 'Refills needed', value: '$refill', icon: Icons.inventory_2_outlined, color: AppColors.warning)),
              ]),
              const SizedBox(height: 20),
              _adherenceCard(rate, recorded),
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

  Widget _adherenceCard(double rate, int recorded) => AppCard(
        padding: const EdgeInsets.all(20),
        radius: 22,
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: rate),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: v,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFE8EEF3),
                      color: AppColors.primary,
                    ),
                    Center(
                      child: Text('${(v * 100).round()}%',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adherence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(
                    recorded == 0
                        ? 'Your statistics will appear after you record doses.'
                        : 'Based on $recorded recorded doses. Skipped and missed doses are not counted as taken.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _weekCard() {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          const Text('Share of recorded doses taken each day', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
                  child: Semantics(
                    label: '${friendlyDate(d)}: ${total == 0 ? 'no doses recorded' : '$t of $total taken'}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(total == 0 ? '–' : '$t/$total',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: r),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Container(
                            width: 22,
                            height: 6 + 80 * v,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: total == 0
                                  ? const Color(0xFFE8EEF3)
                                  : r >= .8
                                      ? AppColors.primary
                                      : r >= .5
                                          ? AppColors.skipped
                                          : AppColors.missed,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekdayLetter(d),
                          style: TextStyle(
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                            color: isToday ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
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
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's activity", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            if (todayLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No doses have been recorded today.', style: TextStyle(color: AppColors.textMuted)),
              )
            else
              ...todayLogs.map((l) {
                final med = meds.where((m) => m.id == l.medicationId).firstOrNull;
                final color = AppColors.forStatus(l.status);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconBadge(icon: AppColors.iconForStatus(l.status), color: color, size: 40),
                  title: Text(med?.name ?? 'Medication', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(formatTime(l.scheduledTime)),
                  trailing: StatusPill(label: l.status, color: color),
                );
              }),
          ],
        ),
      );
}
