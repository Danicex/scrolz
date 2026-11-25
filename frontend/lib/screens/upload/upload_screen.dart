// lib/screens/upload/upload_screen.dart
//
// pubspec.yaml:
//   file_picker: ^8.0.0
//   shared_preferences: ^2.2.0
//   dio: any (already used by your ApiHelper)
//
// ApiHelper members this file assumes (adapt names if yours differ):
//   ApiHelper.showMessageDialog(context, title:, message:, isError:)
//   ApiHelper.confirm(context, title:, message:, confirmText:) -> Future<bool>
//   ApiHelper.upload<T>(path, fields:, context:, parser:) -> Future<Result<T>>
//   ApiHelper.get<T>(path, showError:, parser:)           -> Future<Result<T>>
//   Result: isSuccess, isFailure, data, statusCode

import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart' show MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/api_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../models/library_models.dart';
import '../library/reader_screen.dart';

// ------------------------------------------------------------------ config
const int _maxBytes = 10 * 1024 * 1024; // 10 MB

// Pricing: 1 MB = 1 token, rounded up (so 0.3 MB and 1.0 MB cost 1, 1.2 MB costs 2).
const int _tokensPerMb = 1;
int _estimateTokens(PlatformFile f) =>
    math.max(1, (f.size / (1024 * 1024) * _tokensPerMb).ceil());

String _fmtSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

// Persists the task key so the waiting UI survives leaving the screen / restarts.
class _TaskStore {
  static const _key = 'active_task_id';
  static Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);
  static Future<void> save(String v) async =>
      (await SharedPreferences.getInstance()).setString(_key, v);
  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

// ======================================================================
// UPLOAD SCREEN
// ======================================================================
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  PlatformFile? _file;
  String? _taskKey;
  bool _restoring = true;
  bool _showReq = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final key = await _TaskStore.read();
    if (!mounted) return;
    setState(() {
      _taskKey = key;
      _restoring = false;
    });
  }

  Future<void> _clearTask() async {
    await _TaskStore.clear();
    if (!mounted) return;
    setState(() {
      _taskKey = null;
      _file = null;
    });
  }

  // ------------------------------------------------------------- pick file
  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: kIsWeb, // bytes are only needed on web
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final f = result.files.first;

    if (!f.name.toLowerCase().endsWith('.pdf')) {
      await ApiHelper.showMessageDialog(context,
          title: 'Unsupported file',
          message: 'Only PDF files are allowed.',
          isError: true);
      return;
    }

    if (f.size > _maxBytes) {
      await ApiHelper.showMessageDialog(context,
          title: 'File too large',
          message:
              '"${f.name}" is ${_fmtSize(f.size)}. The maximum allowed size is 10 MB.',
          isError: true);
      return;
    }

    setState(() => _file = f);
    await _review();
  }

  // ----------------------------------------------------- approve / decline
  Future<void> _review() async {
    final f = _file;
    if (f == null || _sending) return;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 36),
        title: const Text('PDF uploaded'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_fmtSize(f.size),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            Text(
              'It will cost ${_estimateTokens(f)} tokens to generate the videos.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (approved == true) {
      await _send(f);
    } else {
      setState(() => _file = null); // decline removes the pdf
    }
  }

  // ------------------------------------------------------------------ send
  Future<void> _send(PlatformFile f) async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final MultipartFile part;
      if (!kIsWeb && f.path != null) {
        part = await MultipartFile.fromFile(f.path!, filename: f.name);
      } else if (f.bytes != null) {
        part = MultipartFile.fromBytes(f.bytes!, filename: f.name);
      } else {
        if (!mounted) return;
        await ApiHelper.showMessageDialog(context,
            title: 'Error',
            message: 'Could not read the selected file.',
            isError: true);
        return;
      }

      if (!mounted) return;

      final res = await ApiHelper.upload<String>(
        '/project/upload_pdf',
        fields: {'file': part}, // change 'file' if your backend expects another name
        context: context,
        parser: (j) => _extractTaskKey(j) ?? '',
      );

      if (!mounted) return;
      if (res.isFailure) return; // helper showed the error; file kept for retry

      final key = res.data ?? '';
      if (key.isEmpty) {
        await ApiHelper.showMessageDialog(context,
            title: 'Error',
            message:
                'The server accepted the file but did not return a task key.',
            isError: true);
        return;
      }

      await _TaskStore.save(key);
      if (!mounted) return;
      setState(() {
        _taskKey = key;
        _file = null;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String? _extractTaskKey(dynamic j) {
    if (j is Map) {
      final v = j['task_id'] ??
          j['taskKey'] ??
          (j['data'] is Map ? (j['data'] as Map)['task_id'] : null);
      return v?.toString();
    }
    return null;
  }

  // ------------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    if (_restoring) return const Center(child: CircularProgressIndicator());

    if (_taskKey != null) {
      return _TaskProgress(taskKey: _taskKey!, onReset: _clearTask);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      children: [
        const Text('Upload a document',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('Securely add a file for processing.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.file_upload_outlined,
                    size: 30, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              const Text('Choose a PDF',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('from your device',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              const Text('PDF ONLY · UP TO 10MB',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              if (_file != null) ...[
                const SizedBox(height: 20),
                _selectedFileRow(_file!),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _sending ? null : (_file == null ? _pick : _review),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                        )
                      : Text(_file == null ? 'Select file' : 'Review & generate'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _requirements(),
      ],
    );
  }

  Widget _selectedFileRow(PlatformFile f) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                  Text(_fmtSize(f.size),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _sending ? null : () => setState(() => _file = null),
          ),
        ],
      ),
    );
  }

  Widget _requirements() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: AppColors.surface,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _showReq = !_showReq),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.textPrimary),
                    const SizedBox(width: 14),
                    const Text('Requirements', style: TextStyle(fontSize: 16)),
                    const Spacer(),
                    Icon(
                      _showReq ? Icons.expand_less : Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_showReq)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  children: [
                    _reqRow('PDF files only'),
                    _reqRow('Maximum file size: 10 MB'),
                    _reqRow('One file at a time'),
                    _reqRow(
                        'You will see the token cost and approve it before anything is generated'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reqRow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check, size: 15, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

// ======================================================================
// WAITING / PROGRESS UI  (polls /project/task/{task_id})
// ======================================================================
class _TaskStatus {
  _TaskStatus(this.raw);
  final Map<String, dynamic> raw;

  String get status => '${raw['status'] ?? 'pending'}'.toLowerCase();

  double get percent =>
      ((raw['percent'] as num?) ?? 0).toDouble().clamp(0.0, 100.0).toDouble();

  Map<String, dynamic> get current => raw['current'] is Map
      ? Map<String, dynamic>.from(raw['current'] as Map)
      : <String, dynamic>{};

  bool get isDone =>
      const {'completed', 'complete', 'done', 'success', 'finished'}
          .contains(status);
  bool get isFailed => const {'failed', 'error', 'cancelled'}.contains(status);
  bool get isTerminal => isDone || isFailed;

  String get projectName => '${raw['project_name'] ?? ''}';

  int? get projectId {
    final v = raw['project_id'];
    if (v == null) return null;
    return v is int ? v : int.tryParse('$v');
  }

  String get errorText {
    final e = raw['error'] ?? current['msg'];
    return (e == null || '$e'.isEmpty)
        ? 'The task failed. Please try again.'
        : '$e';
  }

  List<String> get recentEvents {
    final ev = raw['events'];
    if (ev is! List) return const [];
    return ev.reversed
        .take(6)
        .map((e) {
          if (e is Map) {
            return '${e['msg'] ?? e['message'] ?? e['step'] ?? e['stage'] ?? ''}';
          }
          return '$e';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static _TaskStatus fromJson(dynamic j) {
    var m = j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
    if (m['status'] == null && m['data'] is Map) {
      m = Map<String, dynamic>.from(m['data'] as Map);
    }
    return _TaskStatus(m);
  }
}

String _pretty(String? s) {
  if (s == null || s.isEmpty) return '';
  final t = s.replaceAll('_', ' ');
  return t[0].toUpperCase() + t.substring(1);
}

class _TaskProgress extends StatefulWidget {
  const _TaskProgress({required this.taskKey, required this.onReset});

  final String taskKey;
  final Future<void> Function() onReset;

  @override
  State<_TaskProgress> createState() => _TaskProgressState();
}

class _TaskProgressState extends State<_TaskProgress> {
  Timer? _timer;
  _TaskStatus? _task;
  bool _inFlight = false;
  bool _notFound = false;
  int _fails = 0;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_inFlight) return;
    _inFlight = true;

    try {
      final res = await ApiHelper.get<_TaskStatus>(
        '/project/task/${widget.taskKey}',
        showError: false, // errors are rendered inline here
        parser: _TaskStatus.fromJson,
      );

      if (!mounted) return;

      if (res.isSuccess) {
        final t = res.data!;
        setState(() {
          _task = t;
          _fails = 0;
        });
        if (t.isTerminal) _timer?.cancel();
      } else if (res.statusCode == 404) {
        _timer?.cancel();
        setState(() => _notFound = true);
      } else {
        setState(() => _fails++);
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _openProject() async {
    final t = _task;
    final id = t?.projectId;
    if (t == null || id == null) return;

    // Grab the navigator BEFORE resetting: onReset removes this widget from
    // the tree, so `mounted` would be false afterwards.
    final nav = Navigator.of(context);
    final project = Project(
      id: id,
      title: t.projectName.isEmpty ? 'Project' : t.projectName,
    );

    await widget.onReset();
    nav.push(MaterialPageRoute(builder: (_) => ReaderScreen(project: project)));
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;

    if (_notFound) {
      return _centerMessage(
        icon: Icons.search_off,
        text: 'This task could not be found. It may have expired.',
        buttonLabel: 'Start over',
        onPressed: widget.onReset,
      );
    }

    final done = t?.isDone ?? false;
    final failed = t?.isFailed ?? false;

    final title = done
        ? 'Your videos are ready'
        : failed
            ? 'Something went wrong'
            : 'Generating your videos';

    final subtitle = done
        ? 'Open the project to start reading.'
        : failed
            ? 'You can try uploading again.'
            : 'This can take a few minutes. You can leave this screen — progress is saved.';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 20),
        _card(t, done, failed),
        if (t != null && t.recentEvents.isNotEmpty) ...[
          const SizedBox(height: 12),
          _activityLog(t),
        ],
        const SizedBox(height: 20),
        _actions(done, failed),
      ],
    );
  }

  Widget _card(_TaskStatus? t, bool done, bool failed) {
    final pct = done ? 100.0 : (t?.percent ?? 0);
    final cur = t?.current ?? const <String, dynamic>{};
    final stage = _pretty(cur['stage']?.toString());
    final step = _pretty(cur['step']?.toString());
    final chunk = cur['chunk'];
    final total = cur['total_chunks'];
    final msg = '${cur['msg'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  failed
                      ? 'Failed'
                      : done
                          ? 'Completed'
                          : (stage.isEmpty
                              ? _pretty(t?.status ?? 'pending')
                              : stage),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text('${pct.round()}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: failed ? Colors.redAccent : AppColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              color: failed ? Colors.redAccent : AppColors.accent,
              backgroundColor: AppColors.surfaceLight,
            ),
          ),
          const SizedBox(height: 14),
          if (failed)
            _line(t!.errorText)
          else ...[
            if (step.isNotEmpty) _line('Step: $step'),
            if (chunk != null && total != null) _line('Part $chunk of $total'),
            if (msg.isNotEmpty) _line(msg),
            if (t != null && t.projectName.isNotEmpty)
              _line('Project: ${t.projectName}'),
            if (t == null) _line('Waiting for the server…'),
          ],
          if (_fails >= 3 && !(t?.isTerminal ?? false)) ...[
            const SizedBox(height: 6),
            const Text('Connection issue — retrying…',
                style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
          ],
        ],
      ),
    );
  }

  Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );

  Widget _activityLog(_TaskStatus t) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text('Activity',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        children: [
          for (final e in t.recentEvents)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(bool done, bool failed) {
    if (done) {
      return Column(
        children: [
          if (_task?.projectId != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _openProject,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Open project'),
              ),
            ),
          TextButton(
            onPressed: widget.onReset,
            child: const Text('Upload another'),
          ),
        ],
      );
    }

    if (failed) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: widget.onReset,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Try again'),
        ),
      );
    }

    // Running: stop tracking (does not cancel the task on the server).
    return Center(
      child: TextButton(
        onPressed: () async {
          final ok = await ApiHelper.confirm(
            context,
            title: 'Stop tracking?',
            message:
                'The task keeps running on the server, but this screen will stop showing its progress.',
            confirmText: 'Stop tracking',
          );
          if (ok) await widget.onReset();
        },
        child: const Text('Stop tracking',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _centerMessage({
    required IconData icon,
    required String text,
    required String buttonLabel,
    required Future<void> Function() onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}