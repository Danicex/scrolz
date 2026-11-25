// lib/screens/profile/help_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/api_view.dart';

class _Faq {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
}

// Dummy FAQ content – swap for real copy later.
const _faqs = [
  _Faq('How do tokens work?',
      'Tokens are used each time you generate a video. The more content you generate, the more tokens are used. You can check your balance anytime under Billing.'),
  _Faq('How do I top up my tokens?',
      'Go to Profile → Billing and choose a top-up amount. You can also turn on auto billing so your balance refills when it runs low.'),
  _Faq('Can I change my voice or captions?',
      'Yes. Open Profile → Settings to review your voice, background sound, caption style and video template.'),
  _Faq('Why did my video fail to generate?',
      'Failures are usually caused by a poor connection or unsupported content. Check Profile → Activity for the status, then try again. Tokens for failed generations are not charged.'),
  _Faq('How do I delete my account?',
      'Contact support using the options below and we will process your request within a few days.'),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          const SectionLabel('Frequently asked questions'),
          InfoCard(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      title: Text(_faqs[i].q,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      children: [
                        Text(_faqs[i].a,
                            style: TextStyle(
                                color: AppColors.textSecondary, height: 1.45)),
                      ],
                    ),
                  ),
                  if (i != _faqs.length - 1)
                    Divider(
                        height: 1,
                        color: AppColors.divider.withOpacity(0.5)),
                ],
              ],
            ),
          ),
          const SectionLabel('Still need help?'),
          InfoCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact support',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text('We usually reply within 24 hours.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {}, // TODO: open mailto / support chat
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Email support'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
