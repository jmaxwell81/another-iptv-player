import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/service_locator.dart';

/// Result from global search with content type grouping
class GlobalSearchResult {
  final List<ContentItem> liveStreams;
  final List<ContentItem> movies;
  final List<ContentItem> series;

  GlobalSearchResult({
    this.liveStreams = const [],
    this.movies = const [],
    this.series = const [],
  });

  bool get isEmpty => liveStreams.isEmpty && movies.isEmpty && series.isEmpty;
  int get totalCount => liveStreams.length + movies.length + series.length;
}

/// Controller for global search across all content types and playlists
class GlobalSearchController extends ChangeNotifier {
  final AppDatabase _database = getIt<AppDatabase>();

  bool _isSearching = false;
  String _query = '';
  GlobalSearchResult _results = GlobalSearchResult();
  String? _errorMessage;

  bool get isSearching => _isSearching;
  String get query => _query;
  GlobalSearchResult get results => _results;
  String? get errorMessage => _errorMessage;

  /// Search across all content types
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _results = GlobalSearchResult();
      _query = '';
      notifyListeners();
      return;
    }

    _isSearching = true;
    _query = query;
    _errorMessage = null;
    notifyListeners();

    try {
      final liveStreams = <ContentItem>[];
      final movies = <ContentItem>[];
      final series = <ContentItem>[];

      // Search in combined mode - search all active playlists
      if (AppState.isCombinedMode) {
        for (final entry in AppState.activePlaylists.entries) {
          final playlistId = entry.key;
          final playlist = entry.value;

          if (playlist.type == PlaylistType.xtream) {
            await _searchXtreamPlaylist(playlistId, query, liveStreams, movies, series);
          } else if (playlist.type == PlaylistType.m3u) {
            await _searchM3uPlaylist(playlistId, query, liveStreams, movies, series);
          }
        }
      } else if (AppState.currentPlaylist != null) {
        // Single playlist mode
        final playlist = AppState.currentPlaylist!;
        final playlistId = playlist.id;

        if (playlist.type == PlaylistType.xtream) {
          await _searchXtreamPlaylist(playlistId, query, liveStreams, movies, series);
        } else if (playlist.type == PlaylistType.m3u) {
          await _searchM3uPlaylist(playlistId, query, liveStreams, movies, series);
        }
      }

      _results = GlobalSearchResult(
        liveStreams: liveStreams,
        movies: movies,
        series: series,
      );
    } catch (e) {
      _errorMessage = 'Search failed: $e';
      debugPrint('GlobalSearchController: Error searching: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> _searchXtreamPlaylist(
    String playlistId,
    String query,
    List<ContentItem> liveStreams,
    List<ContentItem> movies,
    List<ContentItem> series,
  ) async {
    final queryLower = query.toLowerCase();

    // Search live streams
    final liveResults = await _database.searchLiveStreams(playlistId, queryLower);
    for (final stream in liveResults) {
      liveStreams.add(ContentItem(
        stream.streamId,
        stream.name,
        stream.streamIcon ?? '',
        ContentType.liveStream,
        liveStream: stream,
        sourcePlaylistId: playlistId,
        sourceType: PlaylistType.xtream,
      ));
    }

    // Search movies (VOD)
    final movieResults = await _database.searchMovie(playlistId, queryLower);
    for (final movie in movieResults) {
      movies.add(ContentItem(
        movie.streamId,
        movie.name,
        movie.streamIcon ?? '',
        ContentType.vod,
        containerExtension: movie.containerExtension,
        vodStream: movie,
        sourcePlaylistId: playlistId,
        sourceType: PlaylistType.xtream,
      ));
    }

    // Search series
    final seriesResults = await _database.searchSeries(playlistId, queryLower);
    for (final s in seriesResults) {
      series.add(ContentItem(
        s.seriesId,
        s.name,
        s.cover ?? '',
        ContentType.series,
        seriesStream: s,
        sourcePlaylistId: playlistId,
        sourceType: PlaylistType.xtream,
      ));
    }
  }

  Future<void> _searchM3uPlaylist(
    String playlistId,
    String query,
    List<ContentItem> liveStreams,
    List<ContentItem> movies,
    List<ContentItem> series,
  ) async {
    final queryLower = query.toLowerCase();

    // Search M3U items
    final m3uResults = await _database.searchM3uItems(playlistId, queryLower);
    for (final item in m3uResults) {
      final contentItem = ContentItem(
        item.url,
        item.name ?? '',
        item.tvgLogo ?? '',
        item.contentType,
        m3uItem: item,
        sourcePlaylistId: playlistId,
        sourceType: PlaylistType.m3u,
      );

      switch (item.contentType) {
        case ContentType.liveStream:
          liveStreams.add(contentItem);
          break;
        case ContentType.vod:
          movies.add(contentItem);
          break;
        case ContentType.series:
          series.add(contentItem);
          break;
      }
    }
  }

  void clearResults() {
    _results = GlobalSearchResult();
    _query = '';
    _errorMessage = null;
    notifyListeners();
  }
}
