import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class _FeedItem {
  const _FeedItem(this.imageUrl, this.title);
  final String imageUrl;
  final String title;
}

/// Dummy data — replace with your API/repository later.
const _dummyFeed = [
  _FeedItem('https://picsum.photos/seed/forest/400/600', 'Misty forest'),
  _FeedItem('https://picsum.photos/seed/bear/400/600', 'Wildlife'),
  _FeedItem('https://picsum.photos/seed/frost/400/600', 'Frost'),
  _FeedItem('https://picsum.photos/seed/road/400/600', 'Highland road'),
  _FeedItem('https://picsum.photos/seed/city/400/600', 'City lights'),
  _FeedItem('https://picsum.photos/seed/woods/400/600', 'The woods'),
];

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 0.75,
      ),
      itemCount: _dummyFeed.length,
      itemBuilder: (context, i) => _FeedCard(item: _dummyFeed[i]),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final _FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          item.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surfaceLight,
            child: const Icon(Icons.image_outlined,
                color: AppColors.textSecondary),
          ),
        ),
        const Positioned(
          left: 8,
          bottom: 8,
          child: Icon(Icons.play_arrow, color: Colors.white, size: 26),
        ),
      ],
    );
  }
}
