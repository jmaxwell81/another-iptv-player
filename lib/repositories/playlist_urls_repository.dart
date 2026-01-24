import '../database/database.dart';
import '../models/playlist_model.dart';
import '../models/playlist_url.dart';
import '../services/url_failover_service.dart';
import '../services/service_locator.dart';

/// Repository for managing playlist URLs with health status tracking
class PlaylistUrlsRepository {
  final AppDatabase _db = getIt<AppDatabase>();
  final UrlFailoverService _failoverService = UrlFailoverService();

  /// Get all URLs for a playlist
  Future<List<PlaylistUrl>> getUrls(String playlistId) async {
    return await _db.getPlaylistUrls(playlistId);
  }

  /// Get a single URL by ID
  Future<PlaylistUrl?> getUrl(String id) async {
    return await _db.getPlaylistUrl(id);
  }

  /// Save a playlist URL (insert or update)
  Future<void> saveUrl(PlaylistUrl url) async {
    await _db.upsertPlaylistUrl(url);
  }

  /// Save multiple URLs for a playlist
  Future<void> saveUrls(List<PlaylistUrl> urls) async {
    for (final url in urls) {
      await _db.upsertPlaylistUrl(url);
    }
  }

  /// Delete a URL
  Future<void> deleteUrl(String id) async {
    await _db.deletePlaylistUrl(id);
    _failoverService.clearCacheForUrl(id);
  }

  /// Delete all URLs for a playlist
  Future<void> deleteUrlsForPlaylist(String playlistId) async {
    final urls = await getUrls(playlistId);
    for (final url in urls) {
      _failoverService.clearCacheForUrl(url.url);
    }
    await _db.deletePlaylistUrlsByPlaylist(playlistId);
  }

  /// Sync URLs from a Playlist model to the database
  /// This ensures the PlaylistUrls table matches the Playlist.allUrls
  Future<void> syncFromPlaylist(Playlist playlist) async {
    final allUrls = playlist.allUrls;
    final existingUrls = await getUrls(playlist.id);

    // Create a map of existing URLs by their URL string
    final existingByUrl = {for (final u in existingUrls) u.url: u};

    // Create/update URLs
    for (var i = 0; i < allUrls.length; i++) {
      final url = allUrls[i];
      final id = '${playlist.id}_$i';

      final existing = existingByUrl[url];
      if (existing != null) {
        // Update priority if changed
        if (existing.priority != i) {
          await saveUrl(existing.copyWith(priority: i, id: id));
        }
      } else {
        // Create new URL entry
        await saveUrl(PlaylistUrl(
          id: id,
          playlistId: playlist.id,
          url: url,
          priority: i,
        ));
      }
    }

    // Remove URLs that are no longer in the playlist
    for (final existing in existingUrls) {
      if (!allUrls.contains(existing.url)) {
        await deleteUrl(existing.id);
      }
    }
  }

  /// Check health of all URLs for a playlist
  Future<List<PlaylistUrl>> checkAllUrlsHealth(Playlist playlist) async {
    final results = await _failoverService.checkAllUrls(playlist);

    // Save the updated status to database
    for (final result in results) {
      await _db.upsertPlaylistUrl(result);
    }

    return results;
  }

  /// Check health of a single URL
  Future<PlaylistUrl> checkUrlHealth(PlaylistUrl url, Playlist playlist) async {
    final result = await _failoverService.checkUrlHealth(
      url.url,
      username: playlist.username,
      password: playlist.password,
      type: playlist.type,
      useCache: false,
    );

    final updated = url.copyWith(
      status: result.status,
      lastChecked: DateTime.now(),
      responseTimeMs: result.responseTimeMs,
      lastError: result.error,
      lastSuccessful: result.isHealthy ? DateTime.now() : url.lastSuccessful,
      failureCount: result.isHealthy ? 0 : url.failureCount + 1,
    );

    await saveUrl(updated);
    return updated;
  }

  /// Get the best working URL for a playlist
  /// Returns null if all URLs are offline
  Future<PlaylistUrl?> getWorkingUrl(Playlist playlist, {bool forceCheck = false}) async {
    final result = await _failoverService.getWorkingUrl(
      playlist,
      forceCheck: forceCheck,
    );

    if (result.success && result.workingUrl != null) {
      // Update the working URL in database
      await saveUrl(result.workingUrl!);
      return result.workingUrl;
    }

    // Update all tried URLs with their status
    for (final triedUrl in result.triedUrls) {
      await saveUrl(triedUrl);
    }

    return null;
  }

  /// Update URL status after a successful or failed operation
  Future<void> updateUrlStatus(
    String id, {
    required UrlStatus status,
    int? responseTimeMs,
    String? error,
  }) async {
    await _db.updatePlaylistUrlStatus(
      id,
      status: status,
      responseTimeMs: responseTimeMs,
      lastError: error,
    );
  }

  /// Increment failure count for a URL
  Future<void> incrementFailureCount(String id) async {
    await _db.incrementPlaylistUrlFailureCount(id);
  }

  /// Get online URLs for a playlist
  Future<List<PlaylistUrl>> getOnlineUrls(String playlistId) async {
    final urls = await getUrls(playlistId);
    return urls.where((u) => u.status == UrlStatus.online).toList();
  }

  /// Get offline or failed URLs for a playlist
  Future<List<PlaylistUrl>> getOfflineUrls(String playlistId) async {
    final urls = await getUrls(playlistId);
    return urls.where((u) =>
      u.status == UrlStatus.offline ||
      u.status == UrlStatus.timeout ||
      u.status == UrlStatus.error
    ).toList();
  }

  /// Check if a playlist has any working URLs (based on cached status)
  Future<bool> hasWorkingUrl(String playlistId) async {
    final urls = await getUrls(playlistId);
    return urls.any((u) => u.isHealthy);
  }

  /// Get the URL with the best response time
  Future<PlaylistUrl?> getFastestUrl(String playlistId) async {
    final urls = await getOnlineUrls(playlistId);
    if (urls.isEmpty) return null;

    urls.sort((a, b) => a.responseTimeMs.compareTo(b.responseTimeMs));
    return urls.first;
  }

  /// Clear all health cache
  void clearCache() {
    _failoverService.clearCache();
  }
}
