import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'chat_screen.dart';
import 'feed_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'upload_screen.dart';

/// Holds the app header, all five screens and the custom bottom navigation.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final _screens = const [
    FeedScreen(),
    LibraryScreen(),
    UploadScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _AppHeader(),
            Expanded(
              // IndexedStack keeps each screen's scroll state alive.
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// Top bar: logo + "Scrolz" title on the left, search + avatar on the right.
class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_outlined,
                color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Scrolz',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, size: 26),
            color: AppColors.textPrimary,
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceLight,
            child: Text(
              'JC',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped bottom navigation bar.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _icons = [
    Icons.layers_outlined,     // feed
    Icons.menu_book_outlined,  // library
    Icons.add,                 // upload
    Icons.history,             // activity / recent
    Icons.person_outline,      // profile
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_icons.length, (i) {
          final selected = i == currentIndex;
          final isCenter = i == 2;
          final icon = Icon(_icons[i],
              size: isCenter ? 30 : 26,
              color: selected ? Colors.black : AppColors.textPrimary);
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isCenter ? 58 : 52,
              height: isCenter ? 58 : 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.accent
                    : (isCenter ? AppColors.surfaceLight : Colors.transparent),
              ),
              child: Center(child: icon),
            ),
          );
        }),
      ),
    );
  }
}
