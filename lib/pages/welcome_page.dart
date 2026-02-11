import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

/// Welcome / landing page with Log In, Create Account and Google buttons.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Top section: Logo + tagline ──
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.asset(
                        'assets/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ExitZero',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cream,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Verify. Don't Trust.",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.cream.withValues(alpha: 0.6),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom section: Buttons ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Column(
              children: [
                // Google button
                AppFilledButton(
                  label: 'Continue with Google',
                  onPressed: () {
                    // TODO: Google Sign-In
                  },
                  backgroundColor: Colors.white,
                  textColor: Colors.grey.shade900,
                  leadingWidget: Image.network(
                    'https://www.svgrepo.com/show/475656/google-color.svg',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.g_mobiledata, size: 24),
                  ),
                ),
                const SizedBox(height: 12),

                const AppDividerWithText(),
                const SizedBox(height: 12),

                // Log In
                AppFilledButton(
                  label: 'Log In',
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  backgroundColor: AppColors.orange,
                  textColor: AppColors.dark,
                ),
                const SizedBox(height: 12),

                // Create Account
                AppOutlinedButton(
                  label: 'Create Account',
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
