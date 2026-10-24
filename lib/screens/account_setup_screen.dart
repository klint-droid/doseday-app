import 'package:flutter/material.dart';

import '../app.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _nameController = TextEditingController(text: 'Livia Vaccaro');
  final _emailController = TextEditingController(text: 'livia.vaccaro@example.com');
  final _emergencyController = TextEditingController();

  String _selectedAvatar = 'assets/images/user_avatar.png';
  String _selectedGoal = 'Never miss a daily dose';
  TimeOfDay _wakeTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 0);
  bool _saving = false;

  final List<String> _avatarOptions = [
    'assets/images/user_avatar.png',
    'assets/images/app_logo.png',
    'assets/images/onboarding_hero.png',
  ];

  final List<({String title, String subtitle, IconData icon, Color color})> _goalOptions = [
    (
      title: 'Never miss a daily dose',
      subtitle: 'Timely reminders for peace of mind',
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.primary,
    ),
    (
      title: 'Manage chronic medication',
      subtitle: 'Strict schedule & inventory refills',
      icon: Icons.medical_services_outlined,
      color: AppColors.blueColor,
    ),
    (
      title: 'Build healthy routine & vitamins',
      subtitle: 'Daily supplements and wellness habit',
      icon: Icons.energy_savings_leaf_outlined,
      color: AppColors.greenColor,
    ),
    (
      title: 'Post-treatment recovery',
      subtitle: 'Prescribed antibiotic or post-surgery course',
      icon: Icons.healing_outlined,
      color: AppColors.pinkColor,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await DatabaseService.instance.getUserProfile();
      if (profile.name.isNotEmpty && profile.name != 'Livia Vaccaro') {
        _nameController.text = profile.name;
      }
      if (profile.email.isNotEmpty && profile.email != 'livia.vaccaro@example.com') {
        _emailController.text = profile.email;
      }
      if (profile.emergencyContact != null && profile.emergencyContact!.isNotEmpty) {
        _emergencyController.text = profile.emergencyContact!;
      }
      if (mounted) {
        setState(() {
          _selectedAvatar = profile.avatarPath;
          _selectedGoal = profile.healthGoal;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> _pickTime(bool isWakeTime) async {
    final initial = isWakeTime ? _wakeTime : _bedtime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isWakeTime) {
          _wakeTime = picked;
        } else {
          _bedtime = picked;
        }
      });
    }
  }

  Future<void> _saveAndProceed() async {
    setState(() => _saving = true);
    final name = _nameController.text.trim().isEmpty ? 'Livia Vaccaro' : _nameController.text.trim();
    final email = _emailController.text.trim().isEmpty ? 'user@doseday.app' : _emailController.text.trim();

    final profile = UserProfile(
      name: name,
      email: email,
      avatarPath: _selectedAvatar,
      healthGoal: _selectedGoal,
      wakeTime: _formatTimeOfDay(_wakeTime),
      bedtime: _formatTimeOfDay(_bedtime),
      emergencyContact: _emergencyController.text.trim().isNotEmpty
          ? _emergencyController.text.trim()
          : null,
      isSetupCompleted: true,
    );

    await DatabaseService.instance.saveUserProfile(profile);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const AppShell(),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            // Top Bar with Skip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Step 1 of 1',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saveAndProceed,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Header Title
            const Text(
              'Set Up Your Profile',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Personalize your medication reminders and health tracking companion.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // Avatar Selector Card
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _selectedAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppColors.primaryContainer,
                              child: const Icon(Icons.person, size: 48, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Choose Avatar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _avatarOptions.map((path) {
                      final isSelected = _selectedAvatar == path;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatar = path),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              width: 2.4,
                            ),
                          ),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                path,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(Icons.face),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Full Name Input
            const Text(
              'Your Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Livia Vaccaro',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Health Goal Options
            const Text(
              'Primary Health Goal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            ..._goalOptions.map((goal) {
              final isSelected = _selectedGoal == goal.title;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  radius: 16,
                  color: isSelected ? AppColors.primaryContainer : Colors.white,
                  onTap: () => setState(() => _selectedGoal = goal.title),
                  child: Row(
                    children: [
                      PastelIconBadge(icon: goal.icon, color: goal.color),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? AppColors.primary : AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              goal.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 6.5 : 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Daily Schedule Preferences
            const Text(
              'Your Daily Routine',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    radius: 16,
                    color: Colors.white,
                    onTap: () => _pickTime(true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.wb_sunny_outlined, size: 18, color: AppColors.yellowColor),
                            SizedBox(width: 6),
                            Text(
                              'Wake-up Time',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimeOfDay(_wakeTime),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    radius: 16,
                    color: Colors.white,
                    onTap: () => _pickTime(false),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.nightlight_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Bedtime',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimeOfDay(_bedtime),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Complete Setup Button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .38),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _saving ? null : _saveAndProceed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Complete Setup',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
