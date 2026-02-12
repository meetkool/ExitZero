import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../services/auth_service.dart';

/// Reset password page: token + new password + confirm password.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _tokenController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _mismatchError;
  bool _isLoading = false;

  Future<void> _submitNewPassword() async {
    setState(() => _mismatchError = null);

    if (!_formKey.currentState!.validate()) return;

    if (_newPassController.text != _confirmPassController.text) {
      setState(() => _mismatchError = 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.resetPassword(
        resetToken: _tokenController.text.trim(),
        password: _newPassController.text,
        passwordConfirm: _confirmPassController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.burnt,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Please check your connection.'),
          backgroundColor: AppColors.burnt,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set New Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cream,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the reset token from your email and your new password.',
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

            // ── Form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Reset Token',
                        placeholder: 'Paste token from email',
                        controller: _tokenController,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Please enter the reset token' : null,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'New Password',
                        placeholder: 'Min. 8 characters',
                        obscureText: true,
                        controller: _newPassController,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'Must be at least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'Confirm Password',
                        placeholder: 'Re-enter password',
                        obscureText: true,
                        controller: _confirmPassController,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      if (_mismatchError != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              _mismatchError!,
                              style: const TextStyle(
                                color: AppColors.burnt,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Submit ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitNewPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.6),
                    foregroundColor: AppColors.cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(AppColors.cream),
                          ),
                        )
                      : const Text('UPDATE PASSWORD'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
