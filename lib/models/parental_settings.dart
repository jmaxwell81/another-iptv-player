import 'dart:convert';

class ParentalSettings {
  final String pin;
  final bool isEnabled;
  final List<String> blockedKeywords;
  final Set<String> lockedCategoryIds;
  final Set<String> lockedContentIds;
  final bool autoLockAdultContent;

  // Default keywords that identify adult content
  static const List<String> defaultAdultKeywords = [
    'adult',
    'xxx',
    'porn',
    'erotic',
    '18+',
    'mature',
    'sex',
    'nsfw',
  ];

  ParentalSettings({
    this.pin = '0000',
    this.isEnabled = true,
    List<String>? blockedKeywords,
    Set<String>? lockedCategoryIds,
    Set<String>? lockedContentIds,
    this.autoLockAdultContent = true,
  })  : blockedKeywords = blockedKeywords ?? List.from(defaultAdultKeywords),
        lockedCategoryIds = lockedCategoryIds ?? {},
        lockedContentIds = lockedContentIds ?? {};

  /// Check if a category name matches any blocked keywords
  bool isCategoryBlocked(String categoryName) {
    if (!autoLockAdultContent && blockedKeywords.isEmpty) return false;

    final lowerName = categoryName.toLowerCase();
    for (final keyword in blockedKeywords) {
      if (lowerName.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Check if a content name matches any blocked keywords
  bool isContentNameBlocked(String contentName) {
    if (!autoLockAdultContent && blockedKeywords.isEmpty) return false;

    final lowerName = contentName.toLowerCase();
    for (final keyword in blockedKeywords) {
      if (lowerName.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Check if a specific category ID is manually locked
  bool isCategoryLocked(String categoryId) {
    return lockedCategoryIds.contains(categoryId);
  }

  /// Check if a specific content ID is manually locked
  bool isContentLocked(String contentId) {
    return lockedContentIds.contains(contentId);
  }

  /// Check if content should be hidden (either by keyword or manual lock)
  bool shouldHideContent({
    required String contentId,
    required String contentName,
    String? categoryId,
    String? categoryName,
  }) {
    // Check if content is manually locked
    if (lockedContentIds.contains(contentId)) return true;

    // Check if category is manually locked
    if (categoryId != null && lockedCategoryIds.contains(categoryId)) return true;

    // Check keyword matches
    if (autoLockAdultContent || blockedKeywords.isNotEmpty) {
      if (isContentNameBlocked(contentName)) return true;
      if (categoryName != null && isCategoryBlocked(categoryName)) return true;
    }

    return false;
  }

  ParentalSettings copyWith({
    String? pin,
    bool? isEnabled,
    List<String>? blockedKeywords,
    Set<String>? lockedCategoryIds,
    Set<String>? lockedContentIds,
    bool? autoLockAdultContent,
  }) {
    return ParentalSettings(
      pin: pin ?? this.pin,
      isEnabled: isEnabled ?? this.isEnabled,
      blockedKeywords: blockedKeywords ?? List.from(this.blockedKeywords),
      lockedCategoryIds: lockedCategoryIds ?? Set.from(this.lockedCategoryIds),
      lockedContentIds: lockedContentIds ?? Set.from(this.lockedContentIds),
      autoLockAdultContent: autoLockAdultContent ?? this.autoLockAdultContent,
    );
  }

  Map<String, dynamic> toJson() => {
    'pin': pin,
    'isEnabled': isEnabled,
    'blockedKeywords': blockedKeywords,
    'lockedCategoryIds': lockedCategoryIds.toList(),
    'lockedContentIds': lockedContentIds.toList(),
    'autoLockAdultContent': autoLockAdultContent,
  };

  factory ParentalSettings.fromJson(Map<String, dynamic> json) {
    return ParentalSettings(
      pin: json['pin'] as String? ?? '0000',
      isEnabled: json['isEnabled'] as bool? ?? true,
      blockedKeywords: (json['blockedKeywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? List.from(defaultAdultKeywords),
      lockedCategoryIds: (json['lockedCategoryIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ?? {},
      lockedContentIds: (json['lockedContentIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ?? {},
      autoLockAdultContent: json['autoLockAdultContent'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ParentalSettings.fromJsonString(String jsonString) {
    return ParentalSettings.fromJson(jsonDecode(jsonString));
  }
}
