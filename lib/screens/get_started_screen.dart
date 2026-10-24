import 'package:flutter/material.dart';

import 'account_setup_screen.dart';
import '../theme/app_theme.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Figma decorative pastel dots & 3D Hero image
              Stack(
                alignment: Alignment.center,
                children: [
                  // Decorative pastel dots matching Figma screen_get_started.png
                  Positioned(
                    top: 10,
                    right: 40,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.blueColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.pinkColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    right: 50,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.yellowColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Friendly Owl Hero Mascot
                  Container(
                    height: size.height * 0.35,
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/onboarding_hero.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 1),
              // Title matching Figma typography
              const Text(
                'DoseDay: Smart\nMedication Tracker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                  height: 1.25,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 14),
              // Subtitle
              const Text(
                'This productive tool is designed to help you better manage your daily doses & health schedule conveniently!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
              // Full-width Figma Royal Purple "Let's Start" button
              Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .38),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, anim, secAnim) => const AccountSetupScreen(),
                        transitionsBuilder: (context, anim, secAnim, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Let's Start",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
