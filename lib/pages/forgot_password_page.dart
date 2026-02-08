import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

/// Forgot-password page with two states: input form and success confirmation.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _linkSent = false;

  void _sendResetLink() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _linkSent = true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _linkSent ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  /// Initial state: email input + send button.
  Widget _buildFormView() {
    return Column(
      children: [
        // Icon + title
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset,
                  color: AppColors.cream,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reset Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter your email to receive recovery instructions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.teal.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Email field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              AppTextField(
                label: 'Email Address',
                placeholder: 'user@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              AppFilledButton(
                label: 'SEND RESET LINK',
                onPressed: _sendResetLink,
                backgroundColor: AppColors.orange,
              ),
            ],
          ),
        ),

        const Spacer(),

        // Back to login
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 18, color: AppColors.burnt),
            label: const Text(
              'Back to Login',
              style: TextStyle(
                color: AppColors.burnt,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Success state: shows confirmation + prototype link to reset page.
  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.mark_email_read,
                color: AppColors.orange,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Check your inbox',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.teal.withValues(alpha: 0.8),
                  height: 1.6,
                ),
                children: [
                  const TextSpan(text: 'We sent instructions to '),
                  TextSpan(
                    text: _emailController.text,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Back to login
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: AppColors.burnt,
                  side: BorderSide(color: AppColors.burnt.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prototype shortcut to reset-password page
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/reset-password');
              },
              child: Text(
                '(Prototype: Click Link)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.cream.withValues(alpha: 0.4),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
