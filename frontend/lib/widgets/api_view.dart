// lib/widgets/api_view.dart
import 'package:flutter/material.dart';

import '../core/utils/api_helper.dart';

/// Runs [load] once, shows a spinner while waiting, an error + retry on failure,
/// and calls [builder] with the data on success. Pull-to-refresh is built in
/// when the builder returns a scrollable.
class ApiView<T> extends StatefulWidget {
  const ApiView({
    super.key,
    required this.load,
    required this.builder,
  });

  final Future<ApiResult<T>> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<ApiView<T>> createState() => _ApiViewState<T>();
}

class _ApiViewState<T> extends State<ApiView<T>> {
  bool _loading = true;
  String? _error;
  T? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final res = await widget.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = res.error;
      _data = res.data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _data == null) {
      return _ErrorState(message: _error ?? 'No data found.', onRetry: _fetch);
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(silent: true),
      child: widget.builder(context, _data as T),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDCF516),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded card used across the profile sub-pages.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

/// Small grey section title above a card.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
