import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bento_card.dart';

/// LeetCode submission card — compact half-width version with danger glass
/// styling, refresh button, and pulsing "Submission Missing" indicator.
class LeetCodeCard extends StatefulWidget {
  final int submissions;
  final int target;
  final VoidCallback? onRefresh;

  const LeetCodeCard({
    super.key,
    this.submissions = 0,
    this.target = 1,
    this.onRefresh,
  });

  @override
  State<LeetCodeCard> createState() => _LeetCodeCardState();
}

class _LeetCodeCardState extends State<LeetCodeCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();

    // Pulsing dot (1.5 s loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Refresh spin (1 s, one-shot)
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    _refreshController.forward(from: 0);
    widget.onRefresh?.call();
  }

  bool get _isMissing => widget.submissions < widget.target;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      height: 150,
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: const Alignment(-0.5, -1),
        end: const Alignment(0.5, 1),
        colors: [
          AppColors.burnt.withValues(alpha: 0.15),
          const Color(0xFF1E0000).withValues(alpha: 0.4),
        ],
      ),
      border: Border.all(color: AppColors.burnt.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top row: icon circle + refresh button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Code icon circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.burnt.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.code, color: AppColors.burnt, size: 22),
              ),
              // Refresh button
              GestureDetector(
                onTap: _handleRefresh,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: RotationTransition(
                    turns: _refreshController,
                    child: Icon(
                      Icons.refresh,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom: label + count + status ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEETCODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream.withValues(alpha: 0.6),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.submissions}/${widget.target}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              if (_isMissing) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    FadeTransition(
                      opacity:
                          _pulseController.drive(Tween(begin: 0.3, end: 1.0)),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.burnt,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Submission Missing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.burnt,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
