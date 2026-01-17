import 'package:another_iptv_player/models/content_type.dart';

/// Enum for specifying which content types a rule applies to
enum RuleAppliesTo {
  all,
  categories,
  liveStream,
  vod,
  series;

  String get value {
    switch (this) {
      case RuleAppliesTo.all:
        return 'all';
      case RuleAppliesTo.categories:
        return 'categories';
      case RuleAppliesTo.liveStream:
        return 'liveStream';
      case RuleAppliesTo.vod:
        return 'vod';
      case RuleAppliesTo.series:
        return 'series';
    }
  }

  static RuleAppliesTo fromString(String value) {
    switch (value) {
      case 'all':
        return RuleAppliesTo.all;
      case 'categories':
        return RuleAppliesTo.categories;
      case 'liveStream':
        return RuleAppliesTo.liveStream;
      case 'vod':
        return RuleAppliesTo.vod;
      case 'series':
        return RuleAppliesTo.series;
      default:
        return RuleAppliesTo.all;
    }
  }

  /// Check if this rule applies to a given ContentType
  bool appliesTo(ContentType? contentType) {
    if (this == RuleAppliesTo.all) return true;
    if (contentType == null) return false;
    switch (this) {
      case RuleAppliesTo.liveStream:
        return contentType == ContentType.liveStream;
      case RuleAppliesTo.vod:
        return contentType == ContentType.vod;
      case RuleAppliesTo.series:
        return contentType == ContentType.series;
      case RuleAppliesTo.categories:
        return false;
      case RuleAppliesTo.all:
        return true;
    }
  }

  /// Check if this rule applies to categories
  bool appliesToCategories() {
    return this == RuleAppliesTo.all || this == RuleAppliesTo.categories;
  }
}

class RenamingRule {
  final String id;
  final String findText;
  final String replaceText;
  final bool fullWordsOnly;
  final RuleAppliesTo appliesTo;
  final bool isEnabled;
  final DateTime createdAt;

  RenamingRule({
    required this.id,
    required this.findText,
    required this.replaceText,
    this.fullWordsOnly = false,
    this.appliesTo = RuleAppliesTo.all,
    this.isEnabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  RenamingRule copyWith({
    String? id,
    String? findText,
    String? replaceText,
    bool? fullWordsOnly,
    RuleAppliesTo? appliesTo,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return RenamingRule(
      id: id ?? this.id,
      findText: findText ?? this.findText,
      replaceText: replaceText ?? this.replaceText,
      fullWordsOnly: fullWordsOnly ?? this.fullWordsOnly,
      appliesTo: appliesTo ?? this.appliesTo,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'findText': findText,
      'replaceText': replaceText,
      'fullWordsOnly': fullWordsOnly,
      'appliesTo': appliesTo.value,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON map
  factory RenamingRule.fromJson(Map<String, dynamic> json) {
    return RenamingRule(
      id: json['id'] as String,
      findText: json['findText'] as String,
      replaceText: json['replaceText'] as String? ?? '',
      fullWordsOnly: json['fullWordsOnly'] as bool? ?? false,
      appliesTo: RuleAppliesTo.fromString(json['appliesTo'] as String? ?? 'all'),
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// Generate a new unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
