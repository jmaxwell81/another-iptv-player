import 'package:another_iptv_player/models/content_type.dart';

/// Represents a user-created custom category that can contain items from any source.
class CustomCategory {
  final String id;
  final String name;
  final String? icon; // Icon name or emoji
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;
  final bool isVisible;

  /// The content type this category applies to (null means all types)
  final ContentType? contentType;

  /// List of item IDs in this category
  final Set<String> itemIds;

  const CustomCategory({
    required this.id,
    required this.name,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.isVisible = true,
    this.contentType,
    this.itemIds = const {},
  });

  /// Create a new category with generated ID
  factory CustomCategory.create({
    required String name,
    String? icon,
    ContentType? contentType,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return CustomCategory(
      id: 'custom_${now.millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
      contentType: contentType,
      itemIds: {},
    );
  }

  /// Create from JSON
  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
      contentType: json['contentType'] != null
          ? ContentType.values.firstWhere(
              (e) => e.name == json['contentType'],
              orElse: () => ContentType.vod,
            )
          : null,
      itemIds: json['itemIds'] != null
          ? Set<String>.from(json['itemIds'] as List)
          : {},
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sortOrder': sortOrder,
      'isVisible': isVisible,
      'contentType': contentType?.name,
      'itemIds': itemIds.toList(),
    };
  }

  /// Create a copy with updated fields
  CustomCategory copyWith({
    String? id,
    String? name,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    bool? isVisible,
    ContentType? contentType,
    Set<String>? itemIds,
  }) {
    return CustomCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sortOrder: sortOrder ?? this.sortOrder,
      isVisible: isVisible ?? this.isVisible,
      contentType: contentType ?? this.contentType,
      itemIds: itemIds ?? this.itemIds,
    );
  }

  /// Add items to this category
  CustomCategory addItems(Set<String> newItemIds) {
    return copyWith(
      itemIds: {...itemIds, ...newItemIds},
    );
  }

  /// Remove items from this category
  CustomCategory removeItems(Set<String> removeItemIds) {
    return copyWith(
      itemIds: itemIds.difference(removeItemIds),
    );
  }

  /// Check if this category contains an item
  bool containsItem(String itemId) => itemIds.contains(itemId);

  /// Get the number of items in this category
  int get itemCount => itemIds.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CustomCategory($name, ${itemIds.length} items)';
}

/// Represents a reference to an item in a custom category
class CustomCategoryItem {
  final String itemId;
  final String categoryId;
  final DateTime addedAt;
  final String? originalCategoryId; // The original category this item came from
  final String? originalCategoryName;

  const CustomCategoryItem({
    required this.itemId,
    required this.categoryId,
    required this.addedAt,
    this.originalCategoryId,
    this.originalCategoryName,
  });

  factory CustomCategoryItem.fromJson(Map<String, dynamic> json) {
    return CustomCategoryItem(
      itemId: json['itemId'] as String,
      categoryId: json['categoryId'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      originalCategoryId: json['originalCategoryId'] as String?,
      originalCategoryName: json['originalCategoryName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'categoryId': categoryId,
      'addedAt': addedAt.toIso8601String(),
      'originalCategoryId': originalCategoryId,
      'originalCategoryName': originalCategoryName,
    };
  }
}
