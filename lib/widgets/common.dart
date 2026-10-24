import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Clean card with smooth rounded corners matching Slide 1 & 2
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color = AppColors.surface,
    this.radius = 20,
    this.onTap,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.border, width: 1.1),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .025),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Large page title + subtitle used at the top of tabs
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.subtitle, this.trailing});

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            ?action,
          ],
        ),
      );
}

/// Circular progress ring matching the Figma card & task groups
class CircularPercentRing extends StatelessWidget {
  const CircularPercentRing({
    super.key,
    required this.percent,
    this.size = 72,
    this.strokeWidth = 7,
    this.ringColor = Colors.white,
    this.trackColor = Colors.white24,
    this.textStyle,
    this.label,
  });

  final double percent; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color ringColor;
  final Color trackColor;
  final TextStyle? textStyle;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? '${(percent * 100).clamp(0, 100).round()}%';
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percent.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
            Text(
              text,
              style: textStyle ??
                  const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastel square/rounded icon badge
class PastelIconBadge extends StatelessWidget {
  const PastelIconBadge({
    super.key,
    required this.icon,
    this.bg,
    required this.color,
    this.size = 46,
    this.radius = 14,
  });

  final IconData icon;
  final Color? bg;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg ?? color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(icon, color: color, size: size * .52),
      );
}

// IconBadge alias for backward compatibility
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) => PastelIconBadge(
        icon: icon,
        bg: background ?? color.withValues(alpha: .12),
        color: color,
        size: size,
      );
}

/// Small count pill badge next to section headings (e.g. "In Progress [6]")
class CountPill extends StatelessWidget {
  const CountPill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      );
}

/// Status Pill matching Figma: "Done", "In Progress", "To-do"
class FigmaStatusPill extends StatelessWidget {
  const FigmaStatusPill({
    super.key,
    required this.label,
    required this.status,
  });

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final bg = AppColors.statusBg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// StatusPill alias
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
            Text(
              label.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: .3),
            ),
          ],
        ),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, color: color, size: 38),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.text)),
            Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.title, required this.subtitle, required this.icon, this.action});

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              IconBadge(icon: icon, size: 54),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          ),
        ),
      );
}
