import 'dart:convert';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_filter.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/service_locator.dart';

/// Service to apply content filters and sorting to content items
class ContentFilterApplyService {
  final AppDatabase _database = getIt<AppDatabase>();

  /// Cache of content details for faster filtering
  final Map<String, ContentDetailsData> _detailsCache = {};

  /// Load content details into cache for a list of content items
  Future<void> preloadDetails(List<ContentItem> items, String playlistId) async {
    for (final item in items) {
      final key = '${item.id}_$playlistId';
      if (!_detailsCache.containsKey(key)) {
        final details = await _database.getContentDetails(item.id, playlistId);
        if (details != null) {
          _detailsCache[key] = details;
        }
      }
    }
  }

  /// Get cached details for an item
  ContentDetailsData? getDetails(String contentId, String playlistId) {
    return _detailsCache['${contentId}_$playlistId'];
  }

  /// Apply filter and sort to content items
  /// Returns filtered and sorted list
  Future<List<ContentItem>> applyFilter(
    List<ContentItem> items,
    ContentFilter filter,
    String playlistId,
  ) async {
    // Preload details if cache is empty
    if (_detailsCache.isEmpty) {
      await preloadDetails(items, playlistId);
    }

    // Filter items
    var filtered = items.where((item) {
      final details = _detailsCache['${item.id}_$playlistId'];

      // If no details, only show if no filters are active
      if (details == null) {
        return !filter.hasActiveFilters;
      }

      // Rating filter
      if (filter.minRating != null) {
        if (details.voteAverage == null || details.voteAverage! < filter.minRating!) {
          return false;
        }
      }
      if (filter.maxRating != null) {
        if (details.voteAverage == null || details.voteAverage! > filter.maxRating!) {
          return false;
        }
      }

      // Year filter
      if (filter.minYear != null || filter.maxYear != null) {
        final year = _extractYear(details.releaseDate);
        if (year == null) return false;
        if (filter.minYear != null && year < filter.minYear!) return false;
        if (filter.maxYear != null && year > filter.maxYear!) return false;
      }

      // Genre filter
      if (filter.genres.isNotEmpty) {
        final genres = _parseJsonList(details.genres);
        if (!filter.genres.any((g) => genres.contains(g))) {
          return false;
        }
      }

      // Revenue filter
      if (filter.minRevenue != null) {
        if (details.revenue == null || details.revenue! < filter.minRevenue!) {
          return false;
        }
      }
      if (filter.maxRevenue != null) {
        if (details.revenue == null || details.revenue! > filter.maxRevenue!) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort items
    filtered.sort((a, b) {
      final detailsA = _detailsCache['${a.id}_$playlistId'];
      final detailsB = _detailsCache['${b.id}_$playlistId'];

      int comparison;
      switch (filter.sortBy) {
        case ContentSortOption.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;

        case ContentSortOption.rating:
          final ratingA = detailsA?.voteAverage ?? 0;
          final ratingB = detailsB?.voteAverage ?? 0;
          comparison = ratingA.compareTo(ratingB);
          break;

        case ContentSortOption.year:
          final yearA = _extractYear(detailsA?.releaseDate) ?? 0;
          final yearB = _extractYear(detailsB?.releaseDate) ?? 0;
          comparison = yearA.compareTo(yearB);
          break;

        case ContentSortOption.revenue:
          final revA = detailsA?.revenue ?? 0;
          final revB = detailsB?.revenue ?? 0;
          comparison = revA.compareTo(revB);
          break;

        case ContentSortOption.dateAdded:
          // Only VOD streams have createdAt, for series we use a default date
          final dateA = a.vodStream?.createdAt ?? DateTime(1970);
          final dateB = b.vodStream?.createdAt ?? DateTime(1970);
          comparison = dateA.compareTo(dateB);
          break;
      }

      return filter.sortDescending ? -comparison : comparison;
    });

    return filtered;
  }

  /// Extract all unique genres from a list of content items
  Future<Set<String>> extractGenres(List<ContentItem> items, String playlistId) async {
    await preloadDetails(items, playlistId);

    final genres = <String>{};
    for (final item in items) {
      final details = _detailsCache['${item.id}_$playlistId'];
      if (details?.genres != null) {
        genres.addAll(_parseJsonList(details!.genres));
      }
    }
    return genres;
  }

  /// Parse JSON list string to List<String>
  List<String> _parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Extract year from release date string (YYYY-MM-DD)
  int? _extractYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return null;
    final parts = releaseDate.split('-');
    if (parts.isEmpty) return null;
    return int.tryParse(parts.first);
  }

  /// Clear the cache
  void clearCache() {
    _detailsCache.clear();
  }
}
