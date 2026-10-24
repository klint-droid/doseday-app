import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize video controller so splash animation plays immediately on frame 1
  VideoPlayerController? splashController;
  try {
    splashController = VideoPlayerController.asset('assets/images/splash_video.mp4');
    await splashController.initialize();
  } catch (e) {
    debugPrint('Splash video pre-init: $e');
  }

  await NotificationService.instance.initialize();
  try {
    await DatabaseService.instance.markPastDosesMissed();
    // Re-register daily reminders on every launch so they stay in sync.
    final meds = await DatabaseService.instance.getMedications(activeOnly: true);
    await NotificationService.instance.rescheduleAll(meds);
  } catch (e) {
    debugPrint('Startup sync failed: $e');
  }

  runApp(MedicationReminderApp(splashController: splashController));
}
