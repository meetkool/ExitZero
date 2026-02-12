import 'package:flutter/material.dart';
import '../../../widgets/bento_card.dart';

/// Outreach card showing emails sent / target.
class OutreachCard extends StatelessWidget {
  final int sent;
  final int total;

  const OutreachCard({
    super.key,
    this.sent = 2,
    this.total = 5,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      height: 120, // Match HTML height
      glassmorphism: false,
      backgroundColor: Colors.white.withValues(alpha: 0.04), // tile bg
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)), // tile border
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top: send icon circle ──
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF126782).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, color: Color(0xFF126782), size: 18),
          ),

          // ── Bottom: count + label ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$sent/$total',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              Text(
                'Emails Sent',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
