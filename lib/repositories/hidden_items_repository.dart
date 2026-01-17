import '../database/database.dart';
import '../models/hidden_item.dart';
import '../models/content_type.dart';
import '../models/playlist_content_model.dart';
import '../services/app_state.dart';
import '../services/service_locator.dart';

class HiddenItemsRepository {
  final AppDatabase _db = getIt<AppDatabase>();

  Future<void> hideItem(HiddenItem item) async {
    await _db.insertHiddenItem(item.toCompanion());
  }

  Future<void> unhideItem(String id) async {
    await _db.deleteHiddenItem(id);
  }

  Future<void> unhideByStreamId(
    String playlistId,
    String streamId,
    ContentType contentType,
  ) async {
    await _db.deleteHiddenItemByStreamId(playlistId, streamId, contentType);
  }

  Future<List<HiddenItem>> getAllHiddenItems() async {
    final data = await _db.getAllHiddenItems();
    return data.map((d) => HiddenItem.fromDrift(d)).toList();
  }

  Future<List<HiddenItem>> getHiddenItemsByPlaylist(String playlistId) async {
    final data = await _db.getHiddenItemsByPlaylist(playlistId);
    return data.map((d) => HiddenItem.fromDrift(d)).toList();
  }

  Future<Set<String>> getHiddenStreamIds(String playlistId) async {
    return await _db.getHiddenStreamIds(playlistId);
  }

  Future<bool> isHidden(
    String playlistId,
    String streamId,
    ContentType contentType,
  ) async {
    return await _db.isHidden(playlistId, streamId, contentType);
  }

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

  Future<HiddenItem> hideContentItem(ContentItem item) async {
    final playlistId = _getPlaylistId(item);
    final hiddenItem = HiddenItem(
      playlistId: playlistId,
      contentType: item.contentType,
      streamId: item.id,
      name: item.name,
      imagePath: item.imagePath,
    );
    await hideItem(hiddenItem);
    return hiddenItem;
  }

  Future<void> unhideContentItem(ContentItem item) async {
    final playlistId = _getPlaylistId(item);
    await unhideByStreamId(playlistId, item.id, item.contentType);
  }
}
