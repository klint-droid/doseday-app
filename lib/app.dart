import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/medication_form.dart';
import 'screens/medications_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'package:video_player/video_player.dart';
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
      // Switch to Schedule tab (index 1) so user can view/take their dose
      setState(() => _currentIndex = 1);
    }
  }

  Future<void> _openAddMedication() async {
    final saved = await showMedicationForm(context);
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.name} added to routine'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenSchedule: () => setState(() => _currentIndex = 1),
        onOpenMedications: () => setState(() => _currentIndex = 2),
        onAddMedication: _openAddMedication,
      ),
      ScheduleScreen(onAddMedication: _openAddMedication),
      const MedicationsScreen(),
      const InsightsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      // Floating Center Action Button matching Figma (+ button in royal purple)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.49),
              blurRadius: 18,
              offset: const Offset(2, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: _openAddMedication,
          child: const Icon(
            Icons.add_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
      // Figma Custom Curved Bottom Navigation Bar (Soft Lavender #EEE9FF with Cradle Cutout)
      bottomNavigationBar: CustomPaint(
        painter: const FigmaBottomNavPainter(),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  index: 0,
                  activeAsset: 'assets/images/nav_home_active.png',
                  inactiveAsset: 'assets/images/nav_home_inactive.png',
                  fallbackIcon: Icons.home_rounded,
                ),
                _navItem(
                  index: 1,
                  activeAsset: 'assets/images/nav_schedule_active.png',
                  inactiveAsset: 'assets/images/nav_schedule_inactive.png',
                  fallbackIcon: Icons.calendar_month_rounded,
                ),
                const SizedBox(width: 56), // Gap for center floating action button & cradle
                _navItem(
                  index: 2,
                  activeAsset: 'assets/images/nav_medicines_active.png',
                  inactiveAsset: 'assets/images/nav_medicines_inactive.png',
                  fallbackIcon: Icons.description_rounded,
                ),
                _navItem(
                  index: 3,
                  activeAsset: 'assets/images/nav_insights_active.png',
                  inactiveAsset: 'assets/images/nav_insights_inactive.png',
                  fallbackIcon: Icons.people_alt_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required String activeAsset,
    required String inactiveAsset,
    required IconData fallbackIcon,
  }) {
    final isSelected = _currentIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: SizedBox(
          width: 58,
          height: 56,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: isSelected
                  ? Matrix4.translationValues(0, -2, 0)
                  : Matrix4.identity(),
              child: Image.asset(
                isSelected ? activeAsset : inactiveAsset,
                key: ValueKey('$index-$isSelected'),
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  fallbackIcon,
                  size: 26,
                  color: isSelected ? AppColors.primary : const Color(0xFFB5A0F3),
                  shadows: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering the exact mathematical cradle curve and lavender background from Figma
class FigmaBottomNavPainter extends CustomPainter {
  const FigmaBottomNavPainter({
    this.color = const Color(0xFFEEE9FF),
    this.shadowColor = const Color(0x18000000),
  });

  final Color color;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    const cornerRadius = 22.0;
    const notchDepth = 27.0;

    final path = Path()
      ..moveTo(0, cornerRadius)
      ..cubicTo(0, 9.85, 9.85, 0, cornerRadius, 0)
      ..lineTo(cx - 46.5, 0)
      ..cubicTo(cx - 33.5, 0, cx - 23.5, notchDepth, cx, notchDepth)
      ..cubicTo(cx + 23.5, notchDepth, cx + 33.5, 0, cx + 46.5, 0)
      ..lineTo(w - cornerRadius, 0)
      ..cubicTo(w - 9.85, 0, w, 9.85, w, cornerRadius)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    // Top soft shadow
    canvas.drawShadow(path, shadowColor, 12, false);

    // Main soft lavender fill
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

