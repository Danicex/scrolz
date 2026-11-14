import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class _MenuEntry {
  const _MenuEntry(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

const _menu = [
  _MenuEntry(Icons.settings_outlined, 'Settings', 'Preferences and security'),
  _MenuEntry(Icons.history, 'Activity', 'Recent history and logs'),
  _MenuEntry(Icons.credit_card_outlined, 'Billing', 'Payments and subscriptions'),
  _MenuEntry(Icons.help_outline, 'Help & Support', 'FAQs and customer service'),
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.surfaceLight,
                child: Text('AM',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
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
        const Center(
          child: Text('Alex Mercer',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('alex.mercer@example.com',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.accent),
                SizedBox(width: 8),
                Text('Pro active',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w600)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
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
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
