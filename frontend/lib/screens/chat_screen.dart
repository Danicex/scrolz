import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum _ChatMode { instant, expert, vision }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  _ChatMode _mode = _ChatMode.instant;
  final _controller = TextEditingController();

  static const _subtitles = {
    _ChatMode.instant: 'Instant responses for daily conversations',
    _ChatMode.expert: 'Deeper reasoning for complex questions',
    _ChatMode.vision: 'Analyze and discuss images',
  };

  static const _titles = {
    _ChatMode.instant: 'Instant',
    _ChatMode.expert: 'Expert',
    _ChatMode.vision: 'Vision',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(
                  '✨ Start chatting with ${_titles[_mode]}',
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 18),
              _modeSelector(),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _subtitles[_mode]!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        _inputBar(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _modeSelector() {
    Widget chip(_ChatMode mode, IconData icon) {
      final selected = _mode == mode;
      return GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentDim : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color:
                      selected ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                _titles[mode]!,
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          chip(_ChatMode.instant, Icons.bolt),
          chip(_ChatMode.expert, Icons.shield_outlined),
          chip(_ChatMode.vision, Icons.image_outlined),
        ],
      ),
    );
  }

  Widget _inputBar() {
    Widget chip(IconData icon, String label, bool active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message or hold to speak',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                chip(Icons.share_outlined, 'Think', false),
                const SizedBox(width: 8),
                chip(Icons.public, 'Search', true),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.textPrimary,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.graphic_eq),
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
