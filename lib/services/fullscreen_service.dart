import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Service to manage fullscreen mode on desktop platforms (macOS, Windows, Linux)
class FullscreenService extends ChangeNotifier {
  static final FullscreenService _instance = FullscreenService._internal();
  factory FullscreenService() => _instance;
  FullscreenService._internal();

  bool _isFullscreen = false;
  bool _initialized = false;

  bool get isFullscreen => _isFullscreen;
  bool get isSupported => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Initialize the service (window manager should already be initialized in main)
  Future<void> initialize() async {
    if (_initialized || !isSupported) return;

    try {
      _isFullscreen = await windowManager.isFullScreen();
      _initialized = true;
    } catch (e) {
      debugPrint('FullscreenService: Failed to initialize: $e');
    }
  }

  /// Toggle fullscreen mode
  Future<void> toggle() async {
    if (!isSupported) return;

    try {
      _isFullscreen = !_isFullscreen;
      await windowManager.setFullScreen(_isFullscreen);
      notifyListeners();
    } catch (e) {
      debugPrint('FullscreenService: Failed to toggle fullscreen: $e');
    }
  }

  /// Enter fullscreen mode
  Future<void> enterFullscreen() async {
    if (!isSupported || _isFullscreen) return;

    try {
      if (!_initialized) {
        await initialize();
      }

      _isFullscreen = true;
      await windowManager.setFullScreen(true);
      notifyListeners();
    } catch (e) {
      debugPrint('FullscreenService: Failed to enter fullscreen: $e');
    }
  }

  /// Exit fullscreen mode
  Future<void> exitFullscreen() async {
    if (!isSupported || !_isFullscreen) return;

    try {
      _isFullscreen = false;
      await windowManager.setFullScreen(false);
      notifyListeners();
    } catch (e) {
      debugPrint('FullscreenService: Failed to exit fullscreen: $e');
    }
  }

  /// Check current fullscreen state from window manager
  Future<void> refreshState() async {
    if (!isSupported || !_initialized) return;

    try {
      final wasFullscreen = _isFullscreen;
      _isFullscreen = await windowManager.isFullScreen();
      if (wasFullscreen != _isFullscreen) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FullscreenService: Failed to refresh state: $e');
    }
  }
}
