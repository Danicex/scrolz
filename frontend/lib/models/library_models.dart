import '../core/utils/api_helper.dart';

String? _absolute(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '${ApiHelper.mediaBaseUrl}/${path.startsWith('/') ? path.substring(1) : path}';
}

List<dynamic> extractList(dynamic json,
    [List<String> keys = const ['data', 'items', 'results', 'projects', 'chunks']]) {
  if (json is List) return json;
  if (json is Map) {
    for (final k in keys) {
      final v = json[k];
      if (v is List) return v;
    }
  }
  return const [];
}


class Project {
  const Project({
    required this.id,
    required this.title,
    this.cover,
    this.videoPath,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? cover;
  final String? videoPath;
  final DateTime? createdAt;

  String? get coverUrl => _absolute(cover);
  String? get videoUrl => _absolute(videoPath);

  String get dateLabel {
    final d = createdAt;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as int,
        title: (j['title'] ?? 'Untitled').toString(),
        cover: j['cover'] as String?,
        videoPath: j['video_path'] as String?,
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
      );
}

class Chunk {
  const Chunk({
    required this.id,
    required this.projectId,
    required this.index,
    required this.key,
    required this.text,
    this.summarizedText,
    this.audio,
    this.quiz = const [],
    this.videoUrl,
  });

  final int id;
  final int projectId;
  final int index; // 1-based
  final String key; // "chunk_1"
  final String text;
  final String? summarizedText;
  final String? audio;
  final List<Map<String, dynamic>> quiz;
  final String? videoUrl;

  String? get audioUrl => _absolute(audio);
  String? get videoFullUrl => _absolute(videoUrl);

  factory Chunk.fromJson(Map<String, dynamic> j) => Chunk(
        id: j['id'] as int,
        projectId: j['project_id'] as int,
        index: j['index'] as int,
        key: (j['key'] ?? 'chunk_${j['index']}').toString(),
        text: (j['text'] ?? '').toString(),
        summarizedText: j['summarized_text'] as String?,
        audio: j['audio'] as String?,
        quiz: ((j['quiz'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        videoUrl: j['video_url'] as String?,
      );
}