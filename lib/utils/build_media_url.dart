import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';

import '../models/content_type.dart';
import '../models/playlist_content_model.dart';

/// Build media URL using the current playlist (legacy behavior)
String buildMediaUrl(ContentItem contentItem) {
  // Try to get playlist from source ID first (for combined mode)
  Playlist? playlist;
  if (contentItem.sourcePlaylistId != null) {
    playlist = AppState.getPlaylist(contentItem.sourcePlaylistId!);
  }
  // Fall back to current playlist
  playlist ??= AppState.currentPlaylist;

  if (playlist == null) {
    // Return an error URL that will fail gracefully
    print('buildMediaUrl: No playlist available for sourcePlaylistId=${contentItem.sourcePlaylistId}');
    return 'error://no-playlist-found/${contentItem.id}';
  }

  // Validate playlist has required credentials
  if (playlist.url == null || playlist.username == null || playlist.password == null) {
    print('buildMediaUrl: Playlist ${playlist.id} missing credentials');
    return 'error://missing-credentials/${contentItem.id}';
  }

  return buildMediaUrlForPlaylist(contentItem, playlist);
}

/// Build media URL using a specific playlist
String buildMediaUrlForPlaylist(ContentItem contentItem, Playlist playlist) {
  switch (contentItem.contentType) {
    case ContentType.liveStream:
      return '${playlist.url}/${playlist.username}/${playlist.password}/${contentItem.id}';
    case ContentType.vod:
      return '${playlist.url}/movie/${playlist.username}/${playlist.password}/${contentItem.id}.${contentItem.containerExtension}';
    case ContentType.series:
      return '${playlist.url}/series/${playlist.username}/${playlist.password}/${contentItem.id}.${contentItem.containerExtension}';
  }
}
