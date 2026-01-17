import 'dart:convert';
import 'package:another_iptv_player/models/category_type.dart';

/// Represents a group of merged categories
class MergedCategory {
  final String id; // Unique ID for this merge group
  final String displayName; // Custom display name for the merged category
  final List<String> categoryIds; // List of original category IDs that are merged
  final DateTime createdAt;

  MergedCategory({
    required this.id,
    required this.displayName,
    required this.categoryIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Generate a unique ID for a new merge group
  static String generateId() {
    return 'merge_${DateTime.now().millisecondsSinceEpoch}';
  }

  MergedCategory copyWith({
    String? id,
    String? displayName,
    List<String>? categoryIds,
    DateTime? createdAt,
  }) {
    return MergedCategory(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      categoryIds: categoryIds ?? List.from(this.categoryIds),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'categoryIds': categoryIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MergedCategory.fromJson(Map<String, dynamic> json) {
    return MergedCategory(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      categoryIds: List<String>.from(json['categoryIds'] as List),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Configuration for category ordering and merging for a specific content type
class CategoryTypeConfig {
  final CategoryType type;
  final List<String> order; // List of category IDs or merge group IDs in display order
  final List<MergedCategory> mergedCategories;

  CategoryTypeConfig({
    required this.type,
    List<String>? order,
    List<MergedCategory>? mergedCategories,
  })  : order = order ?? [],
        mergedCategories = mergedCategories ?? [];

  CategoryTypeConfig copyWith({
    CategoryType? type,
    List<String>? order,
    List<MergedCategory>? mergedCategories,
  }) {
    return CategoryTypeConfig(
      type: type ?? this.type,
      order: order ?? List.from(this.order),
      mergedCategories: mergedCategories ?? List.from(this.mergedCategories),
    );
  }

  /// Check if a category ID is part of a merged group
  bool isCategoryMerged(String categoryId) {
    return mergedCategories.any((m) => m.categoryIds.contains(categoryId));
  }

  /// Get the merge group that contains a category, or null if not merged
  MergedCategory? getMergeGroupForCategory(String categoryId) {
    try {
      return mergedCategories.firstWhere((m) => m.categoryIds.contains(categoryId));
    } catch (e) {
      return null;
    }
  }

  /// Get merge group by ID
  MergedCategory? getMergeGroup(String mergeId) {
    try {
      return mergedCategories.firstWhere((m) => m.id == mergeId);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'order': order,
      'mergedCategories': mergedCategories.map((m) => m.toJson()).toList(),
    };
  }

  factory CategoryTypeConfig.fromJson(Map<String, dynamic> json) {
    return CategoryTypeConfig(
      type: CategoryType.fromString(json['type'] as String),
      order: List<String>.from(json['order'] as List? ?? []),
      mergedCategories: (json['mergedCategories'] as List?)
              ?.map((m) => MergedCategory.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Full category configuration for a playlist
class CategoryConfig {
  final String playlistId;
  final CategoryTypeConfig liveConfig;
  final CategoryTypeConfig vodConfig;
  final CategoryTypeConfig seriesConfig;

  CategoryConfig({
    required this.playlistId,
    CategoryTypeConfig? liveConfig,
    CategoryTypeConfig? vodConfig,
    CategoryTypeConfig? seriesConfig,
  })  : liveConfig = liveConfig ?? CategoryTypeConfig(type: CategoryType.live),
        vodConfig = vodConfig ?? CategoryTypeConfig(type: CategoryType.vod),
        seriesConfig = seriesConfig ?? CategoryTypeConfig(type: CategoryType.series);

  CategoryTypeConfig getConfigForType(CategoryType type) {
    switch (type) {
      case CategoryType.live:
        return liveConfig;
      case CategoryType.vod:
        return vodConfig;
      case CategoryType.series:
        return seriesConfig;
    }
  }

  CategoryConfig copyWith({
    String? playlistId,
    CategoryTypeConfig? liveConfig,
    CategoryTypeConfig? vodConfig,
    CategoryTypeConfig? seriesConfig,
  }) {
    return CategoryConfig(
      playlistId: playlistId ?? this.playlistId,
      liveConfig: liveConfig ?? this.liveConfig,
      vodConfig: vodConfig ?? this.vodConfig,
      seriesConfig: seriesConfig ?? this.seriesConfig,
    );
  }

  CategoryConfig updateTypeConfig(CategoryType type, CategoryTypeConfig config) {
    switch (type) {
      case CategoryType.live:
        return copyWith(liveConfig: config);
      case CategoryType.vod:
        return copyWith(vodConfig: config);
      case CategoryType.series:
        return copyWith(seriesConfig: config);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'playlistId': playlistId,
      'liveConfig': liveConfig.toJson(),
      'vodConfig': vodConfig.toJson(),
      'seriesConfig': seriesConfig.toJson(),
    };
  }

  factory CategoryConfig.fromJson(Map<String, dynamic> json) {
    return CategoryConfig(
      playlistId: json['playlistId'] as String,
      liveConfig: json['liveConfig'] != null
          ? CategoryTypeConfig.fromJson(json['liveConfig'] as Map<String, dynamic>)
          : null,
      vodConfig: json['vodConfig'] != null
          ? CategoryTypeConfig.fromJson(json['vodConfig'] as Map<String, dynamic>)
          : null,
      seriesConfig: json['seriesConfig'] != null
          ? CategoryTypeConfig.fromJson(json['seriesConfig'] as Map<String, dynamic>)
          : null,
    );
  }

  static String configsToJson(Map<String, CategoryConfig> configs) {
    final map = configs.map((key, value) => MapEntry(key, value.toJson()));
    return jsonEncode(map);
  }

  static Map<String, CategoryConfig> configsFromJson(String jsonString) {
    if (jsonString.isEmpty) return {};
    final Map<String, dynamic> map = jsonDecode(jsonString) as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(
          key,
          CategoryConfig.fromJson(value as Map<String, dynamic>),
        ));
  }
}
