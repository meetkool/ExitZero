import 'package:flutter/material.dart';
import '../../../widgets/bento_card.dart';

/// Full-width mock-interview card with a company letter badge on the left.
class InterviewsCard extends StatelessWidget {
  /// The big letter shown in the left panel (e.g. "G" for Google).
  final String companyLetter;

  /// Card title (e.g. "Google Mock").
  final String title;

  /// Date / time label (e.g. "Thursday, 10:00 AM").
  final String schedule;

  /// How many days until the interview.
  final int daysLeft;

  /// Role title (e.g. "SDE-1").
  final String role;

  const InterviewsCard({
    super.key,
    this.companyLetter = 'G',
    this.title = 'Google Mock',
    this.role = 'System Design',
    this.schedule = 'Thursday, 10:00 AM',
    this.daysLeft = 2,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      height: 90, // Match HTML
      glassmorphism: false,
      backgroundColor: Colors.white.withValues(alpha: 0.04), // tile bg
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)), // tile border
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // ── Left: company letter panel ──
          Container(
            width: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              companyLetter,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),

          // ── Right: info ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title + schedule
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF126782),
                          // fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Days left
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$daysLeft days',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LEFT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
