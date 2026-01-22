import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/consolidated_content_item.dart';
import 'package:another_iptv_player/models/content_source_link.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/content_normalization_service.dart';
import 'package:another_iptv_player/utils/build_media_url.dart';

/// Service for consolidating duplicate content items from multiple IPTV sources
/// into single entries with multiple source links.
class ContentConsolidationService {
  // Singleton instance
  static final ContentConsolidationService _instance =
      ContentConsolidationService._internal();
  factory ContentConsolidationService() => _instance;
  ContentConsolidationService._internal();

  final _normalizationService = ContentNormalizationService();

  /// Consolidate a list of content items into consolidated items.
  /// Items with the same normalized name are merged into a single entry.
  List<ConsolidatedContentItem> consolidate(List<ContentItem> items) {
    if (items.isEmpty) return [];

    // Group items by normalized name
    final groups = <String, List<ContentItem>>{};

    for (final item in items) {
      final normalizedName = _normalizationService.normalizeForMatching(item.name);
      if (normalizedName.isEmpty) continue;

      groups.putIfAbsent(normalizedName, () => []).add(item);
    }

    // Convert each group to a ConsolidatedContentItem
    final consolidated = <ConsolidatedContentItem>[];

    for (final entry in groups.entries) {
      final normalizedName = entry.key;
      final groupItems = entry.value;

      try {
        final consolidatedItem = _createConsolidatedItem(normalizedName, groupItems);
        consolidated.add(consolidatedItem);
      } catch (e) {
        debugPrint('ContentConsolidationService: Error consolidating "$normalizedName": $e');
        // Fall back to creating individual items if consolidation fails
        for (final item in groupItems) {
          consolidated.add(_createSingleItemConsolidation(item));
        }
      }
    }

    return consolidated;
  }

  /// Create a ConsolidatedContentItem from a group of matching items
  ConsolidatedContentItem _createConsolidatedItem(
    String normalizedName,
    List<ContentItem> items,
  ) {
    // Create source links for each item
    final sourceLinks = <ContentSourceLink>[];
    final displayNames = <String>[];
    final imagePaths = <String?>[];

    for (final item in items) {
      final sourceLink = _createSourceLink(item);
      sourceLinks.add(sourceLink);
      displayNames.add(item.name);
      imagePaths.add(item.imagePath);
    }

    // Select best display name and image
    final displayName = _normalizationService.selectBestDisplayName(displayNames);
    final imagePath = _normalizationService.selectBestImagePath(imagePaths);

    // Create unique ID based on normalized name
    final id = 'consolidated_${normalizedName.hashCode.abs()}';

    return ConsolidatedContentItem(
      id: id,
      normalizedName: normalizedName,
      displayName: displayName,
      imagePath: imagePath,
      contentType: items.first.contentType,
      sourceLinks: sourceLinks,
    );
  }

  /// Create a source link from a ContentItem
  ContentSourceLink _createSourceLink(ContentItem item) {
    // Get source name from playlist
    String sourceName = 'Unknown';
    final playlistId = item.sourcePlaylistId;
    if (playlistId != null) {
      final playlist = AppState.activePlaylists[playlistId];
      if (playlist != null) {
        sourceName = playlist.name;
      }
    }

    // Extract quality and language from name
    final quality = _normalizationService.extractQuality(
      item.name,
      containerExtension: item.containerExtension,
    );
    final language = _normalizationService.extractLanguage(item.name);

    // Build URL
    String url;
    if (item.m3uItem != null) {
      url = item.m3uItem!.url;
    } else {
      url = buildMediaUrl(item);
    }

    // Determine source type
    final PlaylistType sourceType;
    final currentPlaylistType = AppState.currentPlaylist?.type;
    if (item.sourceType != null) {
      sourceType = item.sourceType!;
    } else if (currentPlaylistType != null) {
      sourceType = currentPlaylistType;
    } else if (item.m3uItem != null) {
      sourceType = PlaylistType.m3u;
    } else {
      sourceType = PlaylistType.xtream;
    }

    return ContentSourceLink(
      url: url,
      sourcePlaylistId: playlistId ?? 'unknown',
      sourceType: sourceType,
      sourceName: sourceName,
      quality: quality,
      language: language,
      containerExtension: item.containerExtension,
      originalId: item.id,
      originalName: item.name,
      vodStream: item.vodStream,
      seriesStream: item.seriesStream,
      liveStream: item.liveStream,
      m3uItem: item.m3uItem,
    );
  }

  /// Create a single-source consolidated item (for items that don't match others)
  ConsolidatedContentItem _createSingleItemConsolidation(ContentItem item) {
    final normalizedName = _normalizationService.normalizeForMatching(item.name);
    final sourceLink = _createSourceLink(item);

    return ConsolidatedContentItem(
      id: 'single_${item.id.hashCode.abs()}',
      normalizedName: normalizedName,
      displayName: item.name,
      imagePath: item.imagePath,
      contentType: item.contentType,
      sourceLinks: [sourceLink],
    );
  }

  /// Consolidate content items and apply preferences to select best sources.
  List<ConsolidatedContentItem> consolidateWithPreferences(
    List<ContentItem> items, {
    ContentQuality? preferredQuality,
    String? preferredLanguage,
  }) {
    final consolidated = consolidate(items);

    // Apply preferences to select best source for each item
    for (final item in consolidated) {
      if (item.hasMultipleSources) {
        final bestSource = _selectBestSource(
          item.sourceLinks,
          preferredQuality: preferredQuality,
          preferredLanguage: preferredLanguage,
        );
        item.preferredSource = bestSource;
      }
    }

    return consolidated;
  }

  /// Select the best source from a list based on preferences
  ContentSourceLink _selectBestSource(
    List<ContentSourceLink> sources, {
    ContentQuality? preferredQuality,
    String? preferredLanguage,
  }) {
    if (sources.isEmpty) throw ArgumentError('Sources list cannot be empty');
    if (sources.length == 1) return sources.first;

    // Score each source
    final scored = sources.map((source) {
      int score = 0;

      // Language match bonus (highest priority: 50 points)
      if (preferredLanguage != null &&
          source.language != null &&
          source.language!.toLowerCase() == preferredLanguage.toLowerCase()) {
        score += 50;
      }

      // Quality score (10-40 points)
      score += source.quality.score;

      // If preferred quality specified, bonus for matching
      if (preferredQuality != null && source.quality == preferredQuality) {
        score += 15;
      }

      // Slight preference for higher quality when no preference set
      // (already handled by quality.score)

      // Source type preference (Xtream for richer metadata)
      if (source.sourceType == PlaylistType.xtream) {
        score += 5;
      }

      return _ScoredSource(source, score);
    }).toList();

    // Sort by score descending and return best
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.first.source;
  }

  /// Consolidate series episodes by (season, episode) for multi-source series
  List<ConsolidatedContentItem> consolidateEpisodes(
    List<ContentItem> episodes, {
    ContentQuality? preferredQuality,
    String? preferredLanguage,
  }) {
    if (episodes.isEmpty) return [];

    // Group by season and episode number
    final groups = <String, List<ContentItem>>{};

    for (final episode in episodes) {
      // Create key from season and episode (extract from name if not available)
      String key;
      if (episode.season != null && episode.episodeNumber != null) {
        key = 's${episode.season}e${episode.episodeNumber}';
      } else {
        // Try to extract from name
        final match = RegExp(r's(\d+)e(\d+)', caseSensitive: false)
            .firstMatch(episode.name);
        if (match != null) {
          key = 's${match.group(1)}e${match.group(2)}';
        } else {
          // Fall back to normalized name
          key = _normalizationService.normalizeForMatching(episode.name);
        }
      }

      groups.putIfAbsent(key, () => []).add(episode);
    }

    // Consolidate each group
    final consolidated = <ConsolidatedContentItem>[];
    for (final entry in groups.entries) {
      if (entry.value.length == 1) {
        consolidated.add(_createSingleItemConsolidation(entry.value.first));
      } else {
        final item = _createConsolidatedItem(entry.key, entry.value);
        // Apply preferences
        if (item.hasMultipleSources) {
          item.preferredSource = _selectBestSource(
            item.sourceLinks,
            preferredQuality: preferredQuality,
            preferredLanguage: preferredLanguage,
          );
        }
        consolidated.add(item);
      }
    }

    return consolidated;
  }

  /// Get statistics about consolidation results
  ConsolidationStats getConsolidationStats(List<ConsolidatedContentItem> items) {
    int totalOriginalItems = 0;
    int itemsWithMultipleSources = 0;
    int maxSourcesPerItem = 0;
    final qualityDistribution = <ContentQuality, int>{};

    for (final item in items) {
      totalOriginalItems += item.sourceCount;

      if (item.hasMultipleSources) {
        itemsWithMultipleSources++;
      }

      if (item.sourceCount > maxSourcesPerItem) {
        maxSourcesPerItem = item.sourceCount;
      }

      final quality = item.highestQuality;
      qualityDistribution[quality] = (qualityDistribution[quality] ?? 0) + 1;
    }

    return ConsolidationStats(
      consolidatedCount: items.length,
      originalCount: totalOriginalItems,
      itemsWithMultipleSources: itemsWithMultipleSources,
      maxSourcesPerItem: maxSourcesPerItem,
      qualityDistribution: qualityDistribution,
    );
  }
}

class _ScoredSource {
  final ContentSourceLink source;
  final int score;

  _ScoredSource(this.source, this.score);
}

/// Statistics about consolidation results
class ConsolidationStats {
  final int consolidatedCount;
  final int originalCount;
  final int itemsWithMultipleSources;
  final int maxSourcesPerItem;
  final Map<ContentQuality, int> qualityDistribution;

  ConsolidationStats({
    required this.consolidatedCount,
    required this.originalCount,
    required this.itemsWithMultipleSources,
    required this.maxSourcesPerItem,
    required this.qualityDistribution,
  });

  /// How many items were deduplicated
  int get deduplicatedCount => originalCount - consolidatedCount;

  /// Percentage of items that had duplicates
  double get deduplicationRate =>
      originalCount > 0 ? deduplicatedCount / originalCount * 100 : 0;

  @override
  String toString() {
    return 'ConsolidationStats(consolidated: $consolidatedCount from $originalCount, '
        'deduped: $deduplicatedCount (${deduplicationRate.toStringAsFixed(1)}%), '
        'multi-source: $itemsWithMultipleSources, maxSources: $maxSourcesPerItem)';
  }
}
