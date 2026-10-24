import 'package:flutter/material.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/notifications_sheet.dart';
import 'profile_screen.dart';

typedef _Slot = ({Medication med, String time});

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenMedications,
    required this.onAddMedication,
  });

  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenMedications;
  final VoidCallback onAddMedication;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;
  UserProfile? _profile;
  List<Medication> _medications = [];
  List<DoseLog> _logs = [];
  int _refillCount = 0;

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
    final logs = await _db.getLogsForDate(dateKey(DateTime.now()));
    final refill = await _db.getRefillCount();
    if (mounted) {
      setState(() {
        _profile = profile;
        _medications = meds;
        _logs = logs;
        _refillCount = refill;
      });
    }
  }

  DoseLog? _logFor(_Slot s) =>
      _logs.where((l) => l.medicationId == s.med.id && l.scheduledTime == s.time).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dateKey(now);

    final slots = <_Slot>[
      for (final m in _medications)
        if (m.isScheduledOn(today))
          for (final t in m.times) (med: m, time: t),
    ]..sort((a, b) => a.time.compareTo(b.time));

    final takenCount = slots.where((s) => _logFor(s)?.status == DoseStatus.taken).length;
    final totalCount = slots.length;
    final progress = totalCount == 0 ? 0.0 : takenCount / totalCount;
    final inProgressMeds = _medications.take(4).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
            children: [
              // Header matching Figma screen_home.png (Avatar + Hello + Bell)
              _buildHeader(),

              const SizedBox(height: 20),

              // Featured Royal Purple Card with 85% Circular Progress Ring
              _buildFeaturedCard(progress, takenCount, totalCount),

              const SizedBox(height: 24),

              // Low-stock warning banner if applicable
              if (_refillCount > 0) ...[
                _buildRefillBanner(),
                const SizedBox(height: 20),
              ],

              // "In Progress" Section with horizontal cards
              Row(
                children: [
                  const Text(
                    'In Progress',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountPill('${inProgressMeds.length}'),
                ],
              ),
              const SizedBox(height: 14),

              if (inProgressMeds.isEmpty)
                _buildEmptyProgress()
              else
                _buildHorizontalCards(inProgressMeds, slots),

              const SizedBox(height: 26),

              // "Medication Routine" (Task Groups in Figma)
              Row(
                children: [
                  const Text(
                    'Medication Routine',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountPill('${_medications.length}'),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onOpenMedications,
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_medications.isEmpty)
                _buildEmptyRoutine()
              else
                ..._medications.map((m) => _buildRoutineCard(m, slots)),
            ],
          ),
        ),
      ),
    );
  }

  // Header: User Avatar + Name (tappable for Profile) + Notification Bell with Dot
  Widget _buildHeader() => Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _profile?.avatarPath ?? 'assets/images/user_avatar.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.primaryContainer,
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hello!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          _profile?.name ?? 'Livia Vaccaro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bell icon with purple indicator dot (tappable for Notifications & Alerts)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => NotificationsSheet.show(context),
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 22,
                      color: AppColors.text,
                    ),
                  ),
                  Positioned(
                    top: 7,
                    right: 9,
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
      );

  // Featured Royal Purple Card matching Figma screen_home.png
  Widget _buildFeaturedCard(double progress, int taken, int total) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .38),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your today's doses\nalmost done!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // "View Schedule" pill button
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: widget.onOpenSchedule,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text(
                          'View Schedule',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Circular 85% Progress Ring
            CircularPercentRing(
              percent: progress,
              size: 84,
              strokeWidth: 8,
              ringColor: Colors.white,
              trackColor: Colors.white.withValues(alpha: .22),
            ),
          ],
        ),
      );

  // Horizontal Scrolling Cards matching Figma screen_home.png (Office Project, Personal Project)
  Widget _buildHorizontalCards(List<Medication> meds, List<_Slot> slots) {
    final colors = [
      (bg: AppColors.blueBg, bar: AppColors.blueColor, badgeBg: AppColors.pinkBg, badgeColor: AppColors.pinkColor),
      (bg: AppColors.peachBg, bar: AppColors.peachColor, badgeBg: AppColors.primaryContainer, badgeColor: AppColors.primary),
      (bg: AppColors.yellowBg, bar: AppColors.amberColor, badgeBg: AppColors.mintBg, badgeColor: AppColors.mintColor),
      (bg: AppColors.primarySoft, bar: AppColors.primary, badgeBg: AppColors.blueBg, badgeColor: AppColors.blueColor),
    ];

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: meds.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final m = meds[i];
          final c = colors[i % colors.length];

          // Compute today's doses for this med
          final medSlots = slots.where((s) => s.med.id == m.id).toList();
          final medTaken = medSlots.where((s) => _logFor(s)?.status == DoseStatus.taken).length;
          final medRatio = medSlots.isEmpty ? 0.0 : medTaken / medSlots.length;

          return Container(
            width: 215,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m.instructions.isNotEmpty ? m.instructions : 'Routine Dose',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    PastelIconBadge(
                      icon: Icons.medication_rounded,
                      bg: c.badgeBg,
                      color: c.badgeColor,
                      size: 28,
                      radius: 8,
                    ),
                  ],
                ),
                Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${m.dosage} ${m.dosageUnit}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        Text(
                          '$medTaken/${medSlots.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: medRatio,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: .6),
                        valueColor: AlwaysStoppedAnimation(c.bar),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Task Groups / Medication Routine vertical list with mini percentage rings
  Widget _buildRoutineCard(Medication m, List<_Slot> slots) {
    final colors = [
      (bg: AppColors.pinkBg, color: AppColors.pinkColor),
      (bg: AppColors.primaryContainer, color: AppColors.primary),
      (bg: AppColors.peachBg, color: AppColors.peachColor),
      (bg: AppColors.yellowBg, color: AppColors.amberColor),
    ];
    final c = colors[(m.id ?? 0) % colors.length];

    // Compute adherence or stock percent
    final medSlots = slots.where((s) => s.med.id == m.id).toList();
    final medTaken = medSlots.where((s) => _logFor(s)?.status == DoseStatus.taken).length;
    final percent = medSlots.isEmpty ? 1.0 : medTaken / medSlots.length;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 18,
      child: Row(
        children: [
          PastelIconBadge(
            icon: Icons.healing_rounded,
            bg: c.bg,
            color: c.color,
            size: 46,
            radius: 14,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${m.dosage} ${m.dosageUnit}  •  ${m.times.map(formatTime).join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Mini Circular Ring matching Figma screen_home.png (70%, 52%, 87%)
          CircularPercentRing(
            percent: percent,
            size: 44,
            strokeWidth: 4.5,
            ringColor: c.color,
            trackColor: c.bg,
            textStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: c.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefillBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.yellowBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const PastelIconBadge(
              icon: Icons.inventory_2_outlined,
              bg: Colors.white,
              color: AppColors.amberColor,
              size: 38,
              radius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_refillCount medication(s) are low on stock.',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onOpenMedications,
              child: const Text('Restock', style: TextStyle(color: AppColors.amberColor, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  Widget _buildEmptyProgress() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No active medications in progress.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );

  Widget _buildEmptyRoutine() => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.medication_outlined, size: 40, color: AppColors.primary),
            const SizedBox(height: 10),
            const Text(
              'No medications added yet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the + button below to add your first medicine.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.onAddMedication,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add medicine'),
            ),
          ],
        ),
      );
}
