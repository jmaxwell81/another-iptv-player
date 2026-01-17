import '../database/database.dart';
import '../models/hidden_item.dart';
import '../models/content_type.dart';
import '../models/playlist_content_model.dart';
import '../services/app_state.dart';
import '../services/service_locator.dart';

class HiddenItemsRepository {
  final AppDatabase _db = AppDatabase();

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

  Future<HiddenItem> hideContentItem(ContentItem item) async {
    final playlistId = AppState.currentPlaylist!.id;
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
    final playlistId = AppState.currentPlaylist!.id;
    await unhideByStreamId(playlistId, item.id, item.contentType);
  }
}
