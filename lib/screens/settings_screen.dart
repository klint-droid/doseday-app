import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _testNotification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.showTest();
    messenger.showSnackBar(const SnackBar(content: Text('Test notification sent')));
  }

  Future<void> _rescheduleAll(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final meds = await DatabaseService.instance.getMedications(activeOnly: true);
    await NotificationService.instance.rescheduleAll(meds);
    messenger.showSnackBar(SnackBar(content: Text('Rescheduled reminders for ${meds.length} medication(s)')));
  }

  Future<void> _deleteAll(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.missed),
        title: const Text('Delete all data?'),
        content: const Text('All medications, reminders and dose history on this device will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.missed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await NotificationService.instance.cancelAll();
    await DatabaseService.instance.deleteAllData();
    messenger.showSnackBar(const SnackBar(content: Text('All data deleted')));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const PageHeader(title: 'Settings', subtitle: 'Your app preferences and data.'),
          const SizedBox(height: 20),
          const SectionTitle('Reminders'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Send test notification',
                  subtitle: 'Check that reminders can reach you',
                  onTap: () => _testNotification(context),
                ),
                const Divider(height: 1, indent: 72),
                _tile(
                  icon: Icons.sync_rounded,
                  title: 'Reschedule all reminders',
                  subtitle: 'Use this if reminders stop arriving',
                  onTap: () => _rescheduleAll(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('About'),
          const AppCard(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoBlock(
                  icon: Icons.phone_android_rounded,
                  title: 'Local-first privacy',
                  body:
                      'Your medication details and dose history are stored on this device using SQLite. Nothing is uploaded to a server.',
                ),
                SizedBox(height: 16),
                _InfoBlock(
                  icon: Icons.battery_alert_outlined,
                  title: 'Notification delivery',
                  body:
                      'Allow notifications in your device settings. Timing can vary by a few minutes due to battery optimisation — exclude DoseDay from battery saving for best results.',
                ),
                SizedBox(height: 16),
                _InfoBlock(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Health disclaimer',
                  body:
                      'This app is a reminder and tracking tool, not medical advice. Follow the instructions from your healthcare professional or medication label.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Data'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _tile(
              icon: Icons.delete_forever_outlined,
              title: 'Delete all data',
              subtitle: 'Remove every medication and log',
              color: AppColors.missed,
              onTap: () => _deleteAll(context),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('DoseDay v1.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ],
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: IconBadge(icon: icon, color: color, size: 40),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color == AppColors.primary ? null : color)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: AppColors.textMuted, height: 1.35)),
              ],
            ),
          ),
        ],
      );
}
