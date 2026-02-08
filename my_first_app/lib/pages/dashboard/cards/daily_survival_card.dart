import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bento_card.dart';

/// "Daily Survival" card with a circular progress ring and status badge.
class DailySurvivalCard extends StatelessWidget {
  final int percentage;
  final String status; // e.g. "Safe", "At Risk"
  final String timeRemaining;
  final VoidCallback? onTap;

  const DailySurvivalCard({
    super.key,
    this.percentage = 72,
    this.status = 'Safe',
    this.timeRemaining = '4 hrs remaining',
    this.onTap,
  });

  Color get _statusColor {
    switch (status.toLowerCase()) {
      case 'safe':
        return const Color(0xFF4ADE80); // green-400
      case 'at risk':
        return AppColors.burnt;
      default:
        return AppColors.orange;
    }
  }

  Color get _statusBg {
    switch (status.toLowerCase()) {
      case 'safe':
        return const Color(0xFF22C55E).withValues(alpha: 0.2); // green-500/20
      case 'at risk':
        return AppColors.burnt.withValues(alpha: 0.2);
      default:
        return AppColors.orange.withValues(alpha: 0.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = percentage.clamp(0, 100) / 100.0;

    return BentoCard(
      height: 160,
      glassmorphism: true,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Row(
        children: [
          // ── Left column ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: title + percentage + badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Survival',
                      style: TextStyle(
                        color: AppColors.cream.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom: time remaining
                Text(
                  timeRemaining,
                  style: TextStyle(
                    color: AppColors.cream.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // ── Right: circular progress ring ──
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(112, 112),
                  painter: _ProgressRingPainter(
                    progress: progress,
                    trackColor: Colors.white.withValues(alpha: 0.1),
                    progressColor: AppColors.orange,
                    strokeWidth: 8,
                  ),
                ),
                const Icon(
                  Icons.local_fire_department,
                  color: AppColors.orange,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a circular progress ring (track + arc).
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from 12 o'clock
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}
