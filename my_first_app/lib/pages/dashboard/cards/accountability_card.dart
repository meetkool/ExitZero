import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bento_card.dart';

/// "Accountability Engine" card with a live countdown, scanline animation,
/// and a pulsing warning icon.
class AccountabilityCard extends StatefulWidget {
  const AccountabilityCard({super.key});

  @override
  State<AccountabilityCard> createState() => _AccountabilityCardState();
}

class _AccountabilityCardState extends State<AccountabilityCard>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _scanlineController;
  late AnimationController _pulseController;
  String _countdown = '';

  @override
  void initState() {
    super.initState();

    // Countdown timer
    _updateCountdown();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());

    // Scanline sweep (3 s loop)
    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulse for warning icon (1.5 s loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final diff = endOfDay.difference(now);

    if (diff.isNegative) {
      setState(() => _countdown = '00:00:00');
      return;
    }

    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    setState(() => _countdown = '$h:$m:$s');
  }

  @override
  void dispose() {
    _timer.cancel();
    _scanlineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: const Color(0xFF220000),
      border: Border.all(color: AppColors.burnt),
      boxShadow: [
        BoxShadow(
          color: AppColors.burnt.withValues(alpha: 0.1),
          blurRadius: 30,
          spreadRadius: -5,
        ),
      ],
      backgroundDecoration: _buildScanline(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: label + timer
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  FadeTransition(
                    opacity: _pulseController
                        .drive(Tween(begin: 0.4, end: 1.0)),
                    child: const Icon(Icons.warning,
                        color: AppColors.burnt, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ACCOUNTABILITY ENGINE',
                    style: TextStyle(
                      color: AppColors.burnt,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _countdown,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Time remaining',
                style: TextStyle(
                  color: AppColors.burnt.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),

          // Right: ARMED badge
          Text(
            'ARMED',
            style: TextStyle(
              color: AppColors.burnt.withValues(alpha: 0.8),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Scanline overlay that sweeps vertically.
  Widget _buildScanline() {
    return AnimatedBuilder(
      animation: _scanlineController,
      builder: (context, child) {
        return Positioned.fill(
          child: Align(
            alignment:
                Alignment(0, -1 + 2 * _scanlineController.value),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.burnt.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
