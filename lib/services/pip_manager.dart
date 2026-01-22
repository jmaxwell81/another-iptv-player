import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';

/// Global manager for Picture-in-Picture (PiP) state
class PipManager extends ChangeNotifier {
  static final PipManager _instance = PipManager._internal();
  factory PipManager() => _instance;
  PipManager._internal();

  ContentItem? _currentItem;
  bool _isActive = false;
  String? _sourceScreen; // 'tv_guide', 'live_streams', etc.

  ContentItem? get currentItem => _currentItem;
  bool get isActive => _isActive;
  String? get sourceScreen => _sourceScreen;

  /// Start PiP mode with the given content item
  void startPip(ContentItem item, {String? source}) {
    _currentItem = item;
    _isActive = true;
    _sourceScreen = source;
    notifyListeners();
    debugPrint('PipManager: Started PiP for ${item.name} from $source');
  }

  /// Stop PiP mode
  void stopPip() {
    if (!_isActive) return;
    _isActive = false;
    _currentItem = null;
    _sourceScreen = null;
    notifyListeners();
    debugPrint('PipManager: Stopped PiP');
  }

  /// Transfer preview to PiP when navigating away
  void transferToPip(ContentItem item, String source) {
    _currentItem = item;
    _isActive = true;
    _sourceScreen = source;
    notifyListeners();
    debugPrint('PipManager: Transferred ${item.name} to PiP from $source');
  }

  /// Check if we should show PiP (not on source screen)
  bool shouldShowPip(String currentScreen) {
    return _isActive && _sourceScreen != currentScreen;
  }
}
