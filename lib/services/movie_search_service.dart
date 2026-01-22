import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/services/tmdb_service.dart';

/// Service for searching movies in the IPTV library by various criteria
class MovieSearchService {
  static final MovieSearchService _instance = MovieSearchService._internal();
  factory MovieSearchService() => _instance;
  MovieSearchService._internal();

  final _database = getIt<AppDatabase>();
  final _tmdbService = getIt<TmdbService>();

  /// Search for movies by actor name across all IPTV sources
  Future<List<ContentItem>> searchMoviesByActor(String actorName) async {
    final results = <ContentItem>[];
    final actorLower = actorName.toLowerCase();

    try {
      // Search in Xtream repositories
      for (final entry in AppState.xtreamRepositories.entries) {
        final movies = await _searchXtreamMoviesByCast(entry.value, entry.key, actorLower);
        results.addAll(movies);
      }

      // If in single playlist mode
      if (AppState.xtreamCodeRepository != null &&
          AppState.currentPlaylist?.type == PlaylistType.xtream) {
        final movies = await _searchXtreamMoviesByCast(
          AppState.xtreamCodeRepository!,
          AppState.currentPlaylist!.id,
          actorLower,
        );
        // Add only if not already in results
        for (final movie in movies) {
          if (!results.any((r) => r.id == movie.id && r.sourcePlaylistId == movie.sourcePlaylistId)) {
            results.add(movie);
          }
        }
      }

      // Search in M3U repositories
      for (final entry in AppState.m3uRepositories.entries) {
        final movies = await _searchM3uMoviesByCast(entry.value, entry.key, actorLower);
        results.addAll(movies);
      }

      // If in single playlist mode
      if (AppState.m3uRepository != null &&
          AppState.currentPlaylist?.type == PlaylistType.m3u) {
        final movies = await _searchM3uMoviesByCast(
          AppState.m3uRepository!,
          AppState.currentPlaylist!.id,
          actorLower,
        );
        for (final movie in movies) {
          if (!results.any((r) => r.id == movie.id && r.sourcePlaylistId == movie.sourcePlaylistId)) {
            results.add(movie);
          }
        }
      }

      // Also search cached TMDB data for movies with this actor
      final tmdbResults = await _searchTmdbCachedByActor(actorLower);
      for (final movie in tmdbResults) {
        if (!results.any((r) => r.id == movie.id && r.sourcePlaylistId == movie.sourcePlaylistId)) {
          results.add(movie);
        }
      }
    } catch (e) {
      debugPrint('Error searching movies by actor: $e');
    }

    return results;
  }

  /// Search Xtream movies by cast
  Future<List<ContentItem>> _searchXtreamMoviesByCast(
    IptvRepository repository,
    String playlistId,
    String actorLower,
  ) async {
    final results = <ContentItem>[];

    try {
      // Get all VOD categories
      final categories = await repository.getVodCategories();
      if (categories == null) return results;

      for (final category in categories) {
        final movies = await repository.getMovies(categoryId: category.categoryId);
        if (movies == null) continue;

        for (final movie in movies) {
          // Check if actor is in cast
          final cast = movie.cast?.toLowerCase() ?? '';
          if (cast.contains(actorLower)) {
            results.add(ContentItem(
              movie.streamId,
              movie.name,
              movie.streamIcon,
              ContentType.vod,
              vodStream: movie,
              containerExtension: movie.containerExtension,
              sourcePlaylistId: playlistId,
              sourceType: PlaylistType.xtream,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching Xtream movies by cast: $e');
    }

    return results;
  }

  /// Search M3U movies by cast (if metadata is available)
  Future<List<ContentItem>> _searchM3uMoviesByCast(
    M3uRepository repository,
    String playlistId,
    String actorLower,
  ) async {
    // M3U files typically don't have cast metadata
    // We rely on TMDB cached data for this
    return [];
  }

  /// Search TMDB cached data for movies with specific actor
  Future<List<ContentItem>> _searchTmdbCachedByActor(String actorLower) async {
    final results = <ContentItem>[];

    try {
      // Get all cached content details
      final allDetails = await _database.getAllContentDetails();

      for (final details in allDetails) {
        if (details.cast == null) continue;

        final castLower = details.cast!.toLowerCase();
        if (castLower.contains(actorLower)) {
          // Try to find the corresponding movie in the library
          final movie = await _findMovieById(details.contentId, details.playlistId);
          if (movie != null) {
            results.add(movie);
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching TMDB cached by actor: $e');
    }

    return results;
  }

  /// Find similar movies in the IPTV library based on TMDB IDs
  Future<List<ContentItem>> findSimilarMoviesInLibrary(
    String currentContentId,
    String playlistId,
    List<int> similarTmdbIds,
  ) async {
    final results = <ContentItem>[];

    try {
      // Get all cached content that matches similar TMDB IDs
      for (final tmdbId in similarTmdbIds.take(20)) {
        final details = await _database.getContentDetailsByTmdbId(tmdbId);
        if (details != null && details.contentId != currentContentId) {
          final movie = await _findMovieById(details.contentId, details.playlistId);
          if (movie != null) {
            results.add(movie);
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding similar movies: $e');
    }

    return results;
  }

  /// Find a movie by ID across all sources
  Future<ContentItem?> _findMovieById(String contentId, String playlistId) async {
    try {
      // Try Xtream repositories
      final xtreamRepo = AppState.xtreamRepositories[playlistId] ?? AppState.xtreamCodeRepository;
      if (xtreamRepo != null) {
        final movie = await _database.findMovieById(contentId, playlistId);
        if (movie != null) {
          return ContentItem(
            movie.streamId,
            movie.name,
            movie.streamIcon,
            ContentType.vod,
            vodStream: movie,
            containerExtension: movie.containerExtension,
            sourcePlaylistId: playlistId,
            sourceType: PlaylistType.xtream,
          );
        }
      }

      // Try M3U repositories
      final m3uRepo = AppState.m3uRepositories[playlistId] ?? AppState.m3uRepository;
      if (m3uRepo != null) {
        final m3uItem = await m3uRepo.getM3uItemById(id: contentId);
        if (m3uItem != null) {
          return ContentItem(
            m3uItem.url,
            m3uItem.name ?? '',
            m3uItem.tvgLogo ?? '',
            ContentType.vod,
            m3uItem: m3uItem,
            sourcePlaylistId: playlistId,
            sourceType: PlaylistType.m3u,
          );
        }
      }
    } catch (e) {
      debugPrint('Error finding movie by ID: $e');
    }

    return null;
  }

  /// Search all movies by name (for finding similar movies by title matching)
  Future<List<ContentItem>> searchMoviesByName(String query, {String? excludeId}) async {
    final results = <ContentItem>[];
    final queryLower = query.toLowerCase();

    try {
      // Search in Xtream repositories
      for (final entry in AppState.xtreamRepositories.entries) {
        final categories = await entry.value.getVodCategories();
        if (categories == null) continue;

        for (final category in categories) {
          final movies = await entry.value.getMovies(categoryId: category.categoryId);
          if (movies == null) continue;

          for (final movie in movies) {
            if (excludeId != null && movie.streamId == excludeId) continue;
            if (movie.name.toLowerCase().contains(queryLower)) {
              results.add(ContentItem(
                movie.streamId,
                movie.name,
                movie.streamIcon,
                ContentType.vod,
                vodStream: movie,
                containerExtension: movie.containerExtension,
                sourcePlaylistId: entry.key,
                sourceType: PlaylistType.xtream,
              ));
            }
          }
        }
      }

      // Search in current Xtream playlist
      if (AppState.xtreamCodeRepository != null && AppState.currentPlaylist?.type == PlaylistType.xtream) {
        final categories = await AppState.xtreamCodeRepository!.getVodCategories();
        if (categories != null) {
          for (final category in categories) {
            final movies = await AppState.xtreamCodeRepository!.getMovies(categoryId: category.categoryId);
            if (movies == null) continue;

            for (final movie in movies) {
              if (excludeId != null && movie.streamId == excludeId) continue;
              if (movie.name.toLowerCase().contains(queryLower)) {
                if (!results.any((r) => r.id == movie.streamId)) {
                  results.add(ContentItem(
                    movie.streamId,
                    movie.name,
                    movie.streamIcon,
                    ContentType.vod,
                    vodStream: movie,
                    containerExtension: movie.containerExtension,
                    sourcePlaylistId: AppState.currentPlaylist!.id,
                    sourceType: PlaylistType.xtream,
                  ));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching movies by name: $e');
    }

    return results;
  }
}
