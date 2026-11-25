// lib/screens/reader_screen.dart

import 'package:flutter/material.dart';

import '../../core/utils/api_helper.dart';
import '../../models/library_models.dart';
import '../ai_chat/chat_screen.dart'; // adjust if your chat screen lives elsewhere
import 'listen_to_audio.dart';
import 'play_video.dart';
import 'quiz.dart';

enum _ReaderAction {
  audio('Play audio', Icons.play_circle_outline),
  video('Watch video', Icons.smart_display_outlined),
  quiz('Take quiz', Icons.quiz_outlined),
  podcast('Listen to podcast', Icons.podcasts),
  save('Save', Icons.bookmark_border),
  askAi('Ask AI', Icons.auto_awesome_outlined);

  const _ReaderAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

// Built-in font families only. For more fonts add the `google_fonts` package.
const Map<String, String?> _fonts = {
  'Default': null,
  'Sans': 'sans-serif',
  'Serif': 'serif',
  'Mono': 'monospace',
};

const List<Color> _textColors = [
  Color(0xFF1A1A1A),
  Color(0xFF5B4636),
  Color(0xFF2E3B2F),
  Color(0xFFE0E0E0),
  Color(0xFFFFFFFF),
  Color(0xFFD8C9A8),
];

const List<Color> _bgColors = [
  Color(0xFFFFFFFF),
  Color(0xFFF4ECD8),
  Color(0xFFE6EFE6),
  Color(0xFF1E1E1E),
  Color(0xFF121212),
  Color(0xFF000000),
];

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.project});

  final Project project;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final ScrollController _scrollCtrl = ScrollController();
  PageController _pageCtrl = PageController();

  // data
  List<Chunk> _chunks = [];
  List<GlobalKey> _keys = [];
  bool _loading = true;
  String? _error;
  int _current = 0;

  // text settings
  bool _horizontal = false;
  String _fontName = 'Default';
  double _fontSize = 18;
  double _lineHeight = 1.6;
  Color _textColor = _textColors[0];
  Color _bgColor = _bgColors[0];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {})); // show/hide the FAB per tab
    _scrollCtrl.addListener(_syncCurrentFromScroll);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scrollCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiHelper.get<List<Chunk>>(
      '/library/chunks',
      query: {'project_id': widget.project.id},
      parser: (json) {
        final list = extractList(json)
            .map((e) => Chunk.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        list.sort((a, b) => a.index.compareTo(b.index));
        return list;
      },
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res.isSuccess) {
        _chunks = res.data ?? [];
        _keys = List.generate(_chunks.length, (_) => GlobalKey());
        _current = 0;
      } else {
        _error = res.error;
      }
    });
  }

  // ------------------------------------------- current chunk (vertical mode)
  void _syncCurrentFromScroll() {
    if (_horizontal || _keys.isEmpty || !mounted) return;

    final top = MediaQuery.of(context).padding.top +
        kToolbarHeight +
        kTextTabBarHeight +
        24;

    var found = _current;
    for (var i = 0; i < _keys.length; i++) {
      final box = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy + box.size.height > top) {
        found = i;
        break;
      }
    }
    if (found != _current) setState(() => _current = found);
  }

  void _setHorizontal(bool value) {
    if (value == _horizontal) return;
    setState(() {
      _horizontal = value;
      if (value) {
        _pageCtrl.dispose();
        _pageCtrl = PageController(initialPage: _current);
      }
    });

    if (!value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys.isEmpty ? null : _keys[_current].currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx);
      });
    }
  }

  // ----------------------------------------------------------------- style
  TextStyle get _textStyle => TextStyle(
        fontFamily: _fonts[_fontName],
        fontSize: _fontSize,
        height: _lineHeight,
        color: _textColor,
      );

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Read'), Tab(text: 'Text settings')],
        ),
      ),
      // Swiping between tabs is disabled so it doesn't fight the horizontal PageView.
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: [_readTab(), _settingsTab()],
      ),
      floatingActionButton: (_tabs.index == 0 && _chunks.isNotEmpty)
          ? FloatingActionButton(
              onPressed: _openActions,
              child: const Icon(Icons.apps_rounded),
            )
          : null,
    );
  }

  // -------------------------------------------------------------- read tab
  Widget _readTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_chunks.isEmpty) {
      return const Center(child: Text('No content in this project yet.'));
    }

    return Container(
      color: _bgColor,
      child: Stack(
        children: [
          _horizontal ? _horizontalReader() : _verticalReader(),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _textColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_current + 1} / ${_chunks.length}',
                style: TextStyle(color: _textColor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalReader() {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _chunks.length; i++)
            KeyedSubtree(
              key: _keys[i],
              child: _chunkBlock(_chunks[i]),
            ),
        ],
      ),
    );
  }

  Widget _horizontalReader() {
    return PageView.builder(
      controller: _pageCtrl,
      itemCount: _chunks.length,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (_, i) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: _chunkBlock(_chunks[i]),
      ),
    );
  }

  Widget _chunkBlock(Chunk c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Part ${c.index}',
            style: TextStyle(
              color: _textColor.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(c.text, style: _textStyle),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- settings tab
  Widget _settingsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // live preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Text(
            'The quick brown fox jumps over the lazy dog. '
            'This is how your text will look while reading.',
            style: _textStyle,
          ),
        ),
        const SizedBox(height: 24),

        _label('Quick themes'),
        Wrap(
          spacing: 8,
          children: [
            _preset('Light', const Color(0xFF1A1A1A), const Color(0xFFFFFFFF)),
            _preset('Sepia', const Color(0xFF5B4636), const Color(0xFFF4ECD8)),
            _preset('Dark', const Color(0xFFE0E0E0), const Color(0xFF121212)),
          ],
        ),
        const SizedBox(height: 24),

        _label('Font'),
        Wrap(
          spacing: 8,
          children: _fonts.keys
              .map((name) => ChoiceChip(
                    label: Text(name),
                    selected: _fontName == name,
                    onSelected: (_) => setState(() => _fontName = name),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),

        _label('Font size  ·  ${_fontSize.round()}'),
        Slider(
          min: 12,
          max: 32,
          divisions: 20,
          value: _fontSize,
          onChanged: (v) => setState(() => _fontSize = v),
        ),

        _label('Line spacing  ·  ${_lineHeight.toStringAsFixed(1)}'),
        Slider(
          min: 1.2,
          max: 2.2,
          divisions: 10,
          value: _lineHeight,
          onChanged: (v) => setState(() => _lineHeight = v),
        ),
        const SizedBox(height: 12),

        _label('Text color'),
        _swatches(_textColors, _textColor, (c) => setState(() => _textColor = c)),
        const SizedBox(height: 24),

        _label('Background color'),
        _swatches(_bgColors, _bgColor, (c) => setState(() => _bgColor = c)),
        const SizedBox(height: 24),

        _label('Scroll direction'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: false,
                icon: Icon(Icons.swap_vert),
                label: Text('Vertical')),
            ButtonSegment(
                value: true,
                icon: Icon(Icons.swap_horiz),
                label: Text('Horizontal')),
          ],
          selected: {_horizontal},
          onSelectionChanged: (s) => _setHorizontal(s.first),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );

  Widget _preset(String name, Color text, Color bg) {
    return ActionChip(
      label: Text(name),
      onPressed: () => setState(() {
        _textColor = text;
        _bgColor = bg;
      }),
    );
  }

  Widget _swatches(
      List<Color> colors, Color selected, ValueChanged<Color> onPick) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onPick(c),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withOpacity(0.5),
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check,
                    size: 18,
                    color: c.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }

  // --------------------------------------------------------- floating menu
  Future<void> _openActions() async {
    final action = await showModalBottomSheet<_ReaderAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            physics: const NeverScrollableScrollPhysics(),
            children: _ReaderAction.values
                .map((a) => InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(ctx).pop(a),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(a.icon, size: 28),
                          const SizedBox(height: 8),
                          Text(a.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );

    if (action != null && mounted) _handleAction(action);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _handleAction(_ReaderAction action) {
    final chunk = _chunks[_current];

    switch (action) {
      case _ReaderAction.audio:
        final url = chunk.audioUrl;
        if (url == null) return _toast('No audio for this part yet.');
        _push(ListenToAudioScreen(
          mode: AudioMode.audio,
          title: widget.project.title,
          coverUrl: widget.project.coverUrl,
          tracks: [AudioTrack(title: 'Part ${chunk.index}', url: url)],
        ));

      case _ReaderAction.video:
        final url = chunk.videoFullUrl ?? widget.project.videoUrl;
        if (url == null) return _toast('No video available.');
        _push(PlayVideoScreen(
          title: widget.project.title,
          url: url,
        ));

      case _ReaderAction.quiz:
        if (chunk.quiz.isEmpty) return _toast('No quiz for this part yet.');
        _push(QuizScreen(
          title: 'Part ${chunk.index} quiz',
          questions: chunk.quiz,
        ));

      case _ReaderAction.podcast:
        // The podcast is every part's audio played back to back.
        final withAudio = _chunks.where((c) => c.audioUrl != null).toList();
        if (withAudio.isEmpty) return _toast('No audio available yet.');
        final start = withAudio.indexWhere((c) => c.index == chunk.index);
        _push(ListenToAudioScreen(
          mode: AudioMode.podcast,
          title: widget.project.title,
          coverUrl: widget.project.coverUrl,
          initialIndex: start < 0 ? 0 : start,
          tracks: [
            for (final c in withAudio)
              AudioTrack(title: 'Part ${c.index}', url: c.audioUrl!),
          ],
        ));

      case _ReaderAction.save:
        _savePage(chunk);

      case _ReaderAction.askAi:
        _push(ChatScreen(
          asPage: true,
          projectId: widget.project.id,
          chunkId: chunk.id,
          contextLabel: 'Part ${chunk.index}',
          contextText: chunk.text,
        ));
    }
  }

  // Sends the page the user is on to the backend.
  Future<void> _savePage(Chunk chunk) async {
    await ApiHelper.post(
      '/project/saved',
      body: {
        'project_id': widget.project.id,
        'chunk_id': chunk.id,
        'chunk_index': chunk.index,
        'text': chunk.text,
      },
      context: context,
      successMessage: 'Page saved',
    );
  }
}