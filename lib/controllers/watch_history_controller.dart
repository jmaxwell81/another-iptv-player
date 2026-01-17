import 'package:flutter/material.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import '../screens/m3u/m3u_player_screen.dart';
import '../services/service_locator.dart';
import '../screens/series/episode_screen.dart';

class WatchHistoryController extends ChangeNotifier {
  late WatchHistoryService _historyService;
  final _database = getIt<AppDatabase>();

  List<WatchHistory> _continueWatching = [];
  List<WatchHistory> _recentlyWatched = [];
  List<WatchHistory> _liveHistory = [];
  List<WatchHistory> _movieHistory = [];
  List<WatchHistory> _seriesHistory = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDisposed = false;

  // Getters
  List<WatchHistory> get continueWatching => _continueWatching;

  List<WatchHistory> get recentlyWatched => _recentlyWatched;

  List<WatchHistory> get liveHistory => _liveHistory;

  List<WatchHistory> get movieHistory => _movieHistory;

  List<WatchHistory> get seriesHistory => _seriesHistory;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  WatchHistoryController() {
    _historyService = WatchHistoryService();
  }

  bool get isAllEmpty =>
      _continueWatching.isEmpty &&
      _recentlyWatched.isEmpty &&
      _liveHistory.isEmpty &&
      _movieHistory.isEmpty &&
      _seriesHistory.isEmpty;

  Future<void> loadWatchHistory() async {
    debugPrint('WatchHistoryController: loadWatchHistory başladı');
    _setLoading(true);
    _clearError();

    // Mevcut verileri temizle
    _continueWatching.clear();
    _recentlyWatched.clear();
    _liveHistory.clear();
    _movieHistory.clear();
    _seriesHistory.clear();
    if (!_isDisposed) notifyListeners();

    try {
      // In combined mode, load history from all active playlists
      if (AppState.isCombinedMode) {
        debugPrint('WatchHistoryController: Combined mode - loading from all playlists');
        for (final playlistId in AppState.activePlaylists.keys) {
          final futures = await Future.wait([
            _historyService.getContinueWatching(playlistId),
            _historyService.getRecentlyWatched(limit: 20, playlistId),
            _historyService.getWatchHistoryByContentType(ContentType.liveStream, playlistId),
            _historyService.getWatchHistoryByContentType(ContentType.vod, playlistId),
            _historyService.getWatchHistoryByContentType(ContentType.series, playlistId),
          ]);

          _continueWatching.addAll(futures[0]);
          _recentlyWatched.addAll(futures[1]);
          _liveHistory.addAll(futures[2]);
          _movieHistory.addAll(futures[3]);
          _seriesHistory.addAll(futures[4]);
        }

        // Sort by watchedAt descending
        _continueWatching.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        _recentlyWatched.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        _liveHistory.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        _movieHistory.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        _seriesHistory.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

        _setLoading(false);
        return;
      }

      // Single playlist mode
      if (AppState.currentPlaylist == null) {
        debugPrint('WatchHistoryController: Aktif playlist bulunamadı');
        _setLoading(false);
        return;
      }

      final playlistId = AppState.currentPlaylist!.id;
      debugPrint('WatchHistoryController: Playlist ID: $playlistId');

      final futures = await Future.wait([
        _historyService.getContinueWatching(playlistId),
        _historyService.getRecentlyWatched(limit: 20, playlistId),
        _historyService.getWatchHistoryByContentType(
          ContentType.liveStream,
          playlistId,
        ),
        _historyService.getWatchHistoryByContentType(
          ContentType.vod,
          playlistId,
        ),
        _historyService.getWatchHistoryByContentType(
          ContentType.series,
          playlistId,
        ),
      ]);

      _continueWatching = futures[0];
      _recentlyWatched = futures[1];
      _liveHistory = futures[2];
      _movieHistory = futures[3];
      _seriesHistory = futures[4];

      _setLoading(false);
    } catch (e) {
      _setError('İzleme geçmişi yüklenirken hata oluştu: $e');
      _setLoading(false);
    }
  }

  Future<void> playContent(BuildContext context, WatchHistory history) async {
    try {
      switch (history.contentType) {
        case ContentType.liveStream:
          await _playLiveStream(context, history);
          break;
        case ContentType.vod:
          await _playMovie(context, history);
          break;
        case ContentType.series:
          await _playSeries(context, history);
          break;
      }
    } catch (e) {
      _setError('Video oynatılırken hata oluştu: $e');
    }
  }

  Future<void> removeHistory(WatchHistory history) async {
    try {
      await _historyService.deleteWatchHistory(
        history.playlistId,
        history.streamId,
      );
      await loadWatchHistory();
    } catch (e) {
      _setError('Hata oluştu: $e');
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _historyService.clearAllHistory();
      await loadWatchHistory();
    } catch (e) {
      _setError('Hata oluştu: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Private methods
  void _setLoading(bool loading) {
    if (_isDisposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    if (_isDisposed) return;
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _playLiveStream(
    BuildContext context,
    WatchHistory history,
  ) async {
    final playlistId = history.playlistId;
    final historyIsXtream = isXtreamCodeById(playlistId);
    final historyIsM3u = isM3uById(playlistId);

    if (historyIsXtream) {
      final liveStream = await _database.findLiveStreamById(
        history.streamId,
        playlistId,
      );

      navigateByContentType(
        context,
        ContentItem(
          history.streamId,
          history.title,
          history.imagePath ?? '',
          history.contentType,
          liveStream: liveStream,
          sourcePlaylistId: playlistId,
          sourceType: PlaylistType.xtream,
        ),
      );
    } else if (historyIsM3u) {
      final liveStream = await _database.getM3uItemsByIdAndPlaylist(
        playlistId,
        history.streamId,
      );

      if (liveStream != null) {
        navigateByContentType(
          context,
          ContentItem(
            liveStream.url,
            history.title,
            history.imagePath ?? '',
            history.contentType,
            m3uItem: liveStream,
            sourcePlaylistId: playlistId,
            sourceType: PlaylistType.m3u,
          ),
        );
      }
    }
  }

  Future<void> _playMovie(BuildContext context, WatchHistory history) async {
    final playlistId = history.playlistId;
    final historyIsXtream = isXtreamCodeById(playlistId);
    final historyIsM3u = isM3uById(playlistId);

    if (historyIsXtream) {
      final movie = await _database.findMovieById(
        history.streamId,
        playlistId,
      );

      if (movie != null) {
        navigateByContentType(
          context,
          ContentItem(
            history.streamId,
            history.title,
            history.imagePath ?? '',
            history.contentType,
            containerExtension: movie.containerExtension,
            vodStream: movie,
            sourcePlaylistId: playlistId,
            sourceType: PlaylistType.xtream,
          ),
        );
      }
    } else if (historyIsM3u) {
      var movie = await _database.getM3uItemsByIdAndPlaylist(
        playlistId,
        history.streamId,
      );

      if (movie != null) {
        navigateByContentType(
          context,
          ContentItem(
            movie.url,
            history.title,
            history.imagePath ?? '',
            history.contentType,
            m3uItem: movie,
            sourcePlaylistId: playlistId,
            sourceType: PlaylistType.m3u,
          ),
        );
      }
    }
  }

  Future<void> _playSeries(BuildContext context, WatchHistory history) async {
    final playlistId = history.playlistId;
    final historyIsXtream = isXtreamCodeById(playlistId);
    final historyIsM3u = isM3uById(playlistId);

    if (historyIsXtream) {
      final episode = await _database.findEpisodesById(
        history.streamId,
        playlistId,
      );

      if (episode == null) return;

      // Get the correct repository for this playlist
      final repository = AppState.xtreamRepositories[playlistId] ?? AppState.xtreamCodeRepository;
      if (repository == null) return;

      final seriesResponse = await repository.getSeriesInfo(
        episode.seriesId,
      );

      if (seriesResponse == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EpisodeScreen(
            seriesInfo: seriesResponse.seriesInfo,
            seasons: seriesResponse.seasons,
            episodes: seriesResponse.episodes,
            contentItem: ContentItem(
              episode.episodeId.toString(),
              history.title,
              history.imagePath ?? "",
              ContentType.series,
              containerExtension: episode.containerExtension,
              season: episode.season,
              sourcePlaylistId: playlistId,
              sourceType: PlaylistType.xtream,
            ),
            watchHistory: history,
          ),
        ),
      );
    } else if (historyIsM3u) {
      var m3uItem = await _database.getM3uItemsByIdAndPlaylist(
        playlistId,
        history.streamId,
      );

      if (m3uItem == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => M3uPlayerScreen(
            contentItem: ContentItem(
              m3uItem.id,
              m3uItem.name ?? '',
              m3uItem.tvgLogo ?? '',
              m3uItem.contentType,
              m3uItem: m3uItem,
              sourcePlaylistId: playlistId,
              sourceType: PlaylistType.m3u,
            ),
          ),
        ),
      );
    }
  }
}
