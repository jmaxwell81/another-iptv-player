import 'package:flutter/foundation.dart' hide Category;
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/content_consolidation_service.dart';
import 'package:another_iptv_player/services/content_preference_service.dart';

/// Repository for aggregating content from multiple IPTV sources
class UnifiedContentRepository {
  /// Get unified categories for a specific type, merged by name
  Future<List<CategoryViewModel>> getUnifiedCategories({
    required CategoryType type,
    int previewLimit = 15,
  }) async {
    final allCategories = <CategoryViewModel>[];

    debugPrint('UnifiedContentRepository: Loading $type categories');
    debugPrint('  Active playlists: ${AppState.activePlaylists.keys.toList()}');
    debugPrint('  Xtream repositories: ${AppState.xtreamRepositories.keys.toList()}');
    debugPrint('  M3U repositories: ${AppState.m3uRepositories.keys.toList()}');

    // Collect from all active Xtream repositories
    for (final entry in AppState.xtreamRepositories.entries) {
      final playlistId = entry.key;
      final repository = entry.value;
      final playlist = AppState.activePlaylists[playlistId];

      if (playlist == null) {
        debugPrint('  Xtream: Playlist $playlistId not found in activePlaylists, skipping');
        continue;
      }

      try {
        final categories = await _loadXtreamCategories(
          repository: repository,
          playlist: playlist,
          type: type,
          previewLimit: previewLimit,
        );
        debugPrint('  Xtream: Loaded ${categories.length} $type categories from ${playlist.name}');
        allCategories.addAll(categories);
      } catch (e) {
        debugPrint('UnifiedContentRepository: Error loading Xtream categories from $playlistId: $e');
      }
    }

    // Collect from all active M3U repositories
    for (final entry in AppState.m3uRepositories.entries) {
      final playlistId = entry.key;
      final repository = entry.value;
      final playlist = AppState.activePlaylists[playlistId];

      if (playlist == null) {
        debugPrint('  M3U: Playlist $playlistId not found in activePlaylists, skipping');
        continue;
      }

      try {
        final categories = await _loadM3uCategories(
          repository: repository,
          playlist: playlist,
          type: type,
          previewLimit: previewLimit,
        );
        debugPrint('  M3U: Loaded ${categories.length} $type categories from ${playlist.name}');
        allCategories.addAll(categories);
      } catch (e) {
        debugPrint('UnifiedContentRepository: Error loading M3U categories from $playlistId: $e');
      }
    }

    debugPrint('UnifiedContentRepository: Total $type categories before merge: ${allCategories.length}');

    // Merge categories by normalized name
    final merged = _mergeByName(allCategories, type);
    debugPrint('UnifiedContentRepository: Total $type categories after merge: ${merged.length}');

    // Apply content consolidation if enabled
    final consolidationEnabled = await UserPreferences.getConsolidationEnabled();
    if (consolidationEnabled) {
      final consolidated = await _consolidateCategories(merged);
      debugPrint('UnifiedContentRepository: Applied content consolidation');
      return consolidated;
    }

    return merged;
  }

  /// Apply content consolidation to merge duplicate items within categories
  Future<List<CategoryViewModel>> _consolidateCategories(
    List<CategoryViewModel> categories,
  ) async {
    final consolidationService = ContentConsolidationService();
    final preferenceService = ContentPreferenceService();
    await preferenceService.loadPreferences();

    final result = <CategoryViewModel>[];

    for (final category in categories) {
      if (category.contentItems.isEmpty) {
        result.add(category);
        continue;
      }

      try {
        // Consolidate content items within this category
        final consolidated = consolidationService.consolidateWithPreferences(
          category.contentItems,
          preferredQuality: preferenceService.preferredQuality,
          preferredLanguage: preferenceService.preferredLanguage,
        );

        // Create new CategoryViewModel with consolidated items
        result.add(category.withConsolidatedItems(consolidated));

        // Log consolidation stats for debugging
        if (consolidated.length < category.contentItems.length) {
          final stats = consolidationService.getConsolidationStats(consolidated);
          debugPrint('  ${category.category.categoryName}: '
              '${category.contentItems.length} -> ${consolidated.length} items '
              '(${stats.itemsWithMultipleSources} with multiple sources)');
        }
      } catch (e) {
        debugPrint('UnifiedContentRepository: Error consolidating category '
            '${category.category.categoryName}: $e');
        result.add(category);
      }
    }

    return result;
  }

  /// Load categories from an Xtream repository
  Future<List<CategoryViewModel>> _loadXtreamCategories({
    required dynamic repository,
    required Playlist playlist,
    required CategoryType type,
    required int previewLimit,
  }) async {
    final result = <CategoryViewModel>[];

    // Get categories based on type
    List<Category>? categories;
    switch (type) {
      case CategoryType.live:
        categories = await repository.getLiveCategories();
        break;
      case CategoryType.vod:
        categories = await repository.getVodCategories();
        break;
      case CategoryType.series:
        categories = await repository.getSeriesCategories();
        break;
    }

    if (categories == null || categories.isEmpty) return result;

    // Load content for each category
    for (final category in categories) {
      final contentItems = await _loadXtreamContent(
        repository: repository,
        playlist: playlist,
        category: category,
        type: type,
        limit: previewLimit,
      );

      if (contentItems.isNotEmpty) {
        result.add(CategoryViewModel(
          category: category,
          contentItems: contentItems,
        ));
      }
    }

    return result;
  }

  /// Load content items from Xtream repository
  Future<List<ContentItem>> _loadXtreamContent({
    required dynamic repository,
    required Playlist playlist,
    required Category category,
    required CategoryType type,
    required int limit,
  }) async {
    try {
      switch (type) {
        case CategoryType.live:
          final streams = await repository.getLiveChannelsByCategoryId(
            categoryId: category.categoryId,
            top: limit,
          );
          if (streams == null) return <ContentItem>[];
          final List<ContentItem> result = [];
          for (final s in streams) {
            result.add(ContentItem(
              s.streamId,
              s.name,
              s.streamIcon ?? '',
              ContentType.liveStream,
              liveStream: s,
              sourcePlaylistId: playlist.id,
              sourceType: PlaylistType.xtream,
            ));
          }
          return result;

        case CategoryType.vod:
          final movies = await repository.getMovies(
            categoryId: category.categoryId,
            top: limit,
          );
          if (movies == null) return <ContentItem>[];
          final List<ContentItem> result = [];
          for (final m in movies) {
            result.add(ContentItem(
              m.streamId,
              m.name,
              m.streamIcon ?? '',
              ContentType.vod,
              vodStream: m,
              containerExtension: m.containerExtension,
              sourcePlaylistId: playlist.id,
              sourceType: PlaylistType.xtream,
            ));
          }
          return result;

        case CategoryType.series:
          final series = await repository.getSeries(
            categoryId: category.categoryId,
            top: limit,
          );
          if (series == null) return <ContentItem>[];
          final List<ContentItem> result = [];
          for (final s in series) {
            result.add(ContentItem(
              s.seriesId,
              s.name,
              s.cover ?? '',
              ContentType.series,
              seriesStream: s,
              sourcePlaylistId: playlist.id,
              sourceType: PlaylistType.xtream,
            ));
          }
          return result;
      }
    } catch (e) {
      debugPrint('UnifiedContentRepository: Error loading content: $e');
      return <ContentItem>[];
    }
  }

  /// Load categories from an M3U repository
  Future<List<CategoryViewModel>> _loadM3uCategories({
    required dynamic repository,
    required Playlist playlist,
    required CategoryType type,
    required int previewLimit,
  }) async {
    final result = <CategoryViewModel>[];

    // M3U doesn't have separate category types in the same way
    // Get all categories and filter by content type
    final categories = await repository.getCategories();
    if (categories == null || categories.isEmpty) return result;

    for (final category in categories) {
      final items = await repository.getM3uItemsByCategoryId(
        categoryId: category.categoryId,
        top: previewLimit,
      );

      if (items == null || items.isEmpty) continue;

      // Filter items by content type
      final filteredItems = items.where((item) {
        final contentType = item.contentType;
        switch (type) {
          case CategoryType.live:
            return contentType == ContentType.liveStream;
          case CategoryType.vod:
            return contentType == ContentType.vod;
          case CategoryType.series:
            return contentType == ContentType.series;
        }
      }).toList();

      if (filteredItems.isEmpty) continue;

      final List<ContentItem> contentItems = [];
      for (final m in filteredItems) {
        contentItems.add(ContentItem(
          m.id,
          m.name,
          m.tvgLogo ?? '',
          m.contentType,
          m3uItem: m,
          sourcePlaylistId: playlist.id,
          sourceType: PlaylistType.m3u,
        ));
      }

      if (contentItems.isNotEmpty) {
        result.add(CategoryViewModel(
          category: category,
          contentItems: contentItems,
        ));
      }
    }

    return result;
  }

  /// Merge categories by normalized name (case-insensitive, trimmed)
  List<CategoryViewModel> _mergeByName(
    List<CategoryViewModel> allCategories,
    CategoryType type,
  ) {
    if (allCategories.isEmpty) return [];

    // Group by normalized name
    final grouped = <String, List<CategoryViewModel>>{};
    for (final cat in allCategories) {
      final normalizedName = _normalizeCategoryName(cat.category.categoryName);
      grouped.putIfAbsent(normalizedName, () => []).add(cat);
    }

    // Create merged CategoryViewModels
    final result = <CategoryViewModel>[];
    for (final entry in grouped.entries) {
      final categories = entry.value;

      if (categories.length == 1) {
        // Single source - keep original category with its playlistId intact
        // The playlistId on the category is used for routing to the correct repository
        result.add(categories.first);
      } else {
        // Merge content from all categories with this name
        final mergedContent = <ContentItem>[];
        for (final cat in categories) {
          mergedContent.addAll(cat.contentItems);
        }

        // Use the first category as the base (for name, etc.)
        final baseCategory = categories.first.category;

        // Create a virtual merged category with normalized name as ID
        final mergedCategory = Category(
          categoryId: 'merged_${entry.key}',
          categoryName: baseCategory.categoryName,
          parentId: baseCategory.parentId,
          playlistId: 'unified', // Virtual playlist ID for merged categories
          type: type,
        );

        result.add(CategoryViewModel(
          category: mergedCategory,
          contentItems: mergedContent,
        ));
      }
    }

    return result;
  }

  /// Normalize category name for comparison
  String _normalizeCategoryName(String name) {
    return name.toLowerCase().trim();
  }
}
