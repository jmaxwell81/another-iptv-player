import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_iptv_player/models/custom_category.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';

/// Service for managing user-created custom categories.
class CustomCategoryService {
  static final CustomCategoryService _instance = CustomCategoryService._internal();
  factory CustomCategoryService() => _instance;
  CustomCategoryService._internal();

  static const String _keyCustomCategories = 'custom_categories';
  static const String _keyCategoryItemMappings = 'custom_category_item_mappings';

  // Cached data
  List<CustomCategory> _categories = [];
  Map<String, CustomCategoryItem> _itemMappings = {}; // itemId -> CustomCategoryItem
  bool _isInitialized = false;

  /// Initialize the service and load saved categories
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadCategories();
    await _loadItemMappings();
    _isInitialized = true;
  }

  // ==================== Category CRUD ====================

  /// Get all custom categories
  List<CustomCategory> get categories => List.unmodifiable(_categories);

  /// Get categories by content type
  List<CustomCategory> getCategoriesForType(ContentType? contentType) {
    if (contentType == null) return categories;
    return _categories
        .where((c) => c.contentType == null || c.contentType == contentType)
        .toList();
  }

  /// Get a category by ID
  CustomCategory? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Create a new custom category
  Future<CustomCategory> createCategory({
    required String name,
    String? icon,
    ContentType? contentType,
  }) async {
    final category = CustomCategory.create(
      name: name,
      icon: icon,
      contentType: contentType,
      sortOrder: _categories.length,
    );

    _categories.add(category);
    await _saveCategories();
    return category;
  }

  /// Update an existing category
  Future<void> updateCategory(CustomCategory category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      _categories[index] = category;
      await _saveCategories();
    }
  }

  /// Rename a category
  Future<void> renameCategory(String categoryId, String newName) async {
    final category = getCategoryById(categoryId);
    if (category != null) {
      await updateCategory(category.copyWith(name: newName));
    }
  }

  /// Delete a category
  Future<void> deleteCategory(String categoryId) async {
    _categories.removeWhere((c) => c.id == categoryId);
    // Remove all item mappings for this category
    _itemMappings.removeWhere((_, v) => v.categoryId == categoryId);
    await _saveCategories();
    await _saveItemMappings();
  }

  /// Toggle category visibility
  Future<void> toggleCategoryVisibility(String categoryId) async {
    final category = getCategoryById(categoryId);
    if (category != null) {
      await updateCategory(category.copyWith(isVisible: !category.isVisible));
    }
  }

  /// Reorder categories
  Future<void> reorderCategories(List<String> categoryIds) async {
    final newCategories = <CustomCategory>[];
    for (int i = 0; i < categoryIds.length; i++) {
      final category = getCategoryById(categoryIds[i]);
      if (category != null) {
        newCategories.add(category.copyWith(sortOrder: i));
      }
    }
    _categories = newCategories;
    await _saveCategories();
  }

  // ==================== Item Management ====================

  /// Add items to a custom category
  Future<void> addItemsToCategory(
    String categoryId,
    List<ContentItem> items, {
    String? originalCategoryId,
    String? originalCategoryName,
  }) async {
    final category = getCategoryById(categoryId);
    if (category == null) return;

    final newItemIds = <String>{};
    final now = DateTime.now();

    for (final item in items) {
      newItemIds.add(item.id);
      _itemMappings[item.id] = CustomCategoryItem(
        itemId: item.id,
        categoryId: categoryId,
        addedAt: now,
        originalCategoryId: originalCategoryId,
        originalCategoryName: originalCategoryName,
      );
    }

    await updateCategory(category.addItems(newItemIds));
    await _saveItemMappings();
  }

  /// Remove items from a custom category
  Future<void> removeItemsFromCategory(
    String categoryId,
    Set<String> itemIds,
  ) async {
    final category = getCategoryById(categoryId);
    if (category == null) return;

    for (final itemId in itemIds) {
      _itemMappings.remove(itemId);
    }

    await updateCategory(category.removeItems(itemIds));
    await _saveItemMappings();
  }

  /// Move items from one category to another
  Future<void> moveItems(
    Set<String> itemIds,
    String fromCategoryId,
    String toCategoryId,
  ) async {
    await removeItemsFromCategory(fromCategoryId, itemIds);

    // Get items and add to new category
    final toCategory = getCategoryById(toCategoryId);
    if (toCategory != null) {
      final now = DateTime.now();
      for (final itemId in itemIds) {
        _itemMappings[itemId] = CustomCategoryItem(
          itemId: itemId,
          categoryId: toCategoryId,
          addedAt: now,
        );
      }
      await updateCategory(toCategory.addItems(itemIds));
      await _saveItemMappings();
    }
  }

  /// Get the custom category an item belongs to (if any)
  CustomCategory? getItemCategory(String itemId) {
    final mapping = _itemMappings[itemId];
    if (mapping == null) return null;
    return getCategoryById(mapping.categoryId);
  }

  /// Check if an item is in any custom category
  bool isItemInCustomCategory(String itemId) {
    return _itemMappings.containsKey(itemId);
  }

  /// Get all items in a category
  Set<String> getItemsInCategory(String categoryId) {
    final category = getCategoryById(categoryId);
    return category?.itemIds ?? {};
  }

  // ==================== Search & Bulk Operations ====================

  /// Search for items by name pattern (partial match)
  List<ContentItem> searchItemsByName(
    String pattern,
    List<ContentItem> allItems,
  ) {
    if (pattern.isEmpty) return [];

    final lowerPattern = pattern.toLowerCase();
    return allItems.where((item) {
      return item.name.toLowerCase().contains(lowerPattern);
    }).toList();
  }

  /// Search for items by category name pattern
  List<ContentItem> searchItemsByCategoryName(
    String categoryPattern,
    Map<String, List<ContentItem>> itemsByCategory, // categoryName -> items
  ) {
    if (categoryPattern.isEmpty) return [];

    final lowerPattern = categoryPattern.toLowerCase();
    final matchingItems = <ContentItem>[];

    for (final entry in itemsByCategory.entries) {
      if (entry.key.toLowerCase().contains(lowerPattern)) {
        matchingItems.addAll(entry.value);
      }
    }

    return matchingItems;
  }

  /// Combined search by name or category
  Map<String, List<ContentItem>> searchItems({
    required String pattern,
    required List<ContentItem> allItems,
    required Map<String, List<ContentItem>> itemsByCategory,
  }) {
    if (pattern.isEmpty) {
      return {'all': []};
    }

    final lowerPattern = pattern.toLowerCase();
    final results = <String, List<ContentItem>>{};

    // Search by name across all items
    final nameMatches = allItems.where((item) {
      return item.name.toLowerCase().contains(lowerPattern);
    }).toList();
    if (nameMatches.isNotEmpty) {
      results['name_matches'] = nameMatches;
    }

    // Search by category name
    for (final entry in itemsByCategory.entries) {
      if (entry.key.toLowerCase().contains(lowerPattern)) {
        results['category:${entry.key}'] = entry.value;
      }
    }

    return results;
  }

  // ==================== Persistence ====================

  Future<void> _loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyCustomCategories);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _categories = list.map((e) => CustomCategory.fromJson(e)).toList();
        // Sort by sortOrder
        _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
    } catch (e) {
      debugPrint('CustomCategoryService: Error loading categories: $e');
    }
  }

  Future<void> _saveCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_categories.map((c) => c.toJson()).toList());
      await prefs.setString(_keyCustomCategories, json);
    } catch (e) {
      debugPrint('CustomCategoryService: Error saving categories: $e');
    }
  }

  Future<void> _loadItemMappings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyCategoryItemMappings);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _itemMappings = map.map(
          (k, v) => MapEntry(k, CustomCategoryItem.fromJson(v)),
        );
      }
    } catch (e) {
      debugPrint('CustomCategoryService: Error loading item mappings: $e');
    }
  }

  Future<void> _saveItemMappings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
        _itemMappings.map((k, v) => MapEntry(k, v.toJson())),
      );
      await prefs.setString(_keyCategoryItemMappings, json);
    } catch (e) {
      debugPrint('CustomCategoryService: Error saving item mappings: $e');
    }
  }

  /// Clear all custom categories and mappings
  Future<void> clearAll() async {
    _categories.clear();
    _itemMappings.clear();
    await _saveCategories();
    await _saveItemMappings();
  }
}
