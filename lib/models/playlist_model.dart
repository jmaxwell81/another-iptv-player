import 'package:another_iptv_player/utils/type_convertions.dart';

class Playlist {
  final String id;
  final String name;
  final PlaylistType type;
  final String? url; // Primary URL (for backward compatibility)
  final List<String> additionalUrls; // Additional backup URLs
  final String? username;
  final String? password;
  final DateTime createdAt;
  final int? activeUrlIndex; // Index of currently active URL (0 = primary)

  Playlist({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.additionalUrls = const [],
    this.username,
    this.password,
    required this.createdAt,
    this.activeUrlIndex,
  });

  /// Get all URLs (primary + additional) in order
  List<String> get allUrls {
    final urls = <String>[];
    if (url != null && url!.isNotEmpty) {
      urls.add(url!);
    }
    urls.addAll(additionalUrls.where((u) => u.isNotEmpty));
    return urls;
  }

  /// Get the currently active URL
  String? get activeUrl {
    final urls = allUrls;
    if (urls.isEmpty) return null;
    final index = activeUrlIndex ?? 0;
    if (index >= 0 && index < urls.length) {
      return urls[index];
    }
    return urls.first;
  }

  /// Whether this playlist has multiple URLs configured
  bool get hasMultipleUrls => allUrls.length > 1;

  /// Get URL count
  int get urlCount => allUrls.length;

  Playlist copyWith({
    String? id,
    String? name,
    PlaylistType? type,
    String? url,
    List<String>? additionalUrls,
    String? username,
    String? password,
    DateTime? createdAt,
    int? activeUrlIndex,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      additionalUrls: additionalUrls ?? this.additionalUrls,
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      activeUrlIndex: activeUrlIndex ?? this.activeUrlIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'url': url,
      'additionalUrls': additionalUrls,
      'username': username,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'activeUrlIndex': activeUrlIndex,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: safeString(json['id']),
      name: safeString(json['name']),
      type: PlaylistType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PlaylistType.m3u,
      ),
      url: safeString(json['url']),
      additionalUrls: json['additionalUrls'] != null
          ? List<String>.from(json['additionalUrls'])
          : const [],
      username: safeString(json['username']),
      password: safeString(json['password']),
      createdAt:
          DateTime.tryParse(safeString(json['createdAt'])) ?? DateTime.now(),
      activeUrlIndex: json['activeUrlIndex'] as int?,
    );
  }
}

enum PlaylistType { xtream, m3u }
