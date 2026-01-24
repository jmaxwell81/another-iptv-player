import 'dart:io';
import 'package:flutter/services.dart';

/// Service to detect if the app is running on an Android TV device.
/// Uses platform channels to check for leanback feature.
class TvDetectionService {
  static TvDetectionService? _instance;
  static const _channel = MethodChannel('com.another_iptv_player/tv_detection');

  bool _isAndroidTV = false;
  bool _initialized = false;

  TvDetectionService._();

  factory TvDetectionService() {
    _instance ??= TvDetectionService._();
    return _instance!;
  }

  /// Whether the app is running on an Android TV device
  bool get isAndroidTV => _isAndroidTV;

  /// Whether the service has been initialized
  bool get isInitialized => _initialized;

  /// Initialize the service and detect if running on Android TV.
  /// Should be called early in app startup (e.g., in main()).
  Future<void> initialize() async {
    if (_initialized) return;

    // Only check on Android
    if (!Platform.isAndroid) {
      _isAndroidTV = false;
      _initialized = true;
      return;
    }

    try {
      // Try to use platform channel to detect Android TV
      final result = await _channel.invokeMethod<bool>('isAndroidTV');
      _isAndroidTV = result ?? false;
    } on MissingPluginException {
      // Platform channel not implemented yet, use fallback detection
      _isAndroidTV = await _detectAndroidTVFallback();
    } catch (e) {
      // Fallback to heuristic detection
      _isAndroidTV = await _detectAndroidTVFallback();
    }

    _initialized = true;
  }

  /// Fallback detection method using device characteristics.
  /// This is less reliable than the platform channel method.
  Future<bool> _detectAndroidTVFallback() async {
    // On Android, we can't reliably detect TV without platform channels
    // but we can make an educated guess based on screen characteristics
    // For now, return false and rely on platform channel implementation
    return false;
  }

  /// Force re-detection (useful for testing)
  Future<void> redetect() async {
    _initialized = false;
    await initialize();
  }
}
