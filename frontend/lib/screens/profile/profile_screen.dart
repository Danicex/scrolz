// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';

import '../../models/user_models.dart';
import '../../core/utils/api_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/api_view.dart';
import 'activity_screen.dart';
import 'billing_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

class _MenuEntry {
  const _MenuEntry(this.icon, this.title, this.subtitle, this.builder);
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

final _menu = <_MenuEntry>[
  _MenuEntry(Icons.settings_outlined, 'Settings', 'Preferences and security',
      (_) => const SettingsScreen()),
  _MenuEntry(Icons.history, 'Activity', 'Recent history and logs',
      (_) => const ActivityScreen()),
  _MenuEntry(Icons.credit_card_outlined, 'Billing', 'Payments and subscriptions',
      (_) => const BillingScreen()),
  _MenuEntry(Icons.help_outline, 'Help & Support', 'FAQs and customer service',
      (_) => const HelpScreen()),
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ApiView<UserProfile>(
      // Token is attached automatically by ApiHelper's interceptor.
      load: () => ApiHelper.get<UserProfile>('/user/me', parser: UserProfile.fromJson),
      builder: (context, user) => _ProfileBody(user: user),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.accentDim,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.accent,
                    child: Icon(Icons.bolt, size: 14, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            user.displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(user.email, style: TextStyle(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(radius: 4, backgroundColor: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Member since ${formatDate(user.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        ..._menu.map((e) => _MenuCard(entry: e)),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: entry.builder)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, color: AppColors.textPrimary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(entry.subtitle,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
