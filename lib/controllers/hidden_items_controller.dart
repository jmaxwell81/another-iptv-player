import 'package:flutter/foundation.dart';
import '../models/hidden_item.dart';
import '../models/content_type.dart';
import '../models/playlist_content_model.dart';
import '../repositories/hidden_items_repository.dart';
import '../services/app_state.dart';

class HiddenItemsController extends ChangeNotifier {
  final HiddenItemsRepository _repository = HiddenItemsRepository();

  List<HiddenItem> _hiddenItems = [];
  Set<String> _hiddenStreamIds = {};
  bool _isLoading = false;
  String? _error;

  List<HiddenItem> get hiddenItems => _hiddenItems;
  Set<String> get hiddenStreamIds => _hiddenStreamIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadHiddenItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final playlistId = AppState.currentPlaylist!.id;
      _hiddenItems = await _repository.getHiddenItemsByPlaylist(playlistId);
      _hiddenStreamIds = _hiddenItems.map((item) => item.streamId).toSet();
    } catch (e) {
      _error = e.toString();
      print('Error loading hidden items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> hideItem(ContentItem item) async {
    try {
      final hiddenItem = await _repository.hideContentItem(item);
      _hiddenItems.insert(0, hiddenItem);
      _hiddenStreamIds.add(item.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error hiding item: $e');
      notifyListeners();
    }
  }

  Future<void> unhideItem(ContentItem item) async {
    try {
      await _repository.unhideContentItem(item);
      _hiddenItems.removeWhere((h) => h.streamId == item.id);
      _hiddenStreamIds.remove(item.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error unhiding item: $e');
      notifyListeners();
    }
  }

  Future<void> unhideItemById(String id) async {
    try {
      await _repository.unhideItem(id);
      final item = _hiddenItems.firstWhere((h) => h.id == id);
      _hiddenStreamIds.remove(item.streamId);
      _hiddenItems.removeWhere((h) => h.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error unhiding item: $e');
      notifyListeners();
    }
  }

  bool isHidden(String streamId) {
    return _hiddenStreamIds.contains(streamId);
  }

  List<HiddenItem> get liveStreamHiddenItems =>
      _hiddenItems.where((h) => h.contentType == ContentType.liveStream).toList();

  List<HiddenItem> get movieHiddenItems =>
      _hiddenItems.where((h) => h.contentType == ContentType.vod).toList();

  List<HiddenItem> get seriesHiddenItems =>
      _hiddenItems.where((h) => h.contentType == ContentType.series).toList();
}
