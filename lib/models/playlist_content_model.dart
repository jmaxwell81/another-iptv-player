import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/live_stream.dart';
import 'package:another_iptv_player/models/m3u_item.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/series.dart';
import 'package:another_iptv_player/models/vod_streams.dart';
import 'package:another_iptv_player/utils/build_media_url.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';

class ContentItem {
  final String id;
  late String url;
  final String name;
  final String imagePath;
  final String? description;
  final Duration? duration;
  final String? coverPath;
  final String? containerExtension;
  final ContentType contentType;
  final LiveStream? liveStream;
  final VodStream? vodStream;
  final SeriesStream? seriesStream;
  final int? season;
  final int? episodeNumber;
  final int? totalEpisodes;
  final M3uItem? m3uItem;

  // Source tracking for multi-playlist support
  final String? sourcePlaylistId;
  final PlaylistType? sourceType;

  // Catch up support
  final bool isCatchUp;

  ContentItem(
    this.id,
    this.name,
    this.imagePath,
    this.contentType, {
    this.description,
    this.duration,
    this.coverPath,
    this.containerExtension,
    this.liveStream,
    this.vodStream,
    this.seriesStream,
    this.season,
    this.episodeNumber,
    this.totalEpisodes,
    this.m3uItem,
    this.sourcePlaylistId,
    this.sourceType,
    this.isCatchUp = false,
    String? overrideUrl,
  }) {
    // If override URL is provided, use it directly (for catch up content)
    if (overrideUrl != null && overrideUrl.isNotEmpty) {
      url = overrideUrl;
      return;
    }

    // Determine if this is Xtream content:
    // 1. If sourceType is set, use that
    // 2. Otherwise, check if we have Xtream-specific stream objects
    // 3. Fall back to global check only if no other info available
    bool isXtream;
    if (sourceType != null) {
      isXtream = sourceType == PlaylistType.xtream;
    } else if (liveStream != null || vodStream != null || seriesStream != null) {
      // Has Xtream-specific stream objects - must be Xtream content
      isXtream = true;
    } else if (m3uItem != null) {
      // Has M3U item - must be M3U content
      isXtream = false;
    } else {
      // Fall back to global check
      isXtream = isXtreamCode;
    }
    url = isXtream ? buildMediaUrl(this) : m3uItem?.url ?? id;
  }
}
