// lib/screens/profile/billing_screen.dart
import 'package:flutter/material.dart';

import '../../models/user_models.dart';
import '../../core/utils/api_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/api_view.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: ApiView<UserBilling>(
        load: () => ApiHelper.get<UserBilling>('/user/billing',
            parser: UserBilling.fromJson),
        builder: (context, b) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.toll_outlined,
                            color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text('Token balance',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _group(b.tokenBalance),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Updated ${formatDate(b.updatedAt)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
              const SectionLabel('Preferences'),
              InfoCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.autorenew, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Auto billing',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text('Top up tokens automatically when low',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: b.autoBilling
                            ? AppColors.accent
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        b.autoBilling ? 'On' : 'Off',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              b.autoBilling ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 12500 -> "12,500"
  static String _group(int n) => n.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
}
