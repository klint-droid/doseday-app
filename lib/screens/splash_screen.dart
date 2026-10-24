import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'get_started_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.controller});

  final VideoPlayerController? controller;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;
  Timer? _fallbackTimer;
  bool? _isSetupCompleted;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();

    final preInit = widget.controller;
    if (preInit != null && preInit.value.isInitialized) {
      _videoController = preInit;
      _isVideoInitialized = true;
      preInit.setLooping(false);
      preInit.play();
      preInit.addListener(_checkVideoCompletion);
    } else {
      _initVideo();
    }

    // Play the full 10-second animation (10,006ms video duration + buffer)
    _fallbackTimer = Timer(const Duration(milliseconds: 10500), _navigateToNext);
  }

  void _checkVideoCompletion() {
    final c = _videoController;
    if (c != null && c.value.isInitialized && c.value.duration > Duration.zero) {
      if (c.value.position >= c.value.duration) {
        _navigateToNext();
      }
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset('assets/images/splash_video.mp4');
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _videoController = controller;
        _isVideoInitialized = true;
      });

      controller.setLooping(false);
      await controller.play();
      controller.addListener(_checkVideoCompletion);
    } catch (e) {
      debugPrint('Video splash loading error: $e');
    }
  }

  Future<void> _checkSetupStatus() async {
    try {
      final done = await DatabaseService.instance.hasCompletedSetup();
      if (mounted) _isSetupCompleted = done;
    } catch (_) {
      _isSetupCompleted = false;
    }
  }

  Future<void> _navigateToNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _fallbackTimer?.cancel();
    _videoController?.removeListener(_checkVideoCompletion);
    _videoController?.pause();

    final hasSetup = _isSetupCompleted ?? await DatabaseService.instance.hasCompletedSetup();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) =>
            hasSetup ? const AppShell() : const GetStartedScreen(),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoController?.removeListener(_checkVideoCompletion);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Centered Mascot + Brand + Loading indicator
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mascot in the middle: directs directly to video animation (no initial photo flash)
                SizedBox(
                  width: 240,
                  height: 240,
                  child: (_isVideoInitialized && _videoController != null)
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const SizedBox(width: 240, height: 240),
                ),
                const SizedBox(height: 24),
                // Brand Text
                const Text(
                  'DoseDay',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your daily medication companion',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 32),
                // Loading Spinner
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Skip button in top right safe area
          Positioned(
            top: 12,
            right: 16,
            child: SafeArea(
              child: TextButton(
                onPressed: _navigateToNext,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Skip', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
