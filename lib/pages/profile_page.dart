
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// Static placeholder profile. The app no longer has a login system, so
  /// there is no signed-in user to fetch from the backend.
  static const Map<String, String> _user = {
    'name': 'User',
    'email': 'user@example.com',
  };

  /// Locally picked avatar. Not persisted — there is nowhere to upload it to.
  File? _avatarFile;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (picked == null) return;

    if (mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user['name']!;
    final email = _user['email']!;

    return Scaffold(
      backgroundColor: const Color(0xFF001E2E), // brand-deep
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pushNamed('/settings'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: AppColors.cream,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Content ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Column(
                  children: [
                    // ── Profile Card ──
                    _buildProfileCard(name, email),
                    const SizedBox(height: 24),

                    // ── Stats Grid ──
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.local_fire_department,
                            iconColor: AppColors.orange,
                            bgOpacity: 0.2, // orange/20
                            value: '15 Days',
                            label: 'PERSONAL BEST',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.code,
                            iconColor: AppColors.teal,
                            bgOpacity: 0.2, // teal/20
                            value: '142 Total',
                            label: 'LEETCODE SUBS',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Menu List ──
                    _buildMenuSection([
                      _MenuItem(
                        icon: Icons.link,
                        label: 'LeetCode Username',
                        value: 'meet_b', // Payload
                      ),
                      _MenuItem(
                        icon: Icons.card_membership,
                        label: 'Subscription',
                        value: 'Pro Plan',
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.orange, width: 3),
                  color: AppColors.dark,
                  image: _avatarFile != null
                      ? DecorationImage(
                          image: FileImage(_avatarFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _avatarFile == null
                    ? Icon(
                        Icons.person,
                        size: 48,
                        color: AppColors.cream.withValues(alpha: 0.5),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF001E2E), // matches bg
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.cream.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              // TODO: Edit profile logic
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required double bgOpacity,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: bgOpacity),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.cream.withValues(alpha: 0.6),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.vertical(
                top: index == 0 ? const Radius.circular(28) : Radius.zero,
                bottom: isLast ? const Radius.circular(28) : Radius.zero,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: AppColors.cream.withValues(alpha: 0.6),
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.value != null) ...[
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.cream.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              item.value!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ] else
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.cream.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? value;

  _MenuItem({
    required this.icon,
    required this.label,
    this.value,
  });
}
