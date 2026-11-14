import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class _Book {
  const _Book(this.title, this.author, this.rating, this.color);
  final String title;
  final String author;
  final double rating;
  final Color color;
}

/// Dummy data — replace with your API/repository later.
const _books = [
  _Book('The Design of Everyday Things', 'Don Norman', 4.8,
      Color(0xFF1E2B1F)),
  _Book('Grid Systems', 'Josef Müller-Brockmann', 4.5,
      Color(0xFF8A6B33)),
  _Book('Thinking with Type', 'Ellen Lupton', 4.7, Color(0xFF3A2438)),
  _Book('Refactoring UI', 'Adam Wathan', 4.6, Color(0xFF24313E)),
];

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search your library',
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _iconBtn(Icons.filter_list, false),
            const SizedBox(width: 8),
            _iconBtn(Icons.grid_view_rounded, true),
            const SizedBox(width: 8),
            _iconBtn(Icons.view_list_outlined, false),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.55,
          ),
          itemCount: _books.length,
          itemBuilder: (context, i) => _BookCard(book: _books[i]),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, bool active) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: active ? AppColors.accentDim : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: active ? AppColors.accent : AppColors.textPrimary,
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final _Book book;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: book.color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            size: 12, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(
                          book.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 16,
                  child: Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}
