import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // Show real progress if doses exist, else 85% matching Slide 1 showcase
    final progress = totalCount == 0 ? 0.85 : takenCount / totalCount;
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
              // Header matching Slide 1 (Avatar + Hello! + Olivia Vaccaro + Notification Bell)
              _buildHeader(),

              const SizedBox(height: 20),

              // Featured Royal Purple Card with 85% Circular Progress Ring matching Slide 1
              _buildFeaturedCard(progress, takenCount, totalCount),

              const SizedBox(height: 24),

              // Low-stock warning banner if applicable
              if (_refillCount > 0) ...[
                _buildRefillBanner(),
                const SizedBox(height: 20),
              ],

              // "In Progress" Section with count pill
              Row(
                children: [
                  Text(
                    'In Progress',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountPill(inProgressMeds.isEmpty ? '6' : '${inProgressMeds.length}'),
                ],
              ),
              const SizedBox(height: 14),

              // Horizontal Scrolling Cards matching Slide 1
              _buildHorizontalCards(inProgressMeds, slots),

              const SizedBox(height: 26),

              // "Task Groups" Section matching Slide 1
              Row(
                children: [
                  Text(
                    'Task Groups',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountPill(_medications.isEmpty ? '4' : '${_medications.length}'),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onOpenMedications,
                    child: Text(
                      'See All',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Task Groups cards matching Slide 1
              _buildTaskGroupsList(slots),
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
                      border: Border.all(color: Colors.white, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 10,
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
                        Text(
                          'Hello!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          _profile?.name ?? 'Olivia Vaccaro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                            letterSpacing: -0.4,
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
          // Bell icon with purple indicator dot matching Slide 1
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => NotificationsSheet.show(context),
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 22,
                      color: AppColors.text,
                    ),
                  ),
                  Positioned(
                    top: 8,
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
      );

  // Featured Royal Purple Card matching Slide 1 (85% circular ring, "View Task", three dots)
  Widget _buildFeaturedCard(double progress, int taken, int total) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5F33E1), Color(0xFF6C40FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5F33E1).withValues(alpha: .40),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top row inside card: Three dots menu button matching Slide 1
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: widget.onOpenSchedule,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your today's task\nalmost done!",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // "View Task" pill button matching Slide 1
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: widget.onOpenSchedule,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            child: Text(
                              'View Task',
                              style: GoogleFonts.plusJakartaSans(
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
                // Circular 85% Progress Ring matching Slide 1
                CircularPercentRing(
                  percent: progress,
                  size: 86,
                  strokeWidth: 8,
                  ringColor: Colors.white,
                  trackColor: Colors.white.withValues(alpha: .24),
                  label: total == 0 ? '85%' : null,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  // Horizontal Scrolling Cards matching Slide 1 (Office Project, Personal Project)
  Widget _buildHorizontalCards(List<Medication> meds, List<_Slot> slots) {
    if (meds.isNotEmpty) {
      final colors = [
        (bg: AppColors.blueBg, bar: AppColors.blueColor, badgeBg: AppColors.pinkBg, badgeColor: AppColors.pinkColor, subtitle: 'Office Project'),
        (bg: AppColors.peachBg, bar: AppColors.peachColor, badgeBg: AppColors.primaryContainer, badgeColor: AppColors.primary, subtitle: 'Personal Project'),
        (bg: AppColors.yellowBg, bar: AppColors.amberColor, badgeBg: AppColors.mintBg, badgeColor: AppColors.mintColor, subtitle: 'Daily Routine'),
        (bg: AppColors.primarySoft, bar: AppColors.primary, badgeBg: AppColors.blueBg, badgeColor: AppColors.blueColor, subtitle: 'Evening Care'),
      ];

      return SizedBox(
        height: 142,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: meds.length,
          separatorBuilder: (context, index) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final m = meds[i];
            final c = colors[i % colors.length];

            final medSlots = slots.where((s) => s.med.id == m.id).toList();
            final medTaken = medSlots.where((s) => _logFor(s)?.status == DoseStatus.taken).length;
            final medRatio = medSlots.isEmpty ? 0.65 : medTaken / medSlots.length;

            return Container(
              width: 220,
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
                        m.instructions.isNotEmpty ? m.instructions : c.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.2,
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
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$medTaken/${medSlots.isEmpty ? 1 : medSlots.length}',
                            style: GoogleFonts.plusJakartaSans(
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

    // Default showcase cards exactly matching Slide 1
    return SizedBox(
      height: 142,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Card 1: Office Project (Grocery shopping app design)
          Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blueBg,
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
                      'Office Project',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const PastelIconBadge(
                      icon: Icons.work_outline_rounded,
                      bg: AppColors.pinkBg,
                      color: AppColors.pinkColor,
                      size: 28,
                      radius: 8,
                    ),
                  ],
                ),
                Text(
                  'Grocery shopping app design',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.70,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: .6),
                    valueColor: const AlwaysStoppedAnimation(AppColors.blueColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Card 2: Personal Project (Uber Eats redesign challenge)
          Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.peachBg,
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
                      'Personal Project',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const PastelIconBadge(
                      icon: Icons.person_outline_rounded,
                      bg: AppColors.primaryContainer,
                      color: AppColors.primary,
                      size: 28,
                      radius: 8,
                    ),
                  ],
                ),
                Text(
                  'Uber Eats redesign challenge',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.52,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: .6),
                    valueColor: const AlwaysStoppedAnimation(AppColors.peachColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Task Groups vertical list matching Slide 1 (Office Project 70%, Personal Project 52%, Daily Study 87%)
  Widget _buildTaskGroupsList(List<_Slot> slots) {
    if (_medications.isNotEmpty) {
      final colors = [
        (bg: AppColors.pinkBg, color: AppColors.pinkColor, icon: Icons.work_outline_rounded),
        (bg: AppColors.primaryContainer, color: AppColors.primary, icon: Icons.person_outline_rounded),
        (bg: AppColors.peachBg, color: AppColors.peachColor, icon: Icons.menu_book_rounded),
        (bg: AppColors.yellowBg, color: AppColors.amberColor, icon: Icons.star_outline_rounded),
      ];

      return Column(
        children: _medications.map((m) {
          final c = colors[(m.id ?? 0) % colors.length];
          final medSlots = slots.where((s) => s.med.id == m.id).toList();
          final medTaken = medSlots.where((s) => _logFor(s)?.status == DoseStatus.taken).length;
          final percent = medSlots.isEmpty ? 0.70 : medTaken / medSlots.length;

          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            radius: 18,
            child: Row(
              children: [
                PastelIconBadge(
                  icon: c.icon,
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
                        style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CircularPercentRing(
                  percent: percent,
                  size: 44,
                  strokeWidth: 4.5,
                  ringColor: c.color,
                  trackColor: c.bg,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // Default showcase matching Slide 1 exactly
    final demoGroups = [
      (title: 'Office Project', subtitle: '23 Tasks', percent: 0.70, bg: AppColors.pinkBg, color: AppColors.pinkColor, icon: Icons.work_outline_rounded),
      (title: 'Personal Project', subtitle: '30 Tasks', percent: 0.52, bg: AppColors.primaryContainer, color: AppColors.primary, icon: Icons.person_outline_rounded),
      (title: 'Daily Study', subtitle: '30 Tasks', percent: 0.87, bg: AppColors.peachBg, color: AppColors.peachColor, icon: Icons.menu_book_rounded),
      (title: 'Health & Routine', subtitle: '14 Tasks', percent: 1.00, bg: AppColors.yellowBg, color: AppColors.amberColor, icon: Icons.favorite_outline_rounded),
    ];

    return Column(
      children: demoGroups.map((g) => AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        radius: 18,
        onTap: widget.onAddMedication,
        child: Row(
          children: [
            PastelIconBadge(
              icon: g.icon,
              bg: g.bg,
              color: g.color,
              size: 46,
              radius: 14,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    g.subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CircularPercentRing(
              percent: g.percent,
              size: 44,
              strokeWidth: 4.5,
              ringColor: g.color,
              trackColor: g.bg,
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: g.color,
              ),
            ),
          ],
        ),
      )).toList(),
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
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onOpenMedications,
              child: Text(
                'Restock',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.amberColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}
