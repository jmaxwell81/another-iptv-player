import 'package:another_iptv_player/models/content_source_link.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';

/// Represents content that has been consolidated from multiple sources.
/// Contains all available source links and tracks the currently preferred source.
class ConsolidatedContentItem {
  /// Unique identifier for this consolidated item (based on normalized name)
  final String id;

  /// Normalized name used for matching duplicates
  final String normalizedName;

  /// Best display name chosen from all sources
  final String displayName;

  /// Best image path chosen from all sources
  final String imagePath;

  /// Content type (live, vod, series)
  final ContentType contentType;

  /// All available source links for this content
  final List<ContentSourceLink> sourceLinks;

  /// Currently selected/preferred source for playback
  ContentSourceLink? preferredSource;

  ConsolidatedContentItem({
    required this.id,
    required this.normalizedName,
    required this.displayName,
    required this.imagePath,
    required this.contentType,
    required this.sourceLinks,
    this.preferredSource,
  }) {
    // Default to first source if no preferred source set
    if (preferredSource == null && sourceLinks.isNotEmpty) {
      preferredSource = sourceLinks.first;
    }
  }

  /// Whether this item has multiple sources available
  bool get hasMultipleSources => sourceLinks.length > 1;

  /// Number of available sources
  int get sourceCount => sourceLinks.length;

  /// Get sources sorted by quality (highest first)
  List<ContentSourceLink> get sourcesByQuality {
    final sorted = List<ContentSourceLink>.from(sourceLinks);
    sorted.sort((a, b) => b.quality.score.compareTo(a.quality.score));
    return sorted;
  }

  /// Get the highest quality available
  ContentQuality get highestQuality {
    if (sourceLinks.isEmpty) return ContentQuality.unknown;
    return sourcesByQuality.first.quality;
  }

  /// Get unique languages available across all sources
  Set<String> get availableLanguages {
    return sourceLinks
        .where((link) => link.language != null && link.language!.isNotEmpty)
        .map((link) => link.language!)
        .toSet();
  }

  /// Get unique source names for display
  List<String> get sourceNames {
    return sourceLinks.map((link) => link.sourceName).toSet().toList();
  }

  /// Convert to a standard ContentItem using the preferred source
  ContentItem toContentItem() {
    final source = preferredSource ?? sourceLinks.first;

    return ContentItem(
      source.originalId,
      displayName,
      imagePath,
      contentType,
      vodStream: source.vodStream,
      seriesStream: source.seriesStream,
      liveStream: source.liveStream,
      m3uItem: source.m3uItem,
      containerExtension: source.containerExtension,
      sourcePlaylistId: source.sourcePlaylistId,
      sourceType: source.sourceType,
    );
  }

  /// Create a ContentItem for a specific source link
  ContentItem toContentItemWithSource(ContentSourceLink source) {
    return ContentItem(
      source.originalId,
      displayName,
      imagePath,
      contentType,
      vodStream: source.vodStream,
      seriesStream: source.seriesStream,
      liveStream: source.liveStream,
      m3uItem: source.m3uItem,
      containerExtension: source.containerExtension,
      sourcePlaylistId: source.sourcePlaylistId,
      sourceType: source.sourceType,
    );
  }

  /// Select a different source as preferred
  void selectSource(ContentSourceLink source) {
    if (sourceLinks.contains(source)) {
      preferredSource = source;
    }
  }

  /// Select source by playlist ID
  void selectSourceByPlaylistId(String playlistId) {
    final source = sourceLinks.firstWhere(
      (link) => link.sourcePlaylistId == playlistId,
      orElse: () => sourceLinks.first,
    );
    preferredSource = source;
  }

  /// Create a copy with updated preferred source
  ConsolidatedContentItem copyWith({
    String? id,
    String? normalizedName,
    String? displayName,
    String? imagePath,
    ContentType? contentType,
    List<ContentSourceLink>? sourceLinks,
    ContentSourceLink? preferredSource,
  }) {
    return ConsolidatedContentItem(
      id: id ?? this.id,
      normalizedName: normalizedName ?? this.normalizedName,
      displayName: displayName ?? this.displayName,
      imagePath: imagePath ?? this.imagePath,
      contentType: contentType ?? this.contentType,
      sourceLinks: sourceLinks ?? this.sourceLinks,
      preferredSource: preferredSource ?? this.preferredSource,
    );
  }

  @override
  String toString() {
    return 'ConsolidatedContentItem(name: $displayName, sources: ${sourceLinks.length}, quality: ${highestQuality.label})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsolidatedContentItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
