// lib/screens/library/listen_to_audio.dart
//
// One screen for both "Play audio" (a single part) and "Listen to podcast"
// (every part of the project as a playlist of episodes).
//
// pubspec.yaml:  just_audio: ^0.9.40   (or newer)

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_theme.dart';

enum AudioMode { audio, podcast }

class AudioTrack {
  const AudioTrack({required this.title, required this.url, this.subtitle});

  final String title;
  final String url;
  final String? subtitle;
}

class ListenToAudioScreen extends StatefulWidget {
  const ListenToAudioScreen({
    super.key,
    required this.mode,
    required this.title,
    required this.tracks,
    this.initialIndex = 0,
    this.coverUrl,
  }) : assert(tracks.length > 0);

  final AudioMode mode;

  /// Project title (shown as the podcast / audio name).
  final String title;
  final List<AudioTrack> tracks;
  final int initialIndex;
  final String? coverUrl;

  @override
  State<ListenToAudioScreen> createState() => _ListenToAudioScreenState();
}

class _ListenToAudioScreenState extends State<ListenToAudioScreen> {
  final AudioPlayer _player = AudioPlayer();

  bool _loading = true;
  String? _error;
  double _speed = 1.0;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  bool get _isPodcast => widget.mode == AudioMode.podcast;
  int get _skip => _isPodcast ? 30 : 15; // seconds

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(
          children: [
            for (final t in widget.tracks) AudioSource.uri(Uri.parse(t.url)),
          ],
        ),
        initialIndex: widget.initialIndex.clamp(0, widget.tracks.length - 1),
        initialPosition: Duration.zero,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _player.play(); // don't await: completes only when playback stops
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the audio.';
      });
    }
  }

  void _seekBy(int seconds) {
    final dur = _player.duration ?? Duration.zero;
    var target = _player.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    _player.seek(target);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPodcast ? 'Podcast' : 'Audio'),
        actions: [
          PopupMenuButton<double>(
            tooltip: 'Playback speed',
            initialValue: _speed,
            onSelected: (v) {
              setState(() => _speed = v);
              _player.setSpeed(v);
            },
            itemBuilder: (_) => [
              for (final s in _speeds)
                PopupMenuItem(value: s, child: Text('${s}x')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text('${_speed}x',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
      body: _error != null
          ? _errorView()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _playerView(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _init, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _playerView() {
    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      builder: (context, snap) {
        final index = (snap.data ?? widget.initialIndex)
            .clamp(0, widget.tracks.length - 1);
        final track = widget.tracks[index];

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  _cover(),
                  const SizedBox(height: 24),
                  Text(
                    track.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.subtitle ?? widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  _progress(),
                  const SizedBox(height: 8),
                  _controls(index),
                  if (_isPodcast && widget.tracks.length > 1) ...[
                    const SizedBox(height: 28),
                    const Text('Episodes',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    _queue(index),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------------- cover
  Widget _cover() {
    final fallback = Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Icon(
        _isPodcast ? Icons.podcasts : Icons.graphic_eq,
        size: 72,
        color: AppColors.accent,
      ),
    );

    final url = widget.coverUrl;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: url == null
                ? fallback
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- progress
  Widget _progress() {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: _player.durationStream,
          builder: (context, durSnap) {
            final duration = durSnap.data ?? Duration.zero;
            final maxMs = duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds
                .toDouble()
                .clamp(0.0, maxMs > 0 ? maxMs : 1.0)
                .toDouble();

            return Column(
              children: [
                Slider(
                  min: 0,
                  max: maxMs > 0 ? maxMs : 1.0,
                  value: value,
                  onChanged: maxMs > 0
                      ? (v) => _player.seek(Duration(milliseconds: v.round()))
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text(_fmt(duration),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------- controls
  Widget _controls(int index) {
    final hasPrev = index > 0;
    final hasNext = index < widget.tracks.length - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.tracks.length > 1)
          IconButton(
            iconSize: 34,
            onPressed: hasPrev ? _player.seekToPrevious : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
        IconButton(
          iconSize: 34,
          tooltip: 'Back $_skip seconds',
          onPressed: () => _seekBy(-_skip),
          icon: Icon(_skip == 30 ? Icons.replay_30 : Icons.replay_10),
        ),
        const SizedBox(width: 4),
        _playPause(),
        const SizedBox(width: 4),
        IconButton(
          iconSize: 34,
          tooltip: 'Forward $_skip seconds',
          onPressed: () => _seekBy(_skip),
          icon: Icon(_skip == 30 ? Icons.forward_30 : Icons.forward_10),
        ),
        if (widget.tracks.length > 1)
          IconButton(
            iconSize: 34,
            onPressed: hasNext ? _player.seekToNext : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
      ],
    );
  }

  Widget _playPause() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final state = snap.data;
        final playing = state?.playing ?? false;
        final processing = state?.processingState;
        final busy = processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;
        final completed = processing == ProcessingState.completed;

        return Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.black),
                )
              : IconButton(
                  iconSize: 38,
                  color: Colors.black,
                  onPressed: () {
                    if (completed) {
                      _player.seek(Duration.zero, index: 0);
                      _player.play();
                    } else if (playing) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                  icon: Icon(
                    completed
                        ? Icons.replay_rounded
                        : playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                  ),
                ),
        );
      },
    );
  }

  // ----------------------------------------------------------------- queue
  Widget _queue(int current) {
    return Column(
      children: [
        for (var i = 0; i < widget.tracks.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _player.seek(Duration.zero, index: i);
              _player.play();
            },
            leading: CircleAvatar(
              backgroundColor:
                  i == current ? AppColors.accentDim : AppColors.surface,
              child: i == current
                  ? const Icon(Icons.equalizer, color: AppColors.accent)
                  : Text('${i + 1}',
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
            ),
            title: Text(
              widget.tracks[i].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                color: i == current ? AppColors.accent : null,
              ),
            ),
          ),
      ],
    );
  }
}
