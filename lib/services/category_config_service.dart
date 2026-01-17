import 'package:flutter/foundation.dart' hide Category;
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_config.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// Service for managing category configuration (merging and ordering)
class CategoryConfigService {
  static final CategoryConfigService _instance = CategoryConfigService._internal();
  factory CategoryConfigService() => _instance;
  CategoryConfigService._internal();

  Map<String, CategoryConfig>? _cachedConfigs;
  bool _isLoading = false;

  /// Load and cache configs from storage
  Future<void> loadConfigs() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      _cachedConfigs = await UserPreferences.getCategoryConfigs();
      debugPrint('CategoryConfigService: Loaded ${_cachedConfigs?.length ?? 0} configs');
    } finally {
      _isLoading = false;
    }
  }

  /// Clear the cache
  void invalidateCache() {
    _cachedConfigs = null;
  }

  /// Get config for a playlist, loading if necessary
  Future<CategoryConfig> getConfig(String playlistId) async {
    if (_cachedConfigs == null) {
      await loadConfigs();
    }
    return _cachedConfigs?[playlistId] ?? CategoryConfig(playlistId: playlistId);
  }

  /// Get config synchronously (returns empty if not loaded)
  CategoryConfig getConfigSync(String playlistId) {
    if (_cachedConfigs == null) {
      loadConfigs();
      return CategoryConfig(playlistId: playlistId);
    }
    return _cachedConfigs?[playlistId] ?? CategoryConfig(playlistId: playlistId);
  }

  /// Save config
  Future<void> saveConfig(CategoryConfig config) async {
    await UserPreferences.setCategoryConfig(config);
    invalidateCache();
    await loadConfigs();
  }

  /// Merge multiple categories into one
  Future<void> mergeCategories({
    required String playlistId,
    required CategoryType type,
    required List<String> categoryIds,
    required String displayName,
  }) async {
    if (categoryIds.length < 2) return;

    final config = await getConfig(playlistId);
    final typeConfig = config.getConfigForType(type);

    // Create new merge group
    final mergeGroup = MergedCategory(
      id: MergedCategory.generateId(),
      displayName: displayName,
      categoryIds: categoryIds,
    );

    // Add to merged categories
    final newMergedCategories = List<MergedCategory>.from(typeConfig.mergedCategories)
      ..add(mergeGroup);

    // Update order: replace first category with merge group, remove others
    final newOrder = List<String>.from(typeConfig.order);
    if (newOrder.isEmpty) {
      newOrder.add(mergeGroup.id);
    } else {
      // Find the first occurrence of any merged category and replace with merge group
      int firstIndex = -1;
      for (int i = 0; i < newOrder.length && firstIndex == -1; i++) {
        if (categoryIds.contains(newOrder[i])) {
          firstIndex = i;
        }
      }
      if (firstIndex != -1) {
        newOrder[firstIndex] = mergeGroup.id;
      } else {
        newOrder.add(mergeGroup.id);
      }
      // Remove the other merged category IDs from order
      newOrder.removeWhere((id) => categoryIds.contains(id) && id != mergeGroup.id);
    }

    final newTypeConfig = typeConfig.copyWith(
      mergedCategories: newMergedCategories,
      order: newOrder,
    );

    await saveConfig(config.updateTypeConfig(type, newTypeConfig));
  }

  /// Unmerge a merged category group
  Future<void> unmergeCategoryGroup({
    required String playlistId,
    required CategoryType type,
    required String mergeGroupId,
  }) async {
    final config = await getConfig(playlistId);
    final typeConfig = config.getConfigForType(type);

    // Find the merge group
    final mergeGroup = typeConfig.getMergeGroup(mergeGroupId);
    if (mergeGroup == null) return;

    // Remove from merged categories
    final newMergedCategories = List<MergedCategory>.from(typeConfig.mergedCategories)
      ..removeWhere((m) => m.id == mergeGroupId);

    // Update order: replace merge group with its category IDs
    final newOrder = List<String>.from(typeConfig.order);
    final mergeIndex = newOrder.indexOf(mergeGroupId);
    if (mergeIndex != -1) {
      newOrder.removeAt(mergeIndex);
      newOrder.insertAll(mergeIndex, mergeGroup.categoryIds);
    }

    final newTypeConfig = typeConfig.copyWith(
      mergedCategories: newMergedCategories,
      order: newOrder,
    );

    await saveConfig(config.updateTypeConfig(type, newTypeConfig));
  }

  /// Update the display name of a merge group
  Future<void> updateMergeGroupName({
    required String playlistId,
    required CategoryType type,
    required String mergeGroupId,
    required String newName,
  }) async {
    final config = await getConfig(playlistId);
    final typeConfig = config.getConfigForType(type);

    final newMergedCategories = typeConfig.mergedCategories.map((m) {
      if (m.id == mergeGroupId) {
        return m.copyWith(displayName: newName);
      }
      return m;
    }).toList();

    final newTypeConfig = typeConfig.copyWith(mergedCategories: newMergedCategories);
    await saveConfig(config.updateTypeConfig(type, newTypeConfig));
  }

  /// Move a category/merge group to a new position
  Future<void> moveCategory({
    required String playlistId,
    required CategoryType type,
    required String itemId,
    required int newIndex,
  }) async {
    final config = await getConfig(playlistId);
    final typeConfig = config.getConfigForType(type);

    final newOrder = List<String>.from(typeConfig.order);
    final currentIndex = newOrder.indexOf(itemId);

    if (currentIndex == -1) {
      // Item not in order, add it
      if (newIndex >= newOrder.length) {
        newOrder.add(itemId);
      } else {
        newOrder.insert(newIndex, itemId);
      }
    } else {
      // Move to new position
      newOrder.removeAt(currentIndex);
      final adjustedIndex = newIndex > currentIndex ? newIndex - 1 : newIndex;
      if (adjustedIndex >= newOrder.length) {
        newOrder.add(itemId);
      } else {
        newOrder.insert(adjustedIndex.clamp(0, newOrder.length), itemId);
      }
    }

    final newTypeConfig = typeConfig.copyWith(order: newOrder);
    await saveConfig(config.updateTypeConfig(type, newTypeConfig));
  }

  /// Set the full order for a category type
  Future<void> setOrder({
    required String playlistId,
    required CategoryType type,
    required List<String> order,
  }) async {
    final config = await getConfig(playlistId);
    final typeConfig = config.getConfigForType(type);
    final newTypeConfig = typeConfig.copyWith(order: order);
    await saveConfig(config.updateTypeConfig(type, newTypeConfig));
  }

  /// Apply configuration to a list of categories, returning ordered and merged results
  List<CategoryViewModel> applyConfig({
    required String playlistId,
    required CategoryType type,
    required List<CategoryViewModel> categories,
  }) {
    final config = getConfigSync(playlistId);
    final typeConfig = config.getConfigForType(type);

    if (typeConfig.order.isEmpty && typeConfig.mergedCategories.isEmpty) {
      return categories; // No config, return as-is
    }

    // Build a map of category ID to view model
    final categoryMap = <String, CategoryViewModel>{};
    for (final cat in categories) {
      categoryMap[cat.category.categoryId] = cat;
    }

    // Build result list respecting order and merges
    final result = <CategoryViewModel>[];
    final processedCategoryIds = <String>{};

    // First, process items in the configured order
    for (final itemId in typeConfig.order) {
      // Check if it's a merge group
      final mergeGroup = typeConfig.getMergeGroup(itemId);
      if (mergeGroup != null) {
        // Merge the categories
        final mergedViewModel = _createMergedViewModel(mergeGroup, categoryMap);
        if (mergedViewModel != null) {
          result.add(mergedViewModel);
          processedCategoryIds.addAll(mergeGroup.categoryIds);
        }
      } else {
        // Regular category
        final catViewModel = categoryMap[itemId];
        if (catViewModel != null && !typeConfig.isCategoryMerged(itemId)) {
          result.add(catViewModel);
          processedCategoryIds.add(itemId);
        }
      }
    }

    // Add any categories not in the order (and not merged) at the end
    for (final cat in categories) {
      final catId = cat.category.categoryId;
      if (!processedCategoryIds.contains(catId) && !typeConfig.isCategoryMerged(catId)) {
        result.add(cat);
      }
    }

    return result;
  }

  /// Create a merged category view model
  CategoryViewModel? _createMergedViewModel(
    MergedCategory mergeGroup,
    Map<String, CategoryViewModel> categoryMap,
  ) {
    // Collect all content items from merged categories
    final allContentItems = <dynamic>[];
    Category? firstCategory;

    for (final catId in mergeGroup.categoryIds) {
      final catViewModel = categoryMap[catId];
      if (catViewModel != null) {
        firstCategory ??= catViewModel.category;
        allContentItems.addAll(catViewModel.contentItems);
      }
    }

    if (firstCategory == null) return null;

    // Create a virtual category with the merge group's display name
    final mergedCategory = Category(
      categoryId: mergeGroup.id,
      categoryName: mergeGroup.displayName,
      parentId: firstCategory.parentId,
      playlistId: firstCategory.playlistId,
      type: firstCategory.type,
    );

    return CategoryViewModel(
      category: mergedCategory,
      contentItems: allContentItems.cast(),
    );
  }

  /// Get the effective display name for a category (considering merges)
  String? getMergedDisplayName(String playlistId, CategoryType type, String categoryId) {
    final config = getConfigSync(playlistId);
    final typeConfig = config.getConfigForType(type);
    final mergeGroup = typeConfig.getMergeGroupForCategory(categoryId);
    return mergeGroup?.displayName;
  }
}
