import 'package:another_iptv_player/models/content_type.dart';

/// Represents parental control settings
class ParentalControlSettings {
  final bool enabled;
  final String? pin;
  final List<String> blockedKeywords;
  final List<String> blockedCategoryIds;
  final List<ParentalBlockedItem> blockedItems;
  final DateTime? lastUnlockTime;
  final int lockTimeoutMinutes;

  const ParentalControlSettings({
    this.enabled = false,
    this.pin,
    this.blockedKeywords = const [],
    this.blockedCategoryIds = const [],
    this.blockedItems = const [],
    this.lastUnlockTime,
    this.lockTimeoutMinutes = 30,
  });

  bool get isUnlocked {
    if (!enabled) return true;
    if (lastUnlockTime == null) return false;
    final elapsed = DateTime.now().difference(lastUnlockTime!);
    return elapsed.inMinutes < lockTimeoutMinutes;
  }

  ParentalControlSettings copyWith({
    bool? enabled,
    String? pin,
    List<String>? blockedKeywords,
    List<String>? blockedCategoryIds,
    List<ParentalBlockedItem>? blockedItems,
    DateTime? lastUnlockTime,
    int? lockTimeoutMinutes,
  }) {
    return ParentalControlSettings(
      enabled: enabled ?? this.enabled,
      pin: pin ?? this.pin,
      blockedKeywords: blockedKeywords ?? this.blockedKeywords,
      blockedCategoryIds: blockedCategoryIds ?? this.blockedCategoryIds,
      blockedItems: blockedItems ?? this.blockedItems,
      lastUnlockTime: lastUnlockTime ?? this.lastUnlockTime,
      lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'pin': pin,
      'blockedKeywords': blockedKeywords,
      'blockedCategoryIds': blockedCategoryIds,
      'blockedItems': blockedItems.map((e) => e.toJson()).toList(),
      'lastUnlockTime': lastUnlockTime?.toIso8601String(),
      'lockTimeoutMinutes': lockTimeoutMinutes,
    };
  }

  factory ParentalControlSettings.fromJson(Map<String, dynamic> json) {
    return ParentalControlSettings(
      enabled: json['enabled'] ?? false,
      pin: json['pin'],
      blockedKeywords: List<String>.from(json['blockedKeywords'] ?? []),
      blockedCategoryIds: List<String>.from(json['blockedCategoryIds'] ?? []),
      blockedItems: (json['blockedItems'] as List<dynamic>?)
              ?.map((e) => ParentalBlockedItem.fromJson(e))
              .toList() ??
          [],
      lastUnlockTime: json['lastUnlockTime'] != null
          ? DateTime.parse(json['lastUnlockTime'])
          : null,
      lockTimeoutMinutes: json['lockTimeoutMinutes'] ?? 30,
    );
  }
}

/// Represents a manually blocked item
class ParentalBlockedItem {
  final String id;
  final String name;
  final ContentType contentType;
  final String? categoryId;
  final String? imagePath;

  const ParentalBlockedItem({
    required this.id,
    required this.name,
    required this.contentType,
    this.categoryId,
    this.imagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contentType': contentType.name,
      'categoryId': categoryId,
      'imagePath': imagePath,
    };
  }

  factory ParentalBlockedItem.fromJson(Map<String, dynamic> json) {
    return ParentalBlockedItem(
      id: json['id'],
      name: json['name'],
      contentType: ContentType.values.firstWhere(
        (e) => e.name == json['contentType'],
        orElse: () => ContentType.liveStream,
      ),
      categoryId: json['categoryId'],
      imagePath: json['imagePath'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParentalBlockedItem &&
        other.id == id &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => id.hashCode ^ contentType.hashCode;
}

/// Blocked category info
class ParentalBlockedCategory {
  final String id;
  final String name;
  final ContentType contentType;

  const ParentalBlockedCategory({
    required this.id,
    required this.name,
    required this.contentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contentType': contentType.name,
    };
  }

  factory ParentalBlockedCategory.fromJson(Map<String, dynamic> json) {
    return ParentalBlockedCategory(
      id: json['id'],
      name: json['name'],
      contentType: ContentType.values.firstWhere(
        (e) => e.name == json['contentType'],
        orElse: () => ContentType.liveStream,
      ),
    );
  }
}
