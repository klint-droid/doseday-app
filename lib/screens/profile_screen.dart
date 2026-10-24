import 'package:flutter/material.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/notifications_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = DatabaseService.instance;
  UserProfile? _profile;
  List<Medication> _medications = [];
  List<DoseLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _db.changes.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    _db.changes.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final profile = await _db.getUserProfile();
    final meds = await _db.getMedications(activeOnly: true);
    final logs = await _db.getAllLogs();
    if (mounted) {
      setState(() {
        _profile = profile;
        _medications = meds;
        _logs = logs;
        _loading = false;
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editProfileDialog() async {
    final profile = _profile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.name);
    final emailController = TextEditingController(text: profile.email);
    final emergencyController = TextEditingController(text: profile.emergencyContact ?? '');
    String selectedAvatar = profile.avatarPath;
    String selectedGoal = profile.healthGoal;

    final avatarOptions = [
      'assets/images/user_avatar.png',
      'assets/images/app_logo.png',
      'assets/images/onboarding_hero.png',
    ];

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Avatar Choice
                    const Text('Choose Avatar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: avatarOptions.map((path) {
                        final isSelected = selectedAvatar == path;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedAvatar = path),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 2.6,
                              ),
                            ),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(shape: BoxShape.circle),
                              child: ClipOval(
                                child: Image.asset(path, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Name Field
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Email Field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Emergency Contact
                    TextField(
                      controller: emergencyController,
                      decoration: InputDecoration(
                        labelText: 'Emergency Contact / Doctor',
                        prefixIcon: const Icon(Icons.emergency_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx, true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (updated == true) {
      final newName = nameController.text.trim().isEmpty ? profile.name : nameController.text.trim();
      final newEmail = emailController.text.trim().isEmpty ? profile.email : emailController.text.trim();
      final newEmergency = emergencyController.text.trim().isEmpty ? null : emergencyController.text.trim();

      final newProfile = profile.copyWith(
        name: newName,
        email: newEmail,
        avatarPath: selectedAvatar,
        healthGoal: selectedGoal,
        emergencyContact: newEmergency,
        isSetupCompleted: true,
      );

      await _db.saveUserProfile(newProfile);
      _toast('Profile updated successfully');
    }
    nameController.dispose();
    emailController.dispose();
    emergencyController.dispose();
  }

  Future<void> _toggleSound(bool val) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(soundEnabled: val);
    await _db.saveUserProfile(updated);
  }

  Future<void> _toggleVibration(bool val) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(vibrationEnabled: val);
    await _db.saveUserProfile(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile!;
    final taken = _logs.where((l) => l.status == DoseStatus.taken).length;
    final total = _logs.length;
    final adherenceRate = total == 0 ? 1.0 : (taken / total);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          children: [
            // Top Bar
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Profile & Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _editProfileDialog,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  tooltip: 'Edit Profile',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Profile Card Hero
            AppCard(
              radius: 24,
              color: Colors.white,
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
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
                            profile.avatarPath,
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
                        child: GestureDetector(
                          onTap: _editProfileDialog,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Health Goal Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          profile.healthGoal,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    radius: 18,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    child: Column(
                      children: [
                        const Icon(Icons.medication_rounded, color: AppColors.primary, size: 26),
                        const SizedBox(height: 8),
                        Text(
                          '${_medications.length}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Active Meds',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    radius: 18,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.greenColor, size: 26),
                        const SizedBox(height: 8),
                        Text(
                          '${(adherenceRate * 100).round()}%',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Adherence',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    radius: 18,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    child: Column(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.pinkColor, size: 26),
                        const SizedBox(height: 8),
                        const Text(
                          '7 Days',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Streak',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Daily Schedule Preferences Card
            const Text(
              'Daily Schedule Routine',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              radius: 18,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const PastelIconBadge(icon: Icons.wb_sunny_rounded, color: AppColors.yellowColor),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Morning Wake-up',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        profile.wakeTime,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  Row(
                    children: [
                      const PastelIconBadge(icon: Icons.nightlight_round, color: AppColors.primary),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Evening Bedtime',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        profile.bedtime,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Reminder & Notification Preferences
            const Text(
              'Notification & Reminders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              radius: 18,
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Notifications & Alerts Center', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Test alerts, check permissions & view schedule', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => NotificationsSheet.show(context),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  SwitchListTile(
                    title: const Text('Sound Alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Play sound on scheduled dose reminder', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    value: profile.soundEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _toggleSound,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  SwitchListTile(
                    title: const Text('Vibration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Vibrate phone when alarm triggers', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    value: profile.vibrationEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _toggleVibration,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Care & Emergency Contact
            const Text(
              'Emergency / Doctor Care',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              radius: 18,
              color: Colors.white,
              onTap: _editProfileDialog,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const PastelIconBadge(icon: Icons.emergency_rounded, color: AppColors.pinkColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Primary Care Physician',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.emergencyContact ?? 'Tap to add doctor or emergency contact',
                          style: TextStyle(
                            fontSize: 12,
                            color: profile.emergencyContact != null ? AppColors.text : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App Information
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'DoseDay v1.0.0',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Your Offline-First Smart Medication Manager',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
