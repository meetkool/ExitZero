import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
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

  const InterviewsCard({
    super.key,
    this.companyLetter = 'G',
    this.title = 'Google Mock',
    this.schedule = 'Thursday, 10:00 AM',
    this.daysLeft = 2,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      height: 100,
      glassmorphism: true,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // ── Left: company letter panel ──
          Container(
            width: 80,
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
                fontSize: 30,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.teal,
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LEFT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
