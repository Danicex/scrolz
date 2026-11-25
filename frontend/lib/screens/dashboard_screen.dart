import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'ai_chat/chat_screen.dart';
import 'feed/feed_screen.dart';
import 'library/library_screen.dart';
import 'profile/profile_screen.dart';
import 'upload/upload_screen.dart';

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
            child: Image.asset(
    'assets/darklogo.png',
    fit: BoxFit.cover,
  ),
          ),
          const SizedBox(width: 12),
         
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
    Icons.layers_outlined,          // feed
    Icons.local_library_outlined,   // library (changed)
    Icons.add,                      // upload
    Icons.auto_awesome_outlined,    // ai (changed from history)
    Icons.person_outline,           // profile
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      // 1. Reduced outer margins slightly and tightened vertical padding
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12), 
      padding: const EdgeInsets.symmetric(vertical: 6), 
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32), // Adjusted radius to match smaller height
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_icons.length, (i) {
          final selected = i == currentIndex;
          final isCenter = i == 2;
          final icon = Icon(
            _icons[i],
            // 2. Reduced icon sizes
            size: isCenter ? 28 : 24, 
            color: selected ? Colors.black : AppColors.textPrimary,
          );

          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              // 3. Reduced circle background width & height
              width: isCenter ? 44 : 38, 
              height: isCenter ? 44 : 38, 
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
