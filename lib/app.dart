import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'theme/app_theme.dart';
import 'pages/splash_page.dart';
import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/profile_page.dart';
import 'pages/schedule_mock_page.dart';
import 'pages/alarm_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Root widget that configures the theme and all named routes.
class ExitZeroApp extends StatefulWidget {
  const ExitZeroApp({super.key});

  @override
  State<ExitZeroApp> createState() => _ExitZeroAppState();
}

class _ExitZeroAppState extends State<ExitZeroApp> {
  @override
  void initState() {
    super.initState();
    Alarm.ringStream.stream.listen((alarmSettings) {
      // Navigate to alarm page when ring stream fires
      // Check if we are already on that page to avoid stacking or popping issues
      bool isCurrentlyAlarmPage = false;
      navigatorKey.currentState?.popUntil((route) {
        if (route.settings.name == '/alarm') {
          isCurrentlyAlarmPage = true;
        }
        return true; 
      });

      if (!isCurrentlyAlarmPage) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/alarm'),
            builder: (context) => AlarmPage(alarmId: alarmSettings.id),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ExitZero',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus},
      ),
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/reset-password': (context) => const ResetPasswordPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/profile': (context) => const ProfilePage(),
        '/schedule-mock': (context) => const ScheduleMockPage(),
      },
    );
  }
}
