import 'package:flutter/foundation.dart' hide Category;
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/favorites_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// Service for managing the special "Favorites" category that shows
/// favorites from hidden categories.
class HiddenFavoritesService {
  static final HiddenFavoritesService _instance = HiddenFavoritesService._internal();
  factory HiddenFavoritesService() => _instance;
  HiddenFavoritesService._internal();

  String _categoryName = 'Favorites';
  bool _showCategory = true;

  String get categoryName => _categoryName;
  bool get showCategory => _showCategory;

  /// Special category ID for the hidden favorites category
  static const String hiddenFavoritesCategoryId = '_hidden_favorites_';

  /// Initialize the service and load preferences
  Future<void> initialize() async {
    _categoryName = await UserPreferences.getHiddenFavoritesCategoryName();
    _showCategory = await UserPreferences.getShowHiddenFavoritesCategory();
  }

  /// Update the category name
  Future<void> setCategoryName(String name) async {
    _categoryName = name;
    await UserPreferences.setHiddenFavoritesCategoryName(name);
  }

  /// Update whether to show the category
  Future<void> setShowCategory(bool show) async {
    _showCategory = show;
    await UserPreferences.setShowHiddenFavoritesCategory(show);
  }

  /// Build the hidden favorites category for a specific content type.
  /// Returns null if there are no favorites from hidden categories.
  Future<CategoryViewModel?> buildHiddenFavoritesCategory({
    required CategoryType type,
    required Set<String> hiddenCategoryIds,
    required Set<String> hiddenCategoryNames,
    required List<CategoryViewModel> allCategories,
  }) async {
    if (!_showCategory) return null;

    try {
      final favoritesRepository = FavoritesRepository();
      final allFavorites = await favoritesRepository.getAllFavorites();

      if (allFavorites.isEmpty) return null;

      // Get favorites that belong to hidden categories
      final favoritesFromHidden = <Favorite>[];

      for (final favorite in allFavorites) {
        // Check if this favorite's category is hidden
        final isHidden = await _isFavoriteFromHiddenCategory(
          favorite,
          hiddenCategoryIds,
          hiddenCategoryNames,
          allCategories,
        );

        if (isHidden) {
          favoritesFromHidden.add(favorite);
        }
      }

      if (favoritesFromHidden.isEmpty) return null;

      // Convert favorites to ContentItems
      final contentItems = <ContentItem>[];
      for (final favorite in favoritesFromHidden) {
        // Filter by content type
        if (!_matchesContentType(favorite, type)) continue;

        final contentItem = await favoritesRepository.getContentItemFromFavorite(favorite);
        if (contentItem != null) {
          contentItems.add(contentItem);
        }
      }

      if (contentItems.isEmpty) return null;

      // Create the special category
      final category = Category(
        categoryId: hiddenFavoritesCategoryId,
        categoryName: _categoryName,
        parentId: 0,
        playlistId: 'special',
        type: type,
      );

      return CategoryViewModel(
        category: category,
        contentItems: contentItems,
      );
    } catch (e) {
      debugPrint('Error building hidden favorites category: $e');
      return null;
    }
  }

  /// Check if a favorite is from a hidden category
  Future<bool> _isFavoriteFromHiddenCategory(
    Favorite favorite,
    Set<String> hiddenCategoryIds,
    Set<String> hiddenCategoryNames,
    List<CategoryViewModel> allCategories,
  ) async {
    // Find which category this favorite belongs to
    for (final categoryVm in allCategories) {
      // Check if this category contains the favorite
      final containsFavorite = categoryVm.contentItems.any((item) =>
          item.id == favorite.streamId ||
          (item.m3uItem?.id != null && item.m3uItem!.id == favorite.m3uItemId));

      if (containsFavorite) {
        // Check if this category is hidden
        final categoryId = categoryVm.category.categoryId;
        final categoryName = categoryVm.category.categoryName.toLowerCase().trim();

        if (hiddenCategoryIds.contains(categoryId) ||
            hiddenCategoryNames.contains(categoryName)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if a favorite matches a content type
  bool _matchesContentType(Favorite favorite, CategoryType type) {
    switch (type) {
      case CategoryType.live:
        return favorite.contentType.name == 'liveStream';
      case CategoryType.vod:
        return favorite.contentType.name == 'vod';
      case CategoryType.series:
        return favorite.contentType.name == 'series';
    }
  }

  /// Check if a category ID is the special hidden favorites category
  static bool isHiddenFavoritesCategory(String categoryId) {
    return categoryId == hiddenFavoritesCategoryId;
  }
}
