import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_helper.dart';

enum _ChatMode { instant, expert, vision }

enum _Role { user, assistant }

class _Msg {
  _Msg(this.role, this.text, {this.isError = false});
  final _Role role;
  final String text;
  final bool isError;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.asPage = false,
    this.projectId,
    this.chunkId,
    this.contextLabel,
    this.contextText,
  });

  /// true when pushed from the reader (adds a Scaffold + back button).
  /// false when used as a tab body, exactly as before.
  final bool asPage;

  /// Page the user was reading when they tapped "Ask AI".
  final int? projectId;
  final int? chunkId;
  final String? contextLabel;
  final String? contextText;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  _ChatMode _mode = _ChatMode.instant;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _sending = false;

  bool get _hasContext => (widget.contextText ?? '').trim().isNotEmpty;

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
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ send
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_Msg(_Role.user, text));
      _sending = true;
      _controller.clear();
    });
    _scrollToEnd();

    final res = await ApiHelper.post<String>(
      '/project/chat_history',
      body: {
        'project_id': widget.projectId,
        'chunk_id': widget.chunkId,
        'mode': _mode.name,
        'message': text,
        if (_hasContext) 'context': widget.contextText,
      },
      parser: _extractReply,
    );

    if (!mounted) return;

    setState(() {
      _sending = false;
      if (res.isSuccess && (res.data ?? '').isNotEmpty) {
        _messages.add(_Msg(_Role.assistant, res.data!));
      } else {
        _messages.add(_Msg(
          _Role.assistant,
          res.error ?? 'Something went wrong. Please try again.',
          isError: true,
        ));
      }
    });
    _scrollToEnd();
  }

  /// Pulls the assistant text out of whatever the backend returns.
  static String _extractReply(dynamic json) {
    if (json is Map) {
      for (final k in ['reply', 'response', 'answer', 'message', 'content']) {
        final v = json[k];
        if (v is String && v.isNotEmpty) return v;
      }
      final data = json['data'];
      if (data != null) return _extractReply(data);
    }
    return json is String ? json : '';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (_hasContext) _contextBanner(),
        Expanded(
          child: _messages.isEmpty ? _emptyState() : _messageList(),
        ),
        _inputBar(),
        const SizedBox(height: 12),
      ],
    );

    if (!widget.asPage) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Ask AI')),
      body: SafeArea(child: body),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        SizedBox(height: widget.asPage ? 60 : 120),
        Center(
          child: Text(
            '✨ Start chatting with ${_titles[_mode]}',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
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
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length + 1 + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _modeSelector(),
          );
        }
        final msgIndex = i - 1;
        if (msgIndex >= _messages.length) return _typingBubble();
        return _bubble(_messages[msgIndex]);
      },
    );
  }

  Widget _bubble(_Msg m) {
    final isUser = m.role == _Role.user;
    final bg = m.isError
        ? Colors.redAccent.withOpacity(0.15)
        : isUser
            ? AppColors.accentDim
            : AppColors.surface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: SelectableText(m.text, style: const TextStyle(height: 1.4)),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _contextBanner() {
    final label = widget.contextLabel ?? 'this page';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Asking about $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- mode selector
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

  // -------------------------------------------------------------- input bar
  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Type a message or hold to speak',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, __) {
                final canSend = value.text.trim().isNotEmpty && !_sending;
                return IconButton.filled(
                  onPressed: canSend ? _send : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppColors.accentDim,
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
