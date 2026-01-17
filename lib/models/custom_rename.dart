import 'dart:convert';

/// Represents a custom rename for a specific item (category, live stream, movie, series)
class CustomRename {
  final String id; // Composite key: "{type}:{playlistId}:{itemId}"
  final String originalName;
  final String customName;
  final CustomRenameType type;
  final String itemId;
  final String? playlistId;
  final DateTime createdAt;

  CustomRename({
    required this.id,
    required this.originalName,
    required this.customName,
    required this.type,
    required this.itemId,
    this.playlistId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Generate a composite ID for lookups
  static String generateId(CustomRenameType type, String itemId, String? playlistId) {
    final prefix = type.name;
    if (playlistId != null && playlistId.isNotEmpty) {
      return '$prefix:$playlistId:$itemId';
    }
    return '$prefix:$itemId';
  }

  CustomRename copyWith({
    String? id,
    String? originalName,
    String? customName,
    CustomRenameType? type,
    String? itemId,
    String? playlistId,
    DateTime? createdAt,
  }) {
    return CustomRename(
      id: id ?? this.id,
      originalName: originalName ?? this.originalName,
      customName: customName ?? this.customName,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      playlistId: playlistId ?? this.playlistId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalName': originalName,
      'customName': customName,
      'type': type.name,
      'itemId': itemId,
      'playlistId': playlistId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomRename.fromJson(Map<String, dynamic> json) {
    return CustomRename(
      id: json['id'] as String,
      originalName: json['originalName'] as String,
      customName: json['customName'] as String,
      type: CustomRenameType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CustomRenameType.liveStream,
      ),
      itemId: json['itemId'] as String,
      playlistId: json['playlistId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  static List<CustomRename> listFromJson(String jsonString) {
    if (jsonString.isEmpty) return [];
    final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => CustomRename.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<CustomRename> renames) {
    return jsonEncode(renames.map((r) => r.toJson()).toList());
  }
}

enum CustomRenameType {
  category,
  liveStream,
  vod,
  series;

  String get displayName {
    switch (this) {
      case CustomRenameType.category:
        return 'Category';
      case CustomRenameType.liveStream:
        return 'Live Stream';
      case CustomRenameType.vod:
        return 'Movie';
      case CustomRenameType.series:
        return 'Series';
    }
  }
}
