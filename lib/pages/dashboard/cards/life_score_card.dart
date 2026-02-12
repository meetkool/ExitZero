import 'package:flutter/material.dart';
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
      height: 120, // Match HTML
      glassmorphism: false,
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)), // tile border
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top row: Label and + button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Life Score'.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom: Score and reward text ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Next reward at $nextRewardAt',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
