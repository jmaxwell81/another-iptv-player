import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/active_playlists_config.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// Service for managing active playlists in combined mode
class ActivePlaylistsService extends ChangeNotifier {
  static final ActivePlaylistsService _instance = ActivePlaylistsService._internal();
  factory ActivePlaylistsService() => _instance;
  ActivePlaylistsService._internal();

  ActivePlaylistsConfig? _config;
  bool _isLoading = false;

  /// Get current configuration
  ActivePlaylistsConfig get config => _config ?? ActivePlaylistsConfig();

  /// Check if combined mode is enabled
  bool get isCombinedMode => _config?.isCombinedMode ?? false;

  /// Get set of active playlist IDs (backward compatible)
  Set<String> get activePlaylistIds => _config?.activePlaylistIdsSet ?? {};

  /// Get ordered list of active playlist IDs (first = highest priority)
  List<String> get orderedActivePlaylistIds => _config?.activePlaylistIds ?? [];

  /// Check if a specific playlist is active
  bool isPlaylistActive(String playlistId) {
    return _config?.activePlaylistIds.contains(playlistId) ?? false;
  }

  /// Get number of active playlists
  int get activeCount => _config?.activeCount ?? 0;

  /// Check if combined mode can be used (need 2+ playlists)
  bool get canUseCombinedMode => _config?.canUseCombinedMode ?? false;

  /// Load configuration from storage
  Future<void> loadConfiguration() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      _config = await UserPreferences.getActivePlaylistsConfig();
      debugPrint('ActivePlaylistsService: Loaded config - combined: ${_config?.isCombinedMode}, active: ${_config?.activePlaylistIds.length}');
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  /// Toggle a playlist's active state (adds to end if new)
  Future<void> togglePlaylistActive(String playlistId) async {
    final currentIds = List<String>.from(orderedActivePlaylistIds);
    if (currentIds.contains(playlistId)) {
      currentIds.remove(playlistId);
    } else {
      currentIds.add(playlistId); // Add to end (lowest priority)
    }

    _config = (_config ?? ActivePlaylistsConfig()).copyWith(
      activePlaylistIds: currentIds,
    );
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }

  /// Set a playlist as active (adds to end if new)
  Future<void> setPlaylistActive(String playlistId, bool active) async {
    final currentIds = List<String>.from(orderedActivePlaylistIds);
    if (active) {
      if (!currentIds.contains(playlistId)) {
        currentIds.add(playlistId); // Add to end (lowest priority)
      }
    } else {
      currentIds.remove(playlistId);
    }

    _config = (_config ?? ActivePlaylistsConfig()).copyWith(
      activePlaylistIds: currentIds,
    );
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }

  /// Set combined mode enabled/disabled
  Future<void> setCombinedMode(bool enabled) async {
    _config = (_config ?? ActivePlaylistsConfig()).copyWith(
      isCombinedMode: enabled,
    );
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }

  /// Set all active playlist IDs at once (preserves order)
  Future<void> setActivePlaylistIds(Set<String> ids) async {
    _config = (_config ?? ActivePlaylistsConfig()).copyWith(
      activePlaylistIds: ids.toList(),
    );
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }

  /// Set ordered active playlist IDs
  Future<void> setOrderedActivePlaylistIds(List<String> ids) async {
    _config = (_config ?? ActivePlaylistsConfig()).copyWith(
      activePlaylistIds: ids,
    );
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }

  /// Reorder a playlist from one position to another
  Future<void> reorderPlaylist(int oldIndex, int newIndex) async {
    if (_config == null) return;
    if (newIndex > oldIndex) newIndex--;

    _config = _config!.reorder(oldIndex, newIndex);
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }

  /// Clear all active playlists
  Future<void> clearActivePlaylists() async {
    _config = (_config ?? ActivePlaylistsConfig()).copyWith(
      activePlaylistIds: <String>[],
      isCombinedMode: false,
    );
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }

  /// Remove a playlist from active (e.g., when playlist is deleted)
  Future<void> removePlaylistFromActive(String playlistId) async {
    if (!isPlaylistActive(playlistId)) return;

    final currentIds = List<String>.from(orderedActivePlaylistIds);
    currentIds.remove(playlistId);

    // If less than 2 playlists, disable combined mode
    final shouldDisableCombined = currentIds.length < 2;

    _config = (_config ?? ActivePlaylistsConfig()).copyWith(
      activePlaylistIds: currentIds,
      isCombinedMode: shouldDisableCombined ? false : _config?.isCombinedMode,
    );
    await UserPreferences.setActivePlaylistsConfig(_config!);
    notifyListeners();
  }
}
