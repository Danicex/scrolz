// lib/screens/library/play_video.dart
//
// pubspec.yaml:  video_player: ^2.9.0   (or newer)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';

class PlayVideoScreen extends StatefulWidget {
  const PlayVideoScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<PlayVideoScreen> createState() => _PlayVideoScreenState();
}

class _PlayVideoScreenState extends State<PlayVideoScreen> {
  late final VideoPlayerController _ctrl;

  bool _ready = false;
  bool _failed = false;
  bool _showControls = true;
  bool _landscape = false;
  double _speed = 1.0;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _ready = false;
      _failed = false;
    });
    try {
      await _ctrl.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      _ctrl.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _toggleLandscape() async {
    _landscape = !_landscape;
    await SystemChrome.setPreferredOrientations(_landscape
        ? [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : [DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(
        _landscape ? SystemUiMode.immersive : SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
  }

  void _seekBy(int seconds) {
    final v = _ctrl.value;
    var target = v.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    _ctrl.seekTo(target);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _landscape
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(widget.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
      body: SafeArea(
        child: Center(
          child: _failed
              ? _errorView()
              : !_ready
                  ? const CircularProgressIndicator()
                  : _videoView(),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined,
              size: 48, color: Colors.white70),
          const SizedBox(height: 12),
          const Text('Could not load the video.',
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _init, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _videoView() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showControls = !_showControls),
      child: AspectRatio(
        aspectRatio: _ctrl.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_ctrl),
            // Dim + controls
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  color: Colors.black38,
                  child: Stack(
                    children: [
                      Center(child: _centerControls()),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _bottomBar(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerControls() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _ctrl,
      builder: (_, v, __) {
        final ended = v.duration > Duration.zero && v.position >= v.duration;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 36,
              color: Colors.white,
              onPressed: () => _seekBy(-10),
              icon: const Icon(Icons.replay_10),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
              child: IconButton(
                iconSize: 44,
                color: Colors.black,
                onPressed: () {
                  if (ended) {
                    _ctrl.seekTo(Duration.zero);
                    _ctrl.play();
                  } else {
                    v.isPlaying ? _ctrl.pause() : _ctrl.play();
                  }
                },
                icon: Icon(ended
                    ? Icons.replay_rounded
                    : v.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              iconSize: 36,
              color: Colors.white,
              onPressed: () => _seekBy(10),
              icon: const Icon(Icons.forward_10),
            ),
          ],
        );
      },
    );
  }

  Widget _bottomBar() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _ctrl,
      builder: (_, v, __) {
        final maxMs = v.duration.inMilliseconds.toDouble();
        final posMs = v.position.inMilliseconds
            .toDouble()
            .clamp(0.0, maxMs > 0 ? maxMs : 1.0)
            .toDouble();

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              Text(_fmt(v.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: Slider(
                  min: 0,
                  max: maxMs > 0 ? maxMs : 1.0,
                  value: posMs,
                  onChanged: maxMs > 0
                      ? (x) => _ctrl.seekTo(Duration(milliseconds: x.round()))
                      : null,
                ),
              ),
              Text(_fmt(v.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              PopupMenuButton<double>(
                tooltip: 'Playback speed',
                initialValue: _speed,
                onSelected: (s) {
                  setState(() => _speed = s);
                  _ctrl.setPlaybackSpeed(s);
                },
                itemBuilder: (_) => [
                  for (final s in _speeds)
                    PopupMenuItem(value: s, child: Text('${s}x')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${_speed}x',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
              IconButton(
                color: Colors.white,
                onPressed: _toggleLandscape,
                icon: Icon(_landscape
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen),
              ),
            ],
          ),
        );
      },
    );
  }
}
