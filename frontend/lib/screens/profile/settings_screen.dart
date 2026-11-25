// lib/screens/profile/settings_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_models.dart';
import '../../core/utils/api_helper.dart';
import '../../widgets/api_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ApiView<UserSettings>(
        load: () => ApiHelper.get<UserSettings>('/user/settings',
            parser: UserSettings.fromJson),
        builder: (context, s) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            const SectionLabel('Video'),
            InfoCard(
              child: Column(
                children: [
                  _Row(Icons.record_voice_over_outlined, 'Voice', s.voice),
                  const _Divider(),
                  _Row(Icons.music_note_outlined, 'Background sound', s.bgSound),
                  const _Divider(),
                  _Row(
                    Icons.palette_outlined,
                    'Background color',
                    s.bgColor.toUpperCase(),
                    trailing: _Swatch(hex: s.bgColor),
                  ),
                ],
              ),
            ),
            const SectionLabel('Captions'),
            InfoCard(
              child: Column(
                children: [
                  _Row(Icons.text_fields, 'Font', s.captionFont),
                  const _Divider(),
                  _Row(Icons.format_color_text, 'Color', s.captionColor),
                  const _Divider(),
                  _Row(Icons.format_size, 'Size', '${s.captionSize} pt'),
                ],
              ),
            ),
            const SectionLabel('Template'),
            InfoCard(
              child: _Row(Icons.dashboard_customize_outlined, 'Video template',
                  s.videoTemplate),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          Text(value, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.hex});

  final String hex;

  Color _parse() {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _parse(),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.divider, width: 1.5),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        color: AppColors.divider.withOpacity(0.5),
      );
}
