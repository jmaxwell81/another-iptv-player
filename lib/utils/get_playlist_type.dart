import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';

PlaylistType getPlaylistType() {
  if (AppState.currentPlaylist != null) {
    return AppState.currentPlaylist!.type;
  }
  // In combined mode, return a default (callers should use getPlaylistTypeById instead)
  return PlaylistType.xtream;
}

bool get isXtreamCode {
  if (AppState.currentPlaylist == null) {
    return false;
  }
  return getPlaylistType() == PlaylistType.xtream;
}

bool get isM3u {
  if (AppState.currentPlaylist == null) {
    return false;
  }
  return getPlaylistType() == PlaylistType.m3u;
}

/// Get playlist type by playlist ID - useful in combined mode
PlaylistType? getPlaylistTypeById(String playlistId) {
  // Check xtream repositories
  if (AppState.xtreamRepositories.containsKey(playlistId)) {
    return PlaylistType.xtream;
  }
  // Check m3u repositories
  if (AppState.m3uRepositories.containsKey(playlistId)) {
    return PlaylistType.m3u;
  }
  // Check active playlists
  final playlist = AppState.activePlaylists[playlistId];
  if (playlist != null) {
    return playlist.type;
  }
  // Fallback to current playlist if matching
  if (AppState.currentPlaylist?.id == playlistId) {
    return AppState.currentPlaylist!.type;
  }
  return null;
}

/// Check if a specific playlist is Xtream type
bool isXtreamCodeById(String playlistId) {
  return getPlaylistTypeById(playlistId) == PlaylistType.xtream;
}

/// Check if a specific playlist is M3U type
bool isM3uById(String playlistId) {
  return getPlaylistTypeById(playlistId) == PlaylistType.m3u;
}
