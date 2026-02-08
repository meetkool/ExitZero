import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bento_card.dart';

/// "Life Score" card — shows the user's total score with a + button
/// and a teaser for the next reward milestone.
class LifeScoreCard extends StatelessWidget {
  final int score;
  final int nextRewardAt;
  final VoidCallback? onAdd;
  final VoidCallback? onTap;

  const LifeScoreCard({
    super.key,
    this.score = 450,
    this.nextRewardAt = 500,
    this.onAdd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      glassmorphism: true,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top row: title + "+" button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: label + score
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Life Score',
                      style: TextStyle(
                        color: AppColors.cream.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: circular "+" button
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: AppColors.cream,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom: next reward text ──
          Text(
            'Next reward at $nextRewardAt coins',
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
