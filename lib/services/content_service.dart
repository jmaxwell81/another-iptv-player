import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import '../models/category_type.dart';

class ContentService {
  /// Fetch content for a category, with optional source playlist override (for combined mode)
  Future<List<ContentItem>> fetchContentByCategory(
    CategoryViewModel category, {
    String? sourcePlaylistId,
    PlaylistType? sourceType,
  }) async {
    final categoryId = category.category.categoryId;
    // Use category's playlistId for routing - this is set correctly for each source in combined mode
    String? playlistId = sourcePlaylistId ?? category.category.playlistId;

    debugPrint('ContentService: fetchContentByCategory');
    debugPrint('  categoryId: $categoryId, playlistId: $playlistId');

    // Handle merged categories - these are virtual and need special handling
    if (categoryId.startsWith('merged_') || playlistId == 'unified') {
      // For merged categories, return the already-loaded content items
      // since we can't fetch by a virtual category ID
      debugPrint('  Merged/unified category - returning ${category.contentItems.length} cached items');
      return category.contentItems;
    }

    // Determine playlist type from sourceType, playlistId, or current playlist
    PlaylistType? playlistType = sourceType;

    if (playlistType == null && playlistId != null) {
      // Try to determine type from the playlist ID
      if (AppState.xtreamRepositories.containsKey(playlistId)) {
        playlistType = PlaylistType.xtream;
      } else if (AppState.m3uRepositories.containsKey(playlistId)) {
        playlistType = PlaylistType.m3u;
      }
    }

    // Fall back to current playlist
    if (playlistType == null && AppState.currentPlaylist != null) {
      playlistType = AppState.currentPlaylist!.type;
      playlistId ??= AppState.currentPlaylist!.id;
    }

    if (playlistType == null) {
      debugPrint('  ERROR: No playlist type available');
      throw Exception('No playlist type available for fetching content');
    }

    debugPrint('  Final: playlistId=$playlistId, type=$playlistType, categoryId=$categoryId');

    try {
      switch (playlistType) {
        case PlaylistType.xtream:
          final result = await _fetchXtreamContent(
            category.category.type,
            categoryId,
            playlistId,
          );
          debugPrint('  Fetched ${result.length} items');
          return result;
        case PlaylistType.m3u:
          final result = await _fetchM3uContent(
            category.category.type,
            categoryId,
            playlistId,
          );
          debugPrint('  Fetched ${result.length} items');
          return result;
      }
    } catch (e) {
      debugPrint('  ERROR fetching content: $e');
      throw Exception('İçerik yüklenirken hata oluştu: $e');
    }
  }

  Future<List<ContentItem>> _fetchXtreamContent(
    CategoryType type,
    String categoryId,
    String? playlistId,
  ) async {
    // Get the right repository
    final repository = playlistId != null
        ? AppState.xtreamRepositories[playlistId] ?? AppState.xtreamCodeRepository
        : AppState.xtreamCodeRepository;

    if (repository == null) {
      throw Exception('No Xtream repository available');
    }

    final sourcePlaylistId = playlistId ?? AppState.currentPlaylist?.id;

    switch (type) {
      case CategoryType.live:
        return await _fetchGenericContent(
          () => repository.getLiveChannelsByCategoryId(categoryId: categoryId),
          ContentType.liveStream,
          (item) => ContentItem(
            item.streamId,
            item.name,
            item.streamIcon,
            ContentType.liveStream,
            liveStream: item,
            sourcePlaylistId: sourcePlaylistId,
            sourceType: PlaylistType.xtream,
          ),
          'Canlı kanallar yüklenirken hata',
        );
      case CategoryType.vod:
        return await _fetchGenericContent(
          () => repository.getMovies(categoryId: categoryId),
          ContentType.vod,
          (item) => ContentItem(
            item.streamId,
            item.name,
            item.streamIcon,
            ContentType.vod,
            containerExtension: item.containerExtension,
            vodStream: item,
            sourcePlaylistId: sourcePlaylistId,
            sourceType: PlaylistType.xtream,
          ),
          'Filmler yüklenirken hata',
        );
      case CategoryType.series:
        return await _fetchGenericContent(
          () => repository.getSeries(categoryId: categoryId),
          ContentType.series,
          (item) => ContentItem(
            item.seriesId,
            item.name,
            item.cover ?? '',
            ContentType.series,
            seriesStream: item,
            sourcePlaylistId: sourcePlaylistId,
            sourceType: PlaylistType.xtream,
          ),
          'Diziler yüklenirken hata',
        );
    }
  }

  Future<List<ContentItem>> _fetchM3uContent(
    CategoryType type,
    String categoryId,
    String? playlistId,
  ) async {
    // Get the right repository - prefer from AppState, otherwise create with playlistId
    final repository = playlistId != null
        ? AppState.m3uRepositories[playlistId] ?? M3uRepository(playlistId: playlistId)
        : M3uRepository();

    final sourcePlaylistId = playlistId ?? AppState.currentPlaylist?.id;

    switch (type) {
      case CategoryType.live:
        return await _fetchGenericContent(
          () => repository.getM3uItemsByCategoryId(
            categoryId: categoryId,
            contentType: ContentType.liveStream,
          ),
          ContentType.liveStream,
          (item) => ContentItem(
            item.url,
            item.name ?? 'NO NAME',
            item.tvgLogo ?? '',
            ContentType.liveStream,
            m3uItem: item,
            sourcePlaylistId: sourcePlaylistId,
            sourceType: PlaylistType.m3u,
          ),
          'M3U canlı kanallar yüklenirken hata',
        );
      case CategoryType.vod:
        return await _fetchGenericContent(
          () => repository.getM3uItemsByCategoryId(
            categoryId: categoryId,
            contentType: ContentType.vod,
          ),
          ContentType.vod,
          (item) => ContentItem(
            item.url,
            item.name ?? 'NO NAME',
            item.tvgLogo ?? '',
            ContentType.vod,
            m3uItem: item,
            sourcePlaylistId: sourcePlaylistId,
            sourceType: PlaylistType.m3u,
          ),
          'M3U filmler yüklenirken hata',
        );
      case CategoryType.series:
        return await _fetchGenericContent(
          () => repository.getSeriesByCategoryId(categoryId: categoryId),
          ContentType.series,
          (item) => ContentItem(
            item.seriesId,
            item.name,
            '',
            ContentType.series,
            sourcePlaylistId: sourcePlaylistId,
            sourceType: PlaylistType.m3u,
          ),
          'M3U diziler yüklenirken hata',
        );
    }
  }

  Future<List<ContentItem>> _fetchGenericContent<T>(
    Future<List<T>?> Function() fetchFunction,
    ContentType contentType,
    ContentItem Function(T) mapper,
    String errorMessage,
  ) async {
    try {
      final result = await fetchFunction();
      if (result == null) return <ContentItem>[];
      return result.map(mapper).toList();
    } catch (e) {
      throw Exception('$errorMessage: $e');
    }
  }
}
