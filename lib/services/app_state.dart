import 'package:another_iptv_player/models/m3u_item.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';

abstract class AppState {
  // Single playlist mode (backward compatible)
  static Playlist? currentPlaylist;
  static IptvRepository? xtreamCodeRepository;
  static M3uRepository? m3uRepository;
  static List<M3uItem>? m3uItems;

  // Multi-playlist support for combined mode
  static Map<String, Playlist> activePlaylists = {};
  static Map<String, IptvRepository> xtreamRepositories = {};
  static Map<String, M3uRepository> m3uRepositories = {};
  static bool isCombinedMode = false;

  /// Get a playlist by ID (checks both active playlists and current playlist)
  static Playlist? getPlaylist(String id) {
    if (activePlaylists.containsKey(id)) {
      return activePlaylists[id];
    }
    if (currentPlaylist?.id == id) {
      return currentPlaylist;
    }
    return null;
  }

  /// Get Xtream repository for a specific playlist
  static IptvRepository? getXtreamRepository(String playlistId) {
    return xtreamRepositories[playlistId] ??
           (currentPlaylist?.id == playlistId ? xtreamCodeRepository : null);
  }

  /// Get M3U repository for a specific playlist
  static M3uRepository? getM3uRepository(String playlistId) {
    return m3uRepositories[playlistId] ??
           (currentPlaylist?.id == playlistId ? m3uRepository : null);
  }

  /// Register a playlist and its repository for combined mode
  static void registerPlaylist(Playlist playlist, {IptvRepository? xtreamRepo, M3uRepository? m3uRepo}) {
    activePlaylists[playlist.id] = playlist;
    if (xtreamRepo != null) {
      xtreamRepositories[playlist.id] = xtreamRepo;
    }
    if (m3uRepo != null) {
      m3uRepositories[playlist.id] = m3uRepo;
    }
  }

  /// Unregister a playlist from combined mode
  static void unregisterPlaylist(String playlistId) {
    activePlaylists.remove(playlistId);
    xtreamRepositories.remove(playlistId);
    m3uRepositories.remove(playlistId);
  }

  /// Clear all active playlists (when exiting combined mode)
  static void clearActivePlaylists() {
    activePlaylists.clear();
    xtreamRepositories.clear();
    m3uRepositories.clear();
    isCombinedMode = false;
  }
}
