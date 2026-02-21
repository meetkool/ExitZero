import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bento_card.dart';

class AlarmCard extends StatelessWidget {
  final VoidCallback? onTap;

  const AlarmCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      height: 100,
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: AppColors.burnt.withValues(alpha: 0.3)),
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
              const Text(
                'ALARM SYSTEM',
                style: TextStyle(
                  color: AppColors.burnt,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Armed & Active',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Waiting for emergency triggers.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.burnt.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.burnt,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
