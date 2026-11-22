import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/medication_form.dart';
import 'screens/medications_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

class MedicationReminderApp extends StatelessWidget {
  const MedicationReminderApp({super.key, this.splashController});

  final VideoPlayerController? splashController;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DoseDay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: SplashScreen(controller: splashController),
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onNotificationTapped.addListener(_handleNotificationTapped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
      if (NotificationService.instance.onNotificationTapped.value != null) {
        _handleNotificationTapped();
      }
    });
  }

  @override
  void dispose() {
    NotificationService.instance.onNotificationTapped.removeListener(_handleNotificationTapped);
    super.dispose();
  }

  void _handleNotificationTapped() {
    final payload = NotificationService.instance.onNotificationTapped.value;
    if (payload != null && mounted) {
      debugPrint('Handling notification tap in AppShell: $payload');
      if (payload.startsWith('taken|')) {
        final parts = payload.split('|');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${parts.length > 1 ? parts[1] : 'Dose'} marked as taken!'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else if (payload.startsWith('snoozed|')) {
        final parts = payload.split('|');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏰ Snoozed ${parts.length > 1 ? parts[1] : 'reminder'} for 10 minutes'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      } else if (payload.startsWith('skipped|')) {
        final parts = payload.split('|');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped ${parts.length > 1 ? parts[1] : 'dose'}'),
            backgroundColor: AppColors.amberColor,
          ),
        );
      } else if (payload.startsWith('refill|')) {
        setState(() => _currentIndex = 1); // Switch to Cabinet tab
      } else {
        // Switch to Plan tab (index 2) so user can view/take their dose
        setState(() => _currentIndex = 2);
      }
      NotificationService.instance.onNotificationTapped.value = null;
    }
  }

  Future<void> _openAddMedication() async {
    final saved = await showMedicationForm(context);
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.name} added to your routine'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4 Tabs matching the Tarsi bottom capsule bar:
    // 0: Home, 1: Cabinet (Wallet equivalent), 2: Plan, 3: History
    final pages = [
      HomeScreen(
        onOpenSchedule: () => setState(() => _currentIndex = 2),
        onOpenMedications: () => setState(() => _currentIndex = 1),
        onOpenHistory: () => setState(() => _currentIndex = 3),
        onAddMedication: _openAddMedication,
      ),
      const MedicationsScreen(),
      ScheduleScreen(onAddMedication: _openAddMedication),
      const InsightsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      // Tarsi-style Floating Capsule Bottom Nav + Separate Circular '+' FAB on the Right
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              // Left Floating Glass Capsule Pill (Home, Cabinet, Plan, History)
              Expanded(
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: const Color(0xFFDCE6DF),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF18281F).withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildCapsuleNavItem(
                        index: 0,
                        label: 'Home',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                      ),
                      _buildCapsuleNavItem(
                        index: 1,
                        label: 'Cabinet',
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded,
                      ),
                      _buildCapsuleNavItem(
                        index: 2,
                        label: 'Plan',
                        icon: Icons.calendar_today_outlined,
                        activeIcon: Icons.calendar_month_rounded,
                      ),
                      _buildCapsuleNavItem(
                        index: 3,
                        label: 'History',
                        icon: Icons.history_rounded,
                        activeIcon: Icons.history_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Separate Circular '+' Button on the Right matching Tarsi screenshot
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.96),
                  border: Border.all(
                    color: const Color(0xFFDCE6DF),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF18281F).withValues(alpha: 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openAddMedication,
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 32,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE2EFE7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.text,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
