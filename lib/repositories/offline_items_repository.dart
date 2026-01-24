import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/offline_item.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:drift/drift.dart';

/// Repository for managing offline items (streams marked as unavailable)
class OfflineItemsRepository {
  static final OfflineItemsRepository _instance =
      OfflineItemsRepository._internal();

  factory OfflineItemsRepository() => _instance;

  OfflineItemsRepository._internal();

  final _db = getIt<AppDatabase>();

  /// Mark a content item as offline
  Future<void> markOffline(
    ContentItem item, {
    bool temporary = false,
    bool autoDetected = false,
    int? tempHours,
  }) async {
    final playlistId = AppState.currentPlaylist?.id ?? '';
    if (playlistId.isEmpty) return;

    DateTime? temporaryUntil;
    if (temporary && tempHours != null && tempHours > 0) {
      temporaryUntil = DateTime.now().add(Duration(hours: tempHours));
    }

    final id = '${playlistId}_${item.id}';

    await _db.insertOfflineItem(
      OfflineItemsCompanion(
        id: Value(id),
        playlistId: Value(playlistId),
        contentType: Value(item.contentType.index),
        streamId: Value(item.id),
        name: Value(item.name),
        imagePath: Value(item.imagePath),
        markedAt: Value(DateTime.now()),
        autoDetected: Value(autoDetected),
        temporaryUntil: Value(temporaryUntil),
      ),
    );
  }

  /// Mark a content item as online (remove offline status)
  Future<void> markOnline(ContentItem item) async {
    final playlistId = AppState.currentPlaylist?.id ?? '';
    if (playlistId.isEmpty) return;

    await _db.deleteOfflineItemByStreamId(playlistId, item.id);
  }

  /// Mark a stream ID as online for a specific playlist
  Future<void> markOnlineByStreamId(String playlistId, String streamId) async {
    await _db.deleteOfflineItemByStreamId(playlistId, streamId);
  }

  /// Check if a stream is marked as offline
  Future<bool> isOffline(String playlistId, String streamId) async {
    return await _db.isOffline(playlistId, streamId);
  }

  /// Check if current playlist's stream is offline
  Future<bool> isStreamOffline(String streamId) async {
    final playlistId = AppState.currentPlaylist?.id ?? '';
    if (playlistId.isEmpty) return false;
    return await _db.isOffline(playlistId, streamId);
  }

  /// Get all offline stream IDs for a playlist
  Future<Set<String>> getOfflineStreamIds(String playlistId) async {
    return await _db.getOfflineStreamIds(playlistId);
  }

  /// Get all offline stream IDs for current playlist
  Future<Set<String>> getCurrentPlaylistOfflineStreamIds() async {
    final playlistId = AppState.currentPlaylist?.id ?? '';
    if (playlistId.isEmpty) return {};
    return await getOfflineStreamIds(playlistId);
  }

  /// Get all offline items for a playlist
  Future<List<OfflineItem>> getOfflineItems(String playlistId) async {
    final items = await _db.getOfflineItemsByPlaylist(playlistId);
    return items.map(_convertToOfflineItem).toList();
  }

  /// Get all offline items for current playlist
  Future<List<OfflineItem>> getCurrentPlaylistOfflineItems() async {
    final playlistId = AppState.currentPlaylist?.id ?? '';
    if (playlistId.isEmpty) return [];
    return await getOfflineItems(playlistId);
  }

  /// Get offline item details for a specific stream
  Future<OfflineItem?> getOfflineItem(
    String playlistId,
    String streamId,
  ) async {
    final item = await _db.getOfflineItem(playlistId, streamId);
    return item != null ? _convertToOfflineItem(item) : null;
  }

  /// Clean up expired temporary offline items
  Future<int> cleanupExpiredTemporary() async {
    return await _db.cleanupExpiredOfflineItems();
  }

  /// Get count of offline items for a playlist
  Future<int> getOfflineCount(String playlistId) async {
    return await _db.getOfflineItemCount(playlistId);
  }

  /// Convert database data to OfflineItem model
  OfflineItem _convertToOfflineItem(OfflineItemsData data) {
    return OfflineItem(
      id: data.id,
      playlistId: data.playlistId,
      contentType: ContentType.values[data.contentType],
      streamId: data.streamId,
      name: data.name,
      imagePath: data.imagePath,
      markedAt: data.markedAt,
      autoDetected: data.autoDetected,
      temporaryUntil: data.temporaryUntil,
    );
  }

  /// Get offline stream IDs from multiple playlists (for combined mode)
  Future<Set<String>> getOfflineStreamIdsFromPlaylists(
    List<String> playlistIds,
  ) async {
    final allIds = <String>{};
    for (final playlistId in playlistIds) {
      final ids = await getOfflineStreamIds(playlistId);
      allIds.addAll(ids);
    }
    return allIds;
  }
}
