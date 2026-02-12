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

  @override
  Widget build(BuildContext context) {
    final progress = percentage.clamp(0, 100) / 100.0;

    return BentoCard(
      height: 140, // Match HTML height
      glassmorphism:
          false, // Turn off default glassmorphism to control background precisely
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      padding: const EdgeInsets.all(24),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Left column ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Daily Survival',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1d3326),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Safe',
                      style: TextStyle(
                        color: Color(0xFF4ade80),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeRemaining,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                      fontFamily:
                          'monospace', // Ensure Roboto Mono is used if available scheme matches
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Right: circular progress ring ──
          SizedBox(
            width: 90, // Adjusted size to fit layout better
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(90, 90),
                  painter: _ProgressRingPainter(
                    progress: progress,
                    trackColor: Colors.white.withValues(alpha: 0.05),
                    progressColor: AppColors.orange,
                    strokeWidth: 8,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: AppColors.orange,
                    size: 24,
                  ),
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
