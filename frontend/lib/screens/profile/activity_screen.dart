// lib/screens/profile/activity_screen.dart
import 'package:flutter/material.dart';

import '../../models/user_models.dart';
import '../../core/utils/api_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/api_view.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: ApiView<List<UserActivity>>(
        load: () => ApiHelper.get<List<UserActivity>>('/user/activity',
            parser: UserActivity.listFromJson),
        builder: (context, items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                _Empty(),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ActivityTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final UserActivity item;

  IconData get _icon {
    final a = item.action.toLowerCase();
    if (a.contains('video')) return Icons.movie_creation_outlined;
    if (a.contains('token') || a.contains('top')) return Icons.toll_outlined;
    return Icons.bolt_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.action,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(formatDate(item.createdAt),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          _StatusChip(status: item.status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case 'completed':
        bg = AppColors.accentDim;
        fg = AppColors.accent;
        break;
      case 'failed':
        bg = const Color(0x33E14535);
        fg = const Color(0xFFE14535);
        break;
      default: // pending, processing, etc.
        bg = AppColors.surfaceLight;
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        prettify(status),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.history, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text('No activity yet', style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}
