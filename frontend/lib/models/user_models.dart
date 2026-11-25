// lib/models/user_models.dart

Map<String, dynamic> _unwrap(dynamic json, String key) {
  final m = Map<String, dynamic>.from(json as Map);
  final inner = m[key];
  return inner is Map ? Map<String, dynamic>.from(inner) : m;
}

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// "VOICE_1" / "voice_1" -> "Voice 1"
String prettify(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.isEmpty) return '-';
  return s
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
      .join(' ');
}

String formatDate(DateTime? d) {
  if (d == null) return '-';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

class UserProfile {
  final int id;
  final String email;
  final String? username;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.username,
    this.createdAt,
  });

  String get displayName =>
      (username != null && username!.isNotEmpty) ? username! : email.split('@').first;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'[\s._-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory UserProfile.fromJson(dynamic json) {
    final m = _unwrap(json, 'user');
    return UserProfile(
      id: (m['id'] as num?)?.toInt() ?? 0,
      email: m['email'] as String? ?? '',
      username: m['username'] as String?,
      createdAt: _date(m['created_at']),
    );
  }
}

class UserSettings {
  final String voice;
  final String bgSound;
  final String bgColor; // hex
  final String captionFont;
  final String captionColor;
  final int captionSize;
  final String videoTemplate;

  const UserSettings({
    required this.voice,
    required this.bgSound,
    required this.bgColor,
    required this.captionFont,
    required this.captionColor,
    required this.captionSize,
    required this.videoTemplate,
  });

  factory UserSettings.fromJson(dynamic json) {
    final m = _unwrap(json, 'settings');
    return UserSettings(
      voice: prettify(m['voice']),
      bgSound: prettify(m['bg_sound']),
      bgColor: m['bg_color'] as String? ?? '#000000',
      captionFont: prettify(m['caption_font']),
      captionColor: prettify(m['caption_color']),
      captionSize: (m['caption_size'] as num?)?.toInt() ?? 16,
      videoTemplate: prettify(m['video_template']),
    );
  }
}

class UserBilling {
  final int tokenBalance;
  final bool autoBilling;
  final DateTime? updatedAt;

  const UserBilling({
    required this.tokenBalance,
    required this.autoBilling,
    this.updatedAt,
  });

  factory UserBilling.fromJson(dynamic json) {
    final m = _unwrap(json, 'billing');
    return UserBilling(
      tokenBalance: (m['token_balance'] as num?)?.toInt() ?? 0,
      autoBilling: m['auto_billing_enabled'] as bool? ?? false,
      updatedAt: _date(m['updated_at']),
    );
  }
}

class UserActivity {
  final int id;
  final String action;
  final String status; // raw, lower-cased
  final DateTime? createdAt;

  const UserActivity({
    required this.id,
    required this.action,
    required this.status,
    this.createdAt,
  });

  factory UserActivity.fromJson(Map<String, dynamic> m) => UserActivity(
        id: (m['id'] as num?)?.toInt() ?? 0,
        action: m['action'] as String? ?? '',
        status: (m['status']?.toString() ?? 'completed').toLowerCase(),
        createdAt: _date(m['created_at']),
      );

  /// Accepts a bare list, or {"activities": [...]} / {"data": [...]} / {"items": [...]}.
  static List<UserActivity> listFromJson(dynamic json) {
    dynamic list = json;
    if (json is Map) {
      list = json['activities'] ?? json['data'] ?? json['items'] ?? [];
    }
    return (list as List)
        .map((e) => UserActivity.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
