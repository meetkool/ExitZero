import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

/// Profile-setup / onboarding page shown after a new registration.
/// User can upload an avatar, set a display name, and "initialize" their profile.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _displayNameController = TextEditingController(text: '');
  File? _avatarFile;
  _ButtonState _buttonState = _ButtonState.idle;

  @override
  void initState() {
    super.initState();
    _prefillName();
  }

  /// Pre‐fill the display name from cached user data (the name used at signup).
  Future<void> _prefillName() async {
    final user = await TokenStorage.getUserData();
    if (user != null && user['name'] != null && mounted) {
      _displayNameController.text = user['name'].toString();
    }
  }

  // ── Avatar picker ──
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  // ── Initialize / save profile ──
  Future<void> _initializeSystem() async {
    if (_displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a display name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Processing state
    setState(() => _buttonState = _ButtonState.processing);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No auth token found. Please log in again.');
      }

      // Update display name
      await AuthService.updateName(
        token: token,
        name: _displayNameController.text.trim(),
      );

      // Upload avatar if selected
      if (_avatarFile != null) {
        await AuthService.uploadAvatar(
          token: token,
          filePath: _avatarFile!.path,
        );
      }

      // Re-fetch and cache the updated user profile
      final user = await AuthService.getMe(token);
      await TokenStorage.saveUserData(user);

      if (!mounted) return;

      // Success state
      setState(() => _buttonState = _ButtonState.ready);

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Navigate to dashboard (clear the entire stack)
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _buttonState = _ButtonState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.burnt,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _buttonState = _ButtonState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.burnt,
        ),
      );
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Who are you?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cream,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is how you will appear on the leaderboards.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.teal.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Avatar ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          // Circle
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.dark,
                              border: Border.all(color: AppColors.orange, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.orange.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _avatarFile != null
                                  ? Image.file(
                                      _avatarFile!,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.face_6,
                                      size: 48,
                                      color: AppColors.cream.withValues(alpha: 0.4),
                                    ),
                            ),
                          ),
                          // Camera badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.background,
                                  width: 4,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: AppColors.cream,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to upload photo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.cream.withValues(alpha: 0.5),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Display Name ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'DISPLAY NAME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cream.withValues(alpha: 0.8),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cream.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _displayNameController,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. The Code Breaker',
                        hintStyle: TextStyle(
                          color: AppColors.cream.withValues(alpha: 0.3),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        suffixIcon: Icon(
                          Icons.badge,
                          color: AppColors.cream.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Initialize Button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _buttonState == _ButtonState.idle
                      ? _initializeSystem
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _buttonColor,
                    disabledBackgroundColor: _buttonColor,
                    foregroundColor: AppColors.cream,
                    disabledForegroundColor: AppColors.cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 4,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  child: _buildButtonContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Button helpers ──

  Color get _buttonColor {
    switch (_buttonState) {
      case _ButtonState.idle:
        return AppColors.orange;
      case _ButtonState.processing:
        return AppColors.teal;
      case _ButtonState.ready:
        return const Color(0xFF4CAF50);
    }
  }

  Widget _buildButtonContent() {
    switch (_buttonState) {
      case _ButtonState.idle:
        return const Text('INITIALIZE SYSTEM');
      case _ButtonState.processing:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppColors.cream),
              ),
            ),
            SizedBox(width: 12),
            Text('INITIALIZING...'),
          ],
        );
      case _ButtonState.ready:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.cream),
            SizedBox(width: 8),
            Text('READY'),
          ],
        );
    }
  }
}

enum _ButtonState { idle, processing, ready }
