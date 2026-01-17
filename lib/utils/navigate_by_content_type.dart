import 'package:another_iptv_player/screens/m3u/series/m3u_series_screen.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import '../screens/live_stream/live_stream_screen.dart';
import '../screens/m3u/m3u_player_screen.dart';
import '../screens/movies/movie_screen.dart';
import '../screens/series/series_screen.dart';

void navigateByContentType(BuildContext context, ContentItem content) {
  // Determine if this is M3U or Xtream content
  // In combined mode, use sourceType; otherwise fall back to current playlist
  final bool contentIsM3u;
  final bool contentIsXtream;

  if (content.sourceType != null) {
    // Combined mode - use the content's source type
    contentIsM3u = content.sourceType == PlaylistType.m3u;
    contentIsXtream = content.sourceType == PlaylistType.xtream;
  } else if (AppState.currentPlaylist != null) {
    // Single playlist mode - use current playlist type
    contentIsM3u = AppState.currentPlaylist!.type == PlaylistType.m3u;
    contentIsXtream = AppState.currentPlaylist!.type == PlaylistType.xtream;
  } else {
    // Fallback - check if content has m3uItem
    contentIsM3u = content.m3uItem != null;
    contentIsXtream = !contentIsM3u;
  }

  if (contentIsM3u &&
      ((content.m3uItem != null && content.m3uItem!.groupTitle == null) ||
          content.contentType == ContentType.series)) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => M3uPlayerScreen(
          contentItem: ContentItem(
            content.m3uItem!.id,
            content.m3uItem!.name ?? '',
            content.m3uItem!.tvgLogo ?? '',
            content.m3uItem!.contentType,
            m3uItem: content.m3uItem!,
          ),
        ),
      ),
    );

    return;
  }

  switch (content.contentType) {
    case ContentType.liveStream:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveStreamScreen(content: content),
        ),
      );
    case ContentType.vod:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieScreen(contentItem: content),
        ),
      );
    case ContentType.series:
      if (contentIsXtream) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SeriesScreen(contentItem: content),
          ),
        );
      } else if (contentIsM3u) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => M3uSeriesScreen(contentItem: content),
          ),
        );
      }
  }
}
