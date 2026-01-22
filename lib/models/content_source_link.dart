import 'package:another_iptv_player/models/live_stream.dart';
import 'package:another_iptv_player/models/m3u_item.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/series.dart';
import 'package:another_iptv_player/models/vod_streams.dart';

/// Quality levels for content, ordered from highest to lowest
enum ContentQuality {
  uhd4k,     // 4K, UHD, 2160p
  hd1080p,   // 1080p, FHD, Full HD
  hd720p,    // 720p, HD
  sd,        // SD, 480p, 360p, or unknown
  unknown;   // Unable to determine quality

  /// Returns a numeric score for ranking (higher is better)
  int get score {
    switch (this) {
      case ContentQuality.uhd4k:
        return 40;
      case ContentQuality.hd1080p:
        return 30;
      case ContentQuality.hd720p:
        return 20;
      case ContentQuality.sd:
        return 10;
      case ContentQuality.unknown:
        return 5;
    }
  }

  /// Human-readable label for UI display
  String get label {
    switch (this) {
      case ContentQuality.uhd4k:
        return '4K';
      case ContentQuality.hd1080p:
        return '1080p';
      case ContentQuality.hd720p:
        return '720p';
      case ContentQuality.sd:
        return 'SD';
      case ContentQuality.unknown:
        return '';
    }
  }
}

/// Represents a single source link for content from a specific playlist
class ContentSourceLink {
  final String url;
  final String sourcePlaylistId;
  final PlaylistType sourceType;
  final String sourceName;
  final ContentQuality quality;
  final String? language;
  final String? containerExtension;

  // Original content references - only one should be non-null
  final VodStream? vodStream;
  final SeriesStream? seriesStream;
  final LiveStream? liveStream;
  final M3uItem? m3uItem;

  // Original item ID from source (for navigation/playback)
  final String originalId;

  // Original name before normalization (for display if needed)
  final String originalName;

  ContentSourceLink({
    required this.url,
    required this.sourcePlaylistId,
    required this.sourceType,
    required this.sourceName,
    required this.quality,
    required this.originalId,
    required this.originalName,
    this.language,
    this.containerExtension,
    this.vodStream,
    this.seriesStream,
    this.liveStream,
    this.m3uItem,
  });

  /// Calculate a score for this source based on quality, language match, and source type
  int calculateScore({String? preferredLanguage}) {
    int score = 0;

    // Quality score (10-40 points)
    score += quality.score;

    // Language match bonus (50 points if matches preferred)
    if (preferredLanguage != null &&
        language != null &&
        language!.toLowerCase() == preferredLanguage.toLowerCase()) {
      score += 50;
    }

    // Source type bonus (Xtream slightly preferred for richer metadata)
    if (sourceType == PlaylistType.xtream) {
      score += 5;
    }

    return score;
  }

  /// Create a brief description for UI display
  String get displayDescription {
    final parts = <String>[];

    if (quality != ContentQuality.unknown) {
      parts.add(quality.label);
    }

    if (language != null && language!.isNotEmpty) {
      parts.add(language!.toUpperCase());
    }

    if (containerExtension != null && containerExtension!.isNotEmpty) {
      parts.add(containerExtension!.toUpperCase());
    }

    return parts.join(' | ');
  }

  @override
  String toString() {
    return 'ContentSourceLink(source: $sourceName, quality: ${quality.label}, language: $language)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentSourceLink &&
        other.url == url &&
        other.sourcePlaylistId == sourcePlaylistId;
  }

  @override
  int get hashCode => url.hashCode ^ sourcePlaylistId.hashCode;
}
