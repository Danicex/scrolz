// lib/screens/library_screen.dart

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/api_helper.dart';
import '../../models/library_models.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();

  List<Project> _projects = [];
  bool _loading = true;
  String? _error;
  bool _isGrid = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final res = await ApiHelper.get<List<Project>>(
      '/library/all_projects',
      parser: (json) => extractList(json)
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res.isSuccess) {
        _projects = res.data ?? [];
        _error = null;
      } else if (!silent || _projects.isEmpty) {
        _error = res.error;
      }
    });

    // Pull-to-refresh failed but we still have old data: tell the user without wiping the list.
    if (res.isFailure && silent && _projects.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.error!)));
    }
  }

  void _open(Project p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(project: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _projects
        .where((p) => p.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search your library',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _iconBtn(Icons.grid_view_rounded, _isGrid,
                  () => setState(() => _isGrid = true)),
              const SizedBox(width: 8),
              _iconBtn(Icons.view_list_outlined, !_isGrid,
                  () => setState(() => _isGrid = false)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _body(filtered)),
        ],
      ),
    );
  }

  Widget _body(List<Project> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (items.isEmpty) {
      return _MessageState(
        icon: Icons.menu_book_outlined,
        message: _query.isEmpty
            ? 'Your library is empty.'
            : 'No projects match "$_query".',
        actionLabel: _query.isEmpty ? 'Refresh' : null,
        onAction: _query.isEmpty ? _load : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _isGrid ? _grid(items) : _list(items),
    );
  }

  Widget _grid(List<Project> items) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ProjectCard(
        project: items[i],
        onTap: () => _open(items[i]),
      ),
    );
  }

  Widget _list(List<Project> items) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _ProjectRow(
        project: items[i],
        onTap: () => _open(items[i]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

// ---------------------------------------------------------------- widgets

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _CoverImage(project: project)),
          const SizedBox(height: 8),
          Text(
            project.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            project.dateLabel,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 84,
            child: _CoverImage(project: project),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  project.dateLabel,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.project});

  final Project project;

  static const _palette = [
    Color(0xFF1E2B1F),
    Color(0xFF8A6B33),
    Color(0xFF3A2438),
    Color(0xFF24313E),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[project.id % _palette.length];

    final fallback = Container(
      color: color,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        project.title,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );

    final url = project.coverUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox.expand(
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : Container(color: color),
              ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}