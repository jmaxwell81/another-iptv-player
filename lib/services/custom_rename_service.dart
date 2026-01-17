import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// Service for managing custom renames for individual items
/// Uses a singleton pattern with caching for performance
class CustomRenameService {
  static final CustomRenameService _instance = CustomRenameService._internal();
  factory CustomRenameService() => _instance;
  CustomRenameService._internal();

  Map<String, CustomRename>? _cachedRenames;
  bool _isLoading = false;

  /// Load and cache custom renames from storage
  Future<void> loadRenames() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final renames = await UserPreferences.getCustomRenames();
      _cachedRenames = {for (var r in renames) r.id: r};
      debugPrint('CustomRenameService: Loaded ${_cachedRenames?.length ?? 0} custom renames');
    } finally {
      _isLoading = false;
    }
  }

  /// Clear the cache (call after renames are modified)
  void invalidateCache() {
    _cachedRenames = null;
  }

  /// Get custom name for an item, returns null if no custom name exists
  String? getCustomName(CustomRenameType type, String itemId, String? playlistId) {
    if (_cachedRenames == null) {
      // Cache not loaded yet - schedule a load for next time
      loadRenames();
      return null;
    }

    final id = CustomRename.generateId(type, itemId, playlistId);
    final rename = _cachedRenames?[id];
    return rename?.customName;
  }

  /// Get custom name synchronously (returns null if not found or cache not loaded)
  String? getCustomNameSync(CustomRenameType type, String itemId, String? playlistId) {
    if (_cachedRenames == null) {
      loadRenames();
      return null;
    }
    final id = CustomRename.generateId(type, itemId, playlistId);
    return _cachedRenames?[id]?.customName;
  }

  /// Set a custom name for an item
  Future<void> setCustomName({
    required CustomRenameType type,
    required String itemId,
    required String originalName,
    required String customName,
    String? playlistId,
  }) async {
    final id = CustomRename.generateId(type, itemId, playlistId);
    final rename = CustomRename(
      id: id,
      originalName: originalName,
      customName: customName,
      type: type,
      itemId: itemId,
      playlistId: playlistId,
    );

    await UserPreferences.setCustomRename(rename);
    invalidateCache();
    await loadRenames();
  }

  /// Remove a custom name for an item
  Future<void> removeCustomName(CustomRenameType type, String itemId, String? playlistId) async {
    final id = CustomRename.generateId(type, itemId, playlistId);
    await UserPreferences.removeCustomRename(id);
    invalidateCache();
    await loadRenames();
  }

  /// Check if an item has a custom name
  bool hasCustomName(CustomRenameType type, String itemId, String? playlistId) {
    if (_cachedRenames == null) return false;
    final id = CustomRename.generateId(type, itemId, playlistId);
    return _cachedRenames?.containsKey(id) ?? false;
  }

  /// Get the original name for a custom renamed item
  String? getOriginalName(CustomRenameType type, String itemId, String? playlistId) {
    if (_cachedRenames == null) return null;
    final id = CustomRename.generateId(type, itemId, playlistId);
    return _cachedRenames?[id]?.originalName;
  }

  /// Get all custom renames (async)
  Future<List<CustomRename>> getAllRenames() async {
    if (_cachedRenames == null) {
      await loadRenames();
    }
    return _cachedRenames?.values.toList() ?? [];
  }
}
