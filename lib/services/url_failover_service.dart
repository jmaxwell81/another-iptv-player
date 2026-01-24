import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/playlist_url.dart';

/// Service for managing URL health checking and automatic failover
class UrlFailoverService {
  static final UrlFailoverService _instance = UrlFailoverService._internal();
  factory UrlFailoverService() => _instance;
  UrlFailoverService._internal();

  /// Cache of URL health status
  final Map<String, UrlHealthCheckResult> _healthCache = {};

  /// Cache expiration time
  final Duration _cacheExpiration = const Duration(minutes: 5);

  /// Timestamp of when each URL was last checked
  final Map<String, DateTime> _lastChecked = {};

  /// Connection timeout for health checks
  final Duration _connectionTimeout = const Duration(seconds: 10);

  /// Check if a single URL is healthy
  ///
  /// For Xtream Codes, this checks the player_api.php endpoint
  /// For M3U, this checks if the URL returns valid content
  Future<UrlHealthCheckResult> checkUrlHealth(
    String url, {
    String? username,
    String? password,
    PlaylistType type = PlaylistType.xtream,
    bool useCache = true,
  }) async {
    // Check cache first
    if (useCache) {
      final cached = _getCachedResult(url);
      if (cached != null) {
        return cached;
      }
    }

    final stopwatch = Stopwatch()..start();

    try {
      final checkUrl = _buildCheckUrl(url, username, password, type);
      final uri = Uri.parse(checkUrl);

      final response = await http.head(uri).timeout(_connectionTimeout);

      stopwatch.stop();
      final responseTimeMs = stopwatch.elapsedMilliseconds;

      UrlHealthCheckResult result;
      if (response.statusCode >= 200 && response.statusCode < 400) {
        result = UrlHealthCheckResult.online(responseTimeMs);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        result = UrlHealthCheckResult.error(
          response.statusCode,
          'Authentication failed',
        );
      } else {
        result = UrlHealthCheckResult.error(
          response.statusCode,
          'HTTP ${response.statusCode}',
        );
      }

      _cacheResult(url, result);
      return result;
    } on TimeoutException {
      stopwatch.stop();
      final result = UrlHealthCheckResult.timeout();
      _cacheResult(url, result);
      return result;
    } on SocketException catch (e) {
      stopwatch.stop();
      final result = UrlHealthCheckResult.offline(e.message);
      _cacheResult(url, result);
      return result;
    } catch (e) {
      stopwatch.stop();
      final result = UrlHealthCheckResult.offline(e.toString());
      _cacheResult(url, result);
      return result;
    }
  }

  /// Build the URL to check based on playlist type
  String _buildCheckUrl(
    String baseUrl,
    String? username,
    String? password,
    PlaylistType type,
  ) {
    // Normalize base URL
    var url = baseUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (type == PlaylistType.xtream && username != null && password != null) {
      // For Xtream, check the player_api.php endpoint
      return '$url/player_api.php?username=$username&password=$password';
    }

    // For M3U or when no credentials, just check the base URL
    return url;
  }

  /// Get a working URL from a playlist, trying failover if needed
  ///
  /// Returns the first working URL, or null if all URLs fail
  Future<FailoverResult> getWorkingUrl(
    Playlist playlist, {
    bool forceCheck = false,
  }) async {
    final urls = playlist.allUrls;
    if (urls.isEmpty) {
      return FailoverResult.noUrls();
    }

    final triedUrls = <PlaylistUrl>[];

    // Start with the active URL index if set, otherwise start at 0
    final startIndex = playlist.activeUrlIndex ?? 0;

    // Create ordered list starting from active index
    final orderedIndices = <int>[];
    for (var i = 0; i < urls.length; i++) {
      orderedIndices.add((startIndex + i) % urls.length);
    }

    for (final index in orderedIndices) {
      final url = urls[index];

      // Create a PlaylistUrl object for tracking
      var playlistUrl = PlaylistUrl(
        id: '${playlist.id}_$index',
        playlistId: playlist.id,
        url: url,
        priority: index,
      );

      // Check health
      final result = await checkUrlHealth(
        url,
        username: playlist.username,
        password: playlist.password,
        type: playlist.type,
        useCache: !forceCheck,
      );

      playlistUrl = playlistUrl.copyWith(
        status: result.status,
        lastChecked: DateTime.now(),
        responseTimeMs: result.responseTimeMs,
        lastError: result.error,
        lastSuccessful: result.isHealthy ? DateTime.now() : null,
      );

      triedUrls.add(playlistUrl);

      if (result.isHealthy) {
        return FailoverResult.foundWorking(playlistUrl, triedUrls);
      }
    }

    return FailoverResult.allFailed(triedUrls);
  }

  /// Check all URLs for a playlist and return their status
  Future<List<PlaylistUrl>> checkAllUrls(Playlist playlist) async {
    final urls = playlist.allUrls;
    final results = <PlaylistUrl>[];

    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];

      final result = await checkUrlHealth(
        url,
        username: playlist.username,
        password: playlist.password,
        type: playlist.type,
        useCache: false,
      );

      results.add(PlaylistUrl(
        id: '${playlist.id}_$i',
        playlistId: playlist.id,
        url: url,
        priority: i,
        status: result.status,
        lastChecked: DateTime.now(),
        responseTimeMs: result.responseTimeMs,
        lastError: result.error,
        lastSuccessful: result.isHealthy ? DateTime.now() : null,
      ));
    }

    return results;
  }

  /// Try to execute a function with automatic URL failover
  ///
  /// If the function fails with the current URL, it will try the next URL
  /// until one succeeds or all URLs have been tried.
  Future<T?> executeWithFailover<T>(
    Playlist playlist,
    Future<T> Function(String url) operation, {
    void Function(String url, int attempt, Object error)? onFailure,
    void Function(String url, int attempt)? onSuccess,
  }) async {
    final urls = playlist.allUrls;
    if (urls.isEmpty) {
      return null;
    }

    // Start with the active URL index if set
    final startIndex = playlist.activeUrlIndex ?? 0;

    for (var attempt = 0; attempt < urls.length; attempt++) {
      final index = (startIndex + attempt) % urls.length;
      final url = urls[index];

      try {
        final result = await operation(url);
        onSuccess?.call(url, attempt);
        return result;
      } catch (e) {
        onFailure?.call(url, attempt, e);

        // Mark this URL as failed in cache
        _cacheResult(url, UrlHealthCheckResult.offline(e.toString()));

        // Continue to next URL
        continue;
      }
    }

    return null;
  }

  /// Get cached result if not expired
  UrlHealthCheckResult? _getCachedResult(String url) {
    final lastCheck = _lastChecked[url];
    if (lastCheck == null) return null;

    if (DateTime.now().difference(lastCheck) > _cacheExpiration) {
      // Cache expired
      _healthCache.remove(url);
      _lastChecked.remove(url);
      return null;
    }

    return _healthCache[url];
  }

  /// Cache a health check result
  void _cacheResult(String url, UrlHealthCheckResult result) {
    _healthCache[url] = result;
    _lastChecked[url] = DateTime.now();
  }

  /// Clear the cache for a specific URL
  void clearCacheForUrl(String url) {
    _healthCache.remove(url);
    _lastChecked.remove(url);
  }

  /// Clear all cached results
  void clearCache() {
    _healthCache.clear();
    _lastChecked.clear();
  }

  /// Get the cached status for a URL (if available)
  UrlStatus? getCachedStatus(String url) {
    final result = _getCachedResult(url);
    return result?.status;
  }
}

/// Extension methods for Playlist to use failover
extension PlaylistFailoverExtension on Playlist {
  /// Get the effective URL to use, checking health and failing over if needed
  Future<String?> getEffectiveUrl({bool forceCheck = false}) async {
    final service = UrlFailoverService();
    final result = await service.getWorkingUrl(this, forceCheck: forceCheck);
    return result.workingUrl?.url;
  }

  /// Execute an operation with automatic failover
  Future<T?> withFailover<T>(
    Future<T> Function(String url) operation, {
    void Function(String url, int attempt, Object error)? onFailure,
    void Function(String url, int attempt)? onSuccess,
  }) async {
    final service = UrlFailoverService();
    return service.executeWithFailover(
      this,
      operation,
      onFailure: onFailure,
      onSuccess: onSuccess,
    );
  }
}
