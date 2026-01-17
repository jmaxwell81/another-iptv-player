import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:uuid/uuid.dart';

class FavoritesRepository {
  final _database = getIt<AppDatabase>();
  final _uuid = Uuid();

  FavoritesRepository();

  /// Get playlist ID - uses source from content item in combined mode, or current playlist
  String _getPlaylistId([ContentItem? contentItem]) {
    // In combined mode, use source playlist from content item if available
    if (contentItem?.sourcePlaylistId != null) {
      return contentItem!.sourcePlaylistId!;
    }
    // Fall back to current playlist
    if (AppState.currentPlaylist != null) {
      return AppState.currentPlaylist!.id;
    }
    // In combined mode without content item, return 'unified'
    if (AppState.isCombinedMode) {
      return 'unified';
    }
    throw StateError('No playlist available');
  }

  Future<void> addFavorite(ContentItem contentItem) async {
    final playlistId = _getPlaylistId(contentItem);

    final isAlreadyFavorite = await _database.isFavorite(
      playlistId,
      contentItem.id,
      contentItem.contentType,
      contentItem.season != null ? contentItem.id : null,
    );

    if (isAlreadyFavorite) {
      throw Exception('Bu içerik zaten favorilerde');
    }

    final favorite = Favorite(
      id: _uuid.v4(),
      playlistId: playlistId,
      contentType: contentItem.contentType,
      streamId: contentItem.id,
      m3uItemId: contentItem.m3uItem?.id,
      name: contentItem.name,
      imagePath: contentItem.imagePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _database.insertFavorite(favorite);
  }

  Future<void> removeFavorite(
    String streamId,
    ContentType contentType, {
    String? episodeId,
  }) async {
    final playlistId = _getPlaylistId();

    final favorites = await _database.getFavoritesByPlaylist(playlistId);
    final favorite = favorites.firstWhere(
      (f) =>
          f.streamId == streamId &&
          f.contentType == contentType &&
          f.episodeId == episodeId,
      orElse: () => throw Exception('Favori bulunamadı'),
    );

    await _database.deleteFavorite(favorite.id);
  }

  Future<bool> isFavorite(
    String streamId,
    ContentType contentType, {
    String? episodeId,
  }) async {
    final playlistId = _getPlaylistId();
    return await _database.isFavorite(
      playlistId,
      streamId,
      contentType,
      episodeId,
    );
  }

  Future<List<Favorite>> getAllFavorites() async {
    // In combined mode, get favorites from all active playlists
    if (AppState.isCombinedMode) {
      final allFavorites = <Favorite>[];
      for (final playlistId in AppState.activePlaylists.keys) {
        final favorites = await _database.getFavoritesByPlaylist(playlistId);
        allFavorites.addAll(favorites);
      }
      return allFavorites;
    }
    final playlistId = _getPlaylistId();
    return await _database.getFavoritesByPlaylist(playlistId);
  }

  Future<List<Favorite>> getFavoritesByContentType(
    ContentType contentType,
  ) async {
    // In combined mode, get favorites from all active playlists
    if (AppState.isCombinedMode) {
      final allFavorites = <Favorite>[];
      for (final playlistId in AppState.activePlaylists.keys) {
        final favorites = await _database.getFavoritesByContentType(playlistId, contentType);
        allFavorites.addAll(favorites);
      }
      return allFavorites;
    }
    final playlistId = _getPlaylistId();
    return await _database.getFavoritesByContentType(playlistId, contentType);
  }

  Future<List<Favorite>> getLiveStreamFavorites() async {
    return await getFavoritesByContentType(ContentType.liveStream);
  }

  Future<List<Favorite>> getMovieFavorites() async {
    return await getFavoritesByContentType(ContentType.vod);
  }

  Future<List<Favorite>> getSeriesFavorites() async {
    return await getFavoritesByContentType(ContentType.series);
  }

  Future<int> getFavoriteCount() async {
    // In combined mode, count favorites from all active playlists
    if (AppState.isCombinedMode) {
      int total = 0;
      for (final playlistId in AppState.activePlaylists.keys) {
        total += await _database.getFavoriteCount(playlistId);
      }
      return total;
    }
    final playlistId = _getPlaylistId();
    return await _database.getFavoriteCount(playlistId);
  }

  Future<int> getFavoriteCountByContentType(ContentType contentType) async {
    // In combined mode, count favorites from all active playlists
    if (AppState.isCombinedMode) {
      int total = 0;
      for (final playlistId in AppState.activePlaylists.keys) {
        total += await _database.getFavoriteCountByContentType(playlistId, contentType);
      }
      return total;
    }
    final playlistId = _getPlaylistId();
    return await _database.getFavoriteCountByContentType(
      playlistId,
      contentType,
    );
  }

  Future<bool> toggleFavorite(ContentItem contentItem) async {
    final playlistId = _getPlaylistId(contentItem);
    final isCurrentlyFavorite = await _database.isFavorite(
      playlistId,
      contentItem.id,
      contentItem.contentType,
      null
    );

    if (isCurrentlyFavorite) {
      await removeFavorite(
        contentItem.id,
        contentItem.contentType
      );
      return false;
    } else {
      await addFavorite(contentItem);
      return true;
    }
  }

  Future<void> updateFavorite(Favorite favorite) async {
    await _database.updateFavorite(favorite);
  }

  Future<void> addFavoriteFromData(Favorite favorite) async {
    final isAlreadyFavorite = await _database.isFavorite(
      favorite.playlistId,
      favorite.streamId,
      favorite.contentType,
      favorite.episodeId,
    );

    if (isAlreadyFavorite) {
      throw Exception('This content is already in favorites');
    }

    await _database.insertFavorite(favorite);
  }

  Future<void> clearAllFavorites() async {
    // In combined mode, clear favorites from all active playlists
    if (AppState.isCombinedMode) {
      for (final playlistId in AppState.activePlaylists.keys) {
        final favorites = await _database.getFavoritesByPlaylist(playlistId);
        for (final favorite in favorites) {
          await _database.deleteFavorite(favorite.id);
        }
      }
      return;
    }
    final playlistId = _getPlaylistId();
    final favorites = await _database.getFavoritesByPlaylist(playlistId);

    for (final favorite in favorites) {
      await _database.deleteFavorite(favorite.id);
    }
  }

  Future<ContentItem?> getContentItemFromFavorite(Favorite favorite) async {
    try {
      // Determine source type based on favorite's playlist
      final isXtream = AppState.xtreamRepositories.containsKey(favorite.playlistId) ||
          (AppState.currentPlaylist != null && AppState.currentPlaylist!.type == PlaylistType.xtream);
      final isM3u = AppState.m3uRepositories.containsKey(favorite.playlistId) ||
          (AppState.currentPlaylist != null && AppState.currentPlaylist!.type == PlaylistType.m3u);

      if (isXtream) {
        // Get repository for this favorite's playlist
        final repository = AppState.xtreamRepositories[favorite.playlistId] ?? AppState.xtreamCodeRepository;
        if (repository == null) {
          return ContentItem(
            favorite.streamId,
            favorite.name,
            favorite.imagePath ?? '',
            favorite.contentType,
            sourcePlaylistId: favorite.playlistId,
            sourceType: PlaylistType.xtream,
          );
        }

        switch (favorite.contentType) {
          case ContentType.liveStream:
            final liveStream = await repository.findLiveStreamById(
              favorite.streamId,
            );

            if (liveStream != null) {
              return ContentItem(
                liveStream.streamId,
                liveStream.name,
                liveStream.streamIcon,
                ContentType.liveStream,
                liveStream: liveStream,
                sourcePlaylistId: favorite.playlistId,
                sourceType: PlaylistType.xtream,
              );
            }
            break;

          case ContentType.vod:
            final movie = await _database.findMovieById(
              favorite.streamId,
              favorite.playlistId,
            );

            if (movie != null) {
              return ContentItem(
                favorite.streamId,
                favorite.name,
                favorite.imagePath ?? '',
                ContentType.vod,
                containerExtension: movie.containerExtension,
                vodStream: movie,
                sourcePlaylistId: favorite.playlistId,
                sourceType: PlaylistType.xtream,
              );
            }
            break;
          case ContentType.series:
            final series = await repository.getSeries(categoryId: '');
            final seriesStream = series?.firstWhere(
              (serie) => serie.seriesId == favorite.streamId,
            );
            if (seriesStream != null) {
              return ContentItem(
                seriesStream.seriesId,
                seriesStream.name,
                seriesStream.cover ?? '',
                ContentType.series,
                seriesStream: seriesStream,
                sourcePlaylistId: favorite.playlistId,
                sourceType: PlaylistType.xtream,
              );
            }
            break;
        }
      } else if (isM3u) {
        final repository = M3uRepository(playlistId: favorite.playlistId);

        switch (favorite.contentType) {
          case ContentType.liveStream:
            final m3uItem = await repository.getM3uItemById(
              id: favorite.m3uItemId ?? '',
            );
            if (m3uItem != null) {
              return ContentItem(
                m3uItem.url,
                m3uItem.name ?? 'NO NAME',
                m3uItem.tvgLogo ?? '',
                ContentType.liveStream,
                m3uItem: m3uItem,
                sourcePlaylistId: favorite.playlistId,
                sourceType: PlaylistType.m3u,
              );
            }
            break;

          case ContentType.vod:
            final m3uItem = await repository.getM3uItemById(
              id: favorite.m3uItemId ?? '',
            );

            if (m3uItem != null) {
              return ContentItem(
                m3uItem.url,
                m3uItem.name ?? 'NO NAME',
                m3uItem.tvgLogo ?? '',
                ContentType.vod,
                m3uItem: m3uItem,
                sourcePlaylistId: favorite.playlistId,
                sourceType: PlaylistType.m3u,
              );
            }
            break;

          case ContentType.series:
            final m3uItem = await repository.getM3uItemById(
              id: favorite.m3uItemId ?? '',
            );

            if (m3uItem != null) {
              return ContentItem(
                m3uItem.id,
                m3uItem.name ?? '',
                m3uItem.tvgLogo ?? '',
                ContentType.series,
                m3uItem: m3uItem,
                sourcePlaylistId: favorite.playlistId,
                sourceType: PlaylistType.m3u,
              );
            }
            break;
        }
      }

      // Determine source type for fallback
      final fallbackSourceType = isXtream ? PlaylistType.xtream : (isM3u ? PlaylistType.m3u : null);
      return ContentItem(
        favorite.streamId,
        favorite.name,
        favorite.imagePath ?? '',
        favorite.contentType,
        sourcePlaylistId: favorite.playlistId,
        sourceType: fallbackSourceType,
      );
    } catch (e) {
      return ContentItem(
        favorite.streamId,
        favorite.name,
        favorite.imagePath ?? '',
        favorite.contentType,
        sourcePlaylistId: favorite.playlistId,
      );
    }
  }
}
