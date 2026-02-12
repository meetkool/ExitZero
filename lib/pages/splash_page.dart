import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

/// Splash screen: shows the ExitZero logo and a loader,
/// then checks for a saved token to auto‐login or goes to welcome.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Give the splash animation at least 2 seconds to play.
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        // Validate the token by hitting /users/me
        final user = await AuthService.getMe(token);
        await TokenStorage.saveUserData(user);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/dashboard');
        return;
      }
    } catch (_) {
      // Token invalid or network error — clear and go to welcome.
      await TokenStorage.clearAll();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/welcome');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Logo + tagline (centered)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.orange.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Image.asset(
                            'assets/app_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'ExitZero',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cream,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seamless exits. Zero hassle.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.cream.withValues(alpha: 0.6),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Loader at the bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Column(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: const AlwaysStoppedAnimation(AppColors.orange),
                      backgroundColor: AppColors.cream.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading System...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.cream.withValues(alpha: 0.7),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
