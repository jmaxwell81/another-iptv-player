import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_iptv_player/models/renaming_rule.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/models/category_configuration.dart';
import 'package:another_iptv_player/models/active_playlists_config.dart';
import 'package:another_iptv_player/models/parental_settings.dart';

class UserPreferences {
  static const String _keyLastPlaylist = 'last_playlist';
  static const String _keyVolume = 'volume';
  static const String _keyAudioTrack = 'audio_track';
  static const String _keySubtitleTrack = 'subtitle_track';
  static const String _keyVideoQuality = 'video_quality';
  static const String _keyBackgroundPlay = 'background_play';
  static const String _keySubtitleFontSize = 'subtitle_font_size';
  static const String _keySubtitleHeight = 'subtitle_height';
  static const String _keySubtitleLetterSpacing = 'subtitle_letter_spacing';
  static const String _keySubtitleWordSpacing = 'subtitle_word_spacing';
  static const String _keySubtitleTextColor = 'subtitle_text_color';
  static const String _keySubtitleBackgroundColor = 'subtitle_background_color';
  static const String _keySubtitleFontWeight = 'subtitle_font_weight';
  static const String _keySubtitleTextAlign = 'subtitle_text_align';
  static const String _keySubtitlePadding = 'subtitle_padding';
  static const String _keyLocale = 'locale';
  static const String _hiddenCategoriesKey = 'hidden_categories';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyBrightnessGesture = 'brightness_gesture';
  static const String _keyVolumeGesture = 'volume_gesture';
  static const String _keySeekGesture = 'seek_gesture';
  static const String _keySpeedUpOnLongPress = 'speed_up_on_long_press';
  static const String _keySeekOnDoubleTap = 'seek_on_double_tap';
  static const String _renamingRulesKey = 'renaming_rules';
  static const String _customRenamesKey = 'custom_renames';
  static const String _categoryConfigKey = 'category_configs';
  static const String _activePlaylistsConfigKey = 'active_playlists_config';
  static const String _tvGuideChannelLimitKey = 'tv_guide_channel_limit';
  static const String _favoritesOnlyCategoriesKey = 'favorites_only_categories';

  // TV Guide channel limit (default 100)
  static Future<void> setTvGuideChannelLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tvGuideChannelLimitKey, limit);
  }

  static Future<int> getTvGuideChannelLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tvGuideChannelLimitKey) ?? 100;
  }

  static Future<void> setLastPlaylist(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPlaylist, playlistId);
  }

  static Future<String?> getLastPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastPlaylist);
  }

  static Future<void> removeLastPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastPlaylist);
  }

  static Future<void> setVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVolume, volume);
  }

  static Future<double> getVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyVolume) ?? 100;
  }

  static Future<void> setAudioTrack(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioTrack, language);
  }

  static Future<String> getAudioTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAudioTrack) ?? 'auto';
  }

  static Future<void> setSubtitleTrack(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubtitleTrack, language);
  }

  static Future<String> getSubtitleTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySubtitleTrack) ?? 'auto';
  }

  static Future<void> setVideoTrack(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVideoQuality, id);
  }

  static Future<String> getVideoTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVideoQuality) ?? 'auto';
  }

  static Future<void> setBackgroundPlay(bool backgroundPlay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundPlay, backgroundPlay);
  }

  static Future<bool> getBackgroundPlay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundPlay) ?? true;
  }

  static Future<double> getSubtitleFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleFontSize) ?? 32.0;
  }

  static Future<void> setSubtitleFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleFontSize, fontSize);
  }

  static Future<double> getSubtitleHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleHeight) ?? 1.4;
  }

  static Future<void> setSubtitleHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleHeight, height);
  }

  static Future<double> getSubtitleLetterSpacing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleLetterSpacing) ?? 0.0;
  }

  static Future<void> setSubtitleLetterSpacing(double letterSpacing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleLetterSpacing, letterSpacing);
  }

  static Future<double> getSubtitleWordSpacing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitleWordSpacing) ?? 0.0;
  }

  static Future<void> setSubtitleWordSpacing(double wordSpacing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitleWordSpacing, wordSpacing);
  }

  static Future<Color> getSubtitleTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_keySubtitleTextColor) ?? 0xffffffff;
    return Color(colorValue);
  }

  static Future<void> setSubtitleTextColor(Color textColor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubtitleTextColor, textColor.value);
  }

  static Future<Color> getSubtitleBackgroundColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_keySubtitleBackgroundColor) ?? 0xaa000000;
    return Color(colorValue);
  }

  static Future<void> setSubtitleBackgroundColor(Color backgroundColor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubtitleBackgroundColor, backgroundColor.value);
  }

  static Future<FontWeight> getSubtitleFontWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final weightIndex =
        prefs.getInt(_keySubtitleFontWeight) ?? FontWeight.normal.index;
    return FontWeight.values[weightIndex];
  }

  static Future<void> setSubtitleFontWeight(FontWeight fontWeight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubtitleFontWeight, fontWeight.index);
  }

  static Future<TextAlign> getSubtitleTextAlign() async {
    final prefs = await SharedPreferences.getInstance();
    final alignIndex =
        prefs.getInt(_keySubtitleTextAlign) ?? TextAlign.center.index;
    return TextAlign.values[alignIndex];
  }

  static Future<void> setSubtitleTextAlign(TextAlign textAlign) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubtitleTextAlign, textAlign.index);
  }

  static Future<double> getSubtitlePadding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySubtitlePadding) ?? 24.0;
  }

  static Future<void> setSubtitlePadding(double padding) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubtitlePadding, padding);
  }

  static Future<String?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale);
  }

  static Future<void> setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale);
  }

  static Future<void> removeLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocale);
  }

  static Future<void> setHiddenCategories(List<String> categoryIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenCategoriesKey, categoryIds);
  }

  static Future<bool> getHiddenCategory(String categoryId) async {
    final hidden = await getHiddenCategories();
    return hidden.contains(categoryId);
  }

  static Future<List<String>> getHiddenCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenCategoriesKey) ?? [];
  }

  static Future<void> toggleHiddenCategory(String categoryId) async {
    final hidden = await getHiddenCategories();
    if (hidden.contains(categoryId)) {
      hidden.remove(categoryId);
    } else {
      hidden.add(categoryId);
    }
    await setHiddenCategories(hidden);
  }

  static Future<void> hideCategory(String categoryId) async {
    final hidden = await getHiddenCategories();
    if (!hidden.contains(categoryId)) {
      hidden.add(categoryId);
      await setHiddenCategories(hidden);
    }
  }

  static Future<void> unhideCategory(String categoryId) async {
    final hidden = await getHiddenCategories();
    if (hidden.contains(categoryId)) {
      hidden.remove(categoryId);
      await setHiddenCategories(hidden);
    }
  }

  // Hidden category names (for cross-source matching in unified mode)
  static const String _hiddenCategoryNamesKey = 'hidden_category_names';

  /// Get hidden category names (normalized: lowercase, trimmed)
  static Future<List<String>> getHiddenCategoryNames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenCategoryNamesKey) ?? [];
  }

  /// Set hidden category names
  static Future<void> setHiddenCategoryNames(List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenCategoryNamesKey, names);
  }

  /// Hide a category by ID and name (for cross-source matching)
  static Future<void> hideCategoryWithName(String categoryId, String categoryName) async {
    // Save ID
    final hiddenIds = await getHiddenCategories();
    if (!hiddenIds.contains(categoryId)) {
      hiddenIds.add(categoryId);
      await setHiddenCategories(hiddenIds);
    }
    // Save normalized name
    final normalizedName = categoryName.toLowerCase().trim();
    final hiddenNames = await getHiddenCategoryNames();
    if (!hiddenNames.contains(normalizedName)) {
      hiddenNames.add(normalizedName);
      await setHiddenCategoryNames(hiddenNames);
    }
  }

  /// Unhide a category by ID and name
  static Future<void> unhideCategoryWithName(String categoryId, String categoryName) async {
    // Remove ID
    final hiddenIds = await getHiddenCategories();
    if (hiddenIds.contains(categoryId)) {
      hiddenIds.remove(categoryId);
      await setHiddenCategories(hiddenIds);
    }
    // Remove normalized name
    final normalizedName = categoryName.toLowerCase().trim();
    final hiddenNames = await getHiddenCategoryNames();
    if (hiddenNames.contains(normalizedName)) {
      hiddenNames.remove(normalizedName);
      await setHiddenCategoryNames(hiddenNames);
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.toString().split('.').last);
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_keyThemeMode) ?? 'system';
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  // Player gesture settings
  static Future<bool> getBrightnessGesture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBrightnessGesture) ?? false;
  }

  static Future<void> setBrightnessGesture(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBrightnessGesture, value);
  }

  static Future<bool> getVolumeGesture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVolumeGesture) ?? false;
  }

  static Future<void> setVolumeGesture(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVolumeGesture, value);
  }

  static Future<bool> getSeekGesture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeekGesture) ?? false;
  }

  static Future<void> setSeekGesture(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeekGesture, value);
  }

  static Future<bool> getSpeedUpOnLongPress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySpeedUpOnLongPress) ?? true;
  }

  static Future<void> setSpeedUpOnLongPress(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpeedUpOnLongPress, value);
  }

  static Future<bool> getSeekOnDoubleTap() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeekOnDoubleTap) ?? true;
  }

  static Future<void> setSeekOnDoubleTap(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeekOnDoubleTap, value);
  }

  // Renaming Rules
  static Future<List<RenamingRule>> getRenamingRules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_renamingRulesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => RenamingRule.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> setRenamingRules(List<RenamingRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = rules.map((rule) => rule.toJson()).toList();
    await prefs.setString(_renamingRulesKey, jsonEncode(jsonList));
  }

  static Future<void> addRenamingRule(RenamingRule rule) async {
    final rules = await getRenamingRules();
    rules.add(rule);
    await setRenamingRules(rules);
  }

  static Future<void> updateRenamingRule(RenamingRule updatedRule) async {
    final rules = await getRenamingRules();
    final index = rules.indexWhere((r) => r.id == updatedRule.id);
    if (index != -1) {
      rules[index] = updatedRule;
      await setRenamingRules(rules);
    }
  }

  static Future<void> deleteRenamingRule(String ruleId) async {
    final rules = await getRenamingRules();
    rules.removeWhere((r) => r.id == ruleId);
    await setRenamingRules(rules);
  }

  static Future<void> toggleRenamingRule(String ruleId) async {
    final rules = await getRenamingRules();
    final index = rules.indexWhere((r) => r.id == ruleId);
    if (index != -1) {
      rules[index] = rules[index].copyWith(isEnabled: !rules[index].isEnabled);
      await setRenamingRules(rules);
    }
  }

  // Custom Renames (individual item renames)
  static Future<List<CustomRename>> getCustomRenames() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_customRenamesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      return CustomRename.listFromJson(jsonString);
    } catch (e) {
      return [];
    }
  }

  static Future<void> setCustomRenames(List<CustomRename> renames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customRenamesKey, CustomRename.listToJson(renames));
  }

  static Future<void> setCustomRename(CustomRename rename) async {
    final renames = await getCustomRenames();
    final index = renames.indexWhere((r) => r.id == rename.id);
    if (index != -1) {
      renames[index] = rename;
    } else {
      renames.add(rename);
    }
    await setCustomRenames(renames);
  }

  static Future<void> removeCustomRename(String renameId) async {
    final renames = await getCustomRenames();
    renames.removeWhere((r) => r.id == renameId);
    await setCustomRenames(renames);
  }

  static Future<CustomRename?> getCustomRename(String renameId) async {
    final renames = await getCustomRenames();
    try {
      return renames.firstWhere((r) => r.id == renameId);
    } catch (e) {
      return null;
    }
  }

  // Category Configuration (merge/order)
  static Future<Map<String, CategoryConfig>> getCategoryConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_categoryConfigKey);
    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }
    try {
      return CategoryConfig.configsFromJson(jsonString);
    } catch (e) {
      return {};
    }
  }

  static Future<void> setCategoryConfigs(Map<String, CategoryConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoryConfigKey, CategoryConfig.configsToJson(configs));
  }

  static Future<CategoryConfig?> getCategoryConfig(String playlistId) async {
    final configs = await getCategoryConfigs();
    return configs[playlistId];
  }

  static Future<void> setCategoryConfig(CategoryConfig config) async {
    final configs = await getCategoryConfigs();
    configs[config.playlistId] = config;
    await setCategoryConfigs(configs);
  }

  static Future<void> removeCategoryConfig(String playlistId) async {
    final configs = await getCategoryConfigs();
    configs.remove(playlistId);
    await setCategoryConfigs(configs);
  }

  // Active Playlists Configuration (combined mode)
  static Future<ActivePlaylistsConfig> getActivePlaylistsConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_activePlaylistsConfigKey);
    if (jsonString == null || jsonString.isEmpty) {
      return ActivePlaylistsConfig();
    }
    try {
      return ActivePlaylistsConfig.fromJsonString(jsonString);
    } catch (e) {
      return ActivePlaylistsConfig();
    }
  }

  static Future<void> setActivePlaylistsConfig(ActivePlaylistsConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activePlaylistsConfigKey, config.toJsonString());
  }

  static Future<Set<String>> getActivePlaylistIds() async {
    final config = await getActivePlaylistsConfig();
    return config.activePlaylistIdsSet;
  }

  static Future<void> setActivePlaylistIds(Set<String> ids) async {
    final config = await getActivePlaylistsConfig();
    await setActivePlaylistsConfig(config.copyWith(activePlaylistIds: ids.toList()));
  }

  static Future<bool> isCombinedModeEnabled() async {
    final config = await getActivePlaylistsConfig();
    return config.isCombinedMode;
  }

  static Future<void> setCombinedModeEnabled(bool enabled) async {
    final config = await getActivePlaylistsConfig();
    await setActivePlaylistsConfig(config.copyWith(isCombinedMode: enabled));
  }

  static Future<void> togglePlaylistActive(String playlistId) async {
    final config = await getActivePlaylistsConfig();
    final newIds = List<String>.from(config.activePlaylistIds);
    if (newIds.contains(playlistId)) {
      newIds.remove(playlistId);
    } else {
      newIds.add(playlistId);
    }
    await setActivePlaylistsConfig(config.copyWith(activePlaylistIds: newIds));
  }

  // Background refresh settings
  static const String _keyAutoRefreshEnabled = 'auto_refresh_enabled';
  static const String _keyAutoRefreshInterval = 'auto_refresh_interval_hours';
  static const String _keyLastRefreshTime = 'last_refresh_time';

  static Future<void> setAutoRefreshEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoRefreshEnabled, enabled);
  }

  static Future<bool> getAutoRefreshEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoRefreshEnabled) ?? false;
  }

  static Future<void> setAutoRefreshInterval(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoRefreshInterval, hours);
  }

  static Future<int> getAutoRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAutoRefreshInterval) ?? 24; // Default 24 hours
  }

  static Future<void> setLastRefreshTime(String playlistId, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyLastRefreshTime}_$playlistId', time.toIso8601String());
  }

  static Future<DateTime?> getLastRefreshTime(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('${_keyLastRefreshTime}_$playlistId');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // Source health monitoring settings
  static const String _keySourceErrorThreshold = 'source_error_threshold';
  static const String _keySourceErrorWindowMinutes = 'source_error_window_minutes';
  static const String _keyShowStreamErrors = 'show_stream_errors';

  static Future<void> setSourceErrorThreshold(int threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySourceErrorThreshold, threshold);
  }

  static Future<int> getSourceErrorThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySourceErrorThreshold) ?? 3; // Default 3 errors
  }

  static Future<void> setSourceErrorWindowMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySourceErrorWindowMinutes, minutes);
  }

  static Future<int> getSourceErrorWindowMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySourceErrorWindowMinutes) ?? 2; // Default 2 minutes
  }

  static Future<void> setShowStreamErrors(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowStreamErrors, show);
  }

  static Future<bool> getShowStreamErrors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowStreamErrors) ?? true; // Default true
  }

  // VPN Detection settings
  static const String _keyVpnCheckEnabled = 'vpn_check_enabled';
  static const String _keyVpnKillSwitchEnabled = 'vpn_kill_switch_enabled';
  static const String _keyVpnCheckIntervalMinutes = 'vpn_check_interval_minutes';
  static const String _keyVpnStatusPosition = 'vpn_status_position';
  static const String _keyVpnStatusOpacity = 'vpn_status_opacity';
  static const String _keyVpnShowOnlyWhenDisconnected = 'vpn_show_only_when_disconnected';
  static const String _keyVpnTargetCountry = 'vpn_target_country';
  static const String _keyVpnStatusOffsetX = 'vpn_status_offset_x';
  static const String _keyVpnStatusOffsetY = 'vpn_status_offset_y';

  static Future<void> setVpnCheckEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVpnCheckEnabled, enabled);
  }

  static Future<bool> getVpnCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVpnCheckEnabled) ?? false; // Default disabled
  }

  static Future<void> setVpnKillSwitchEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVpnKillSwitchEnabled, enabled);
  }

  static Future<bool> getVpnKillSwitchEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVpnKillSwitchEnabled) ?? false; // Default disabled
  }

  static Future<void> setVpnCheckIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVpnCheckIntervalMinutes, minutes);
  }

  static Future<int> getVpnCheckIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVpnCheckIntervalMinutes) ?? 5; // Default 5 minutes
  }

  /// Position: 0 = bottom-left, 1 = bottom-right, 2 = top-left, 3 = top-right
  static Future<void> setVpnStatusPosition(int position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVpnStatusPosition, position);
  }

  static Future<int> getVpnStatusPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVpnStatusPosition) ?? 0; // Default bottom-left
  }

  static Future<void> setVpnStatusOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVpnStatusOpacity, opacity);
  }

  static Future<double> getVpnStatusOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyVpnStatusOpacity) ?? 0.5; // Default 50%
  }

  static Future<void> setVpnShowOnlyWhenDisconnected(bool showOnly) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVpnShowOnlyWhenDisconnected, showOnly);
  }

  static Future<bool> getVpnShowOnlyWhenDisconnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVpnShowOnlyWhenDisconnected) ?? false; // Default false
  }

  /// Set the target country for VPN detection (ISO 3166-1 alpha-2 code, e.g., 'US', 'GB', 'DE')
  /// When set, VPN is considered "enabled" if the detected country doesn't match this target.
  static Future<void> setVpnTargetCountry(String? countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (countryCode == null || countryCode.isEmpty) {
      await prefs.remove(_keyVpnTargetCountry);
    } else {
      await prefs.setString(_keyVpnTargetCountry, countryCode.toUpperCase());
    }
  }

  /// Get the target country for VPN detection (null means no country-based check)
  static Future<String?> getVpnTargetCountry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVpnTargetCountry);
  }

  /// Set VPN status X offset (horizontal distance from corner)
  static Future<void> setVpnStatusOffsetX(double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVpnStatusOffsetX, offset);
  }

  /// Get VPN status X offset (default: 16)
  static Future<double> getVpnStatusOffsetX() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyVpnStatusOffsetX) ?? 16.0;
  }

  /// Set VPN status Y offset (vertical distance from corner)
  static Future<void> setVpnStatusOffsetY(double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVpnStatusOffsetY, offset);
  }

  /// Get VPN status Y offset (default: 16)
  static Future<double> getVpnStatusOffsetY() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyVpnStatusOffsetY) ?? 16.0;
  }

  // Download settings
  static const String _keyMaxConcurrentDownloads = 'max_concurrent_downloads';
  static const String _keyDownloads = 'downloads';
  static const String _keyRecordings = 'recordings';

  static Future<void> setMaxConcurrentDownloads(int max) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxConcurrentDownloads, max);
  }

  static Future<int> getMaxConcurrentDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMaxConcurrentDownloads) ?? 1; // Default 1
  }

  static Future<void> saveDownloads(List<dynamic> downloads) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = downloads.map((d) => d.toJson()).toList();
    await prefs.setString(_keyDownloads, jsonEncode(jsonList));
  }

  static Future<List<dynamic>> getDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyDownloads);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      // Import Download model dynamically to avoid circular dependency
      return jsonList;
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveRecordings(List<dynamic> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = recordings.map((r) => r.toJson()).toList();
    await prefs.setString(_keyRecordings, jsonEncode(jsonList));
  }

  static Future<List<dynamic>> getRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyRecordings);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList;
    } catch (e) {
      return [];
    }
  }

  // Parental control settings
  static const String _keyParentalSettings = 'parental_settings';
  static const String _keyCatchUpUrls = 'catch_up_urls';

  static Future<void> setParentalSettings(ParentalSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyParentalSettings, settings.toJsonString());
  }

  static Future<ParentalSettings> getParentalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyParentalSettings);
    if (jsonString == null || jsonString.isEmpty) {
      return ParentalSettings();
    }
    try {
      return ParentalSettings.fromJsonString(jsonString);
    } catch (e) {
      return ParentalSettings();
    }
  }

  // Catch Up URL configuration per playlist
  static Future<void> setCatchUpUrl(String playlistId, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyCatchUpUrls) ?? '{}';
    final Map<String, dynamic> urls = jsonDecode(jsonString);
    urls[playlistId] = url;
    await prefs.setString(_keyCatchUpUrls, jsonEncode(urls));
  }

  static Future<String?> getCatchUpUrl(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyCatchUpUrls);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> urls = jsonDecode(jsonString);
      return urls[playlistId] as String?;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, String>> getAllCatchUpUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyCatchUpUrls);
    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }
    try {
      final Map<String, dynamic> urls = jsonDecode(jsonString);
      return urls.map((key, value) => MapEntry(key, value as String));
    } catch (e) {
      return {};
    }
  }

  // Timeshift recordings storage
  static const String _keyTimeshiftRecordings = 'timeshift_recordings';

  static Future<void> setTimeshiftRecordings(List<Map<String, dynamic>> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimeshiftRecordings, jsonEncode(recordings));
  }

  static Future<List<Map<String, dynamic>>> getTimeshiftRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyTimeshiftRecordings);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // Default panel setting (which panel to navigate to on app launch)
  // Values: 'history', 'favorites', 'live', 'tv_guide', 'movies', 'series', 'settings'
  static const String _keyDefaultPanel = 'default_panel';

  static Future<void> setDefaultPanel(String panel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultPanel, panel);
  }

  static Future<String> getDefaultPanel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultPanel) ?? 'live'; // Default to Live Streams
  }

  // Timeshift enabled setting
  static const String _keyTimeshiftEnabled = 'timeshift_enabled';

  static Future<void> setTimeshiftEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTimeshiftEnabled, enabled);
  }

  static Future<bool> getTimeshiftEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTimeshiftEnabled) ?? true; // Enabled by default
  }

  // Timeshift max buffer duration in minutes
  static const String _keyTimeshiftMaxBuffer = 'timeshift_max_buffer';

  static Future<void> setTimeshiftMaxBuffer(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimeshiftMaxBuffer, minutes);
  }

  static Future<int> getTimeshiftMaxBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTimeshiftMaxBuffer) ?? 30; // Default 30 minutes
  }

  // Custom FFmpeg path for timeshift
  static const String _keyCustomFfmpegPath = 'custom_ffmpeg_path';

  static Future<void> setCustomFfmpegPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_keyCustomFfmpegPath);
    } else {
      await prefs.setString(_keyCustomFfmpegPath, path);
    }
  }

  static Future<String?> getCustomFfmpegPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomFfmpegPath);
  }

  // External API keys for subtitles and movie details
  static const String _keyOpenSubtitlesApiKey = 'opensubtitles_api_key';
  static const String _keyOpenSubtitlesUsername = 'opensubtitles_username';
  static const String _keyOpenSubtitlesPassword = 'opensubtitles_password';
  static const String _keyTmdbApiKey = 'tmdb_api_key';
  static const String _keyPreferredSubtitleLanguage = 'preferred_subtitle_language';
  static const String _keyAutoDownloadSubtitles = 'auto_download_subtitles';
  static const String _keySubtitleDownloadPath = 'subtitle_download_path';

  // OpenSubtitles API key (free registration at opensubtitles.com)
  static Future<void> setOpenSubtitlesApiKey(String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_keyOpenSubtitlesApiKey);
    } else {
      await prefs.setString(_keyOpenSubtitlesApiKey, apiKey);
    }
  }

  static Future<String?> getOpenSubtitlesApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOpenSubtitlesApiKey);
  }

  // OpenSubtitles username (optional, increases rate limit)
  static Future<void> setOpenSubtitlesUsername(String? username) async {
    final prefs = await SharedPreferences.getInstance();
    if (username == null || username.isEmpty) {
      await prefs.remove(_keyOpenSubtitlesUsername);
    } else {
      await prefs.setString(_keyOpenSubtitlesUsername, username);
    }
  }

  static Future<String?> getOpenSubtitlesUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOpenSubtitlesUsername);
  }

  // OpenSubtitles password
  static Future<void> setOpenSubtitlesPassword(String? password) async {
    final prefs = await SharedPreferences.getInstance();
    if (password == null || password.isEmpty) {
      await prefs.remove(_keyOpenSubtitlesPassword);
    } else {
      await prefs.setString(_keyOpenSubtitlesPassword, password);
    }
  }

  static Future<String?> getOpenSubtitlesPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOpenSubtitlesPassword);
  }

  // TMDB API key (free registration at themoviedb.org)
  static Future<void> setTmdbApiKey(String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_keyTmdbApiKey);
    } else {
      await prefs.setString(_keyTmdbApiKey, apiKey);
    }
  }

  static Future<String?> getTmdbApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTmdbApiKey);
  }

  // Preferred subtitle language (ISO 639-1 code, e.g., 'en', 'es', 'fr')
  static Future<void> setPreferredSubtitleLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreferredSubtitleLanguage, language);
  }

  static Future<String> getPreferredSubtitleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPreferredSubtitleLanguage) ?? 'en';
  }

  // Auto-download subtitles when playing movies/series
  static Future<void> setAutoDownloadSubtitles(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoDownloadSubtitles, enabled);
  }

  static Future<bool> getAutoDownloadSubtitles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoDownloadSubtitles) ?? false;
  }

  // Custom subtitle download path
  static Future<void> setSubtitleDownloadPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_keySubtitleDownloadPath);
    } else {
      await prefs.setString(_keySubtitleDownloadPath, path);
    }
  }

  static Future<String?> getSubtitleDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySubtitleDownloadPath);
  }

  // Content Consolidation/Deduplication settings
  static const String _keyConsolidationEnabled = 'consolidation_enabled';
  static const String _keyPreferredContentQuality = 'preferred_content_quality';
  static const String _keyPreferredContentLanguage = 'preferred_content_language';

  /// Enable/disable content consolidation (default: true)
  static Future<void> setConsolidationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsolidationEnabled, enabled);
  }

  static Future<bool> getConsolidationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsolidationEnabled) ?? true;
  }

  /// Set preferred content quality for source selection
  /// Stored as index of ContentQuality enum
  static Future<void> setPreferredContentQuality(dynamic quality) async {
    final prefs = await SharedPreferences.getInstance();
    // Store as string name for safety across enum changes
    await prefs.setString(_keyPreferredContentQuality, quality.toString().split('.').last);
  }

  /// Get preferred content quality (returns null if not set)
  /// Returns a ContentQuality value
  static Future<dynamic> getPreferredContentQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyPreferredContentQuality);
    if (value == null) return null;

    // Map string back to quality - imported dynamically to avoid circular imports
    switch (value) {
      case 'uhd4k':
        return _ContentQualityHelper.uhd4k;
      case 'hd1080p':
        return _ContentQualityHelper.hd1080p;
      case 'hd720p':
        return _ContentQualityHelper.hd720p;
      case 'sd':
        return _ContentQualityHelper.sd;
      default:
        return _ContentQualityHelper.hd1080p; // Default fallback
    }
  }

  /// Set preferred content language (ISO 639-1 code, e.g., 'en', 'tr', 'es')
  static Future<void> setPreferredContentLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreferredContentLanguage, language.toLowerCase());
  }

  /// Get preferred content language (default: 'en')
  static Future<String> getPreferredContentLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPreferredContentLanguage) ?? 'en';
  }

  // Favorites from Hidden Categories settings
  static const String _keyHiddenFavoritesCategoryName = 'hidden_favorites_category_name';
  static const String _keyShowHiddenFavoritesCategory = 'show_hidden_favorites_category';

  /// Get the name of the "Favorites from Hidden Categories" category
  static Future<String> getHiddenFavoritesCategoryName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHiddenFavoritesCategoryName) ?? 'Favorites';
  }

  /// Set the name of the "Favorites from Hidden Categories" category
  static Future<void> setHiddenFavoritesCategoryName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHiddenFavoritesCategoryName, name);
  }

  /// Get whether to show the hidden favorites category
  static Future<bool> getShowHiddenFavoritesCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowHiddenFavoritesCategory) ?? true;
  }

  /// Set whether to show the hidden favorites category
  static Future<void> setShowHiddenFavoritesCategory(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowHiddenFavoritesCategory, show);
  }

  // Live Recording Jobs storage
  static const String _keyRecordingJobs = 'recording_jobs';

  static Future<void> setRecordingJobs(List<Map<String, dynamic>> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecordingJobs, jsonEncode(jobs));
  }

  static Future<List<Map<String, dynamic>>> getRecordingJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyRecordingJobs);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // Favorites-only categories - show only favorited items in these categories
  /// Get list of category IDs that should show only favorites
  static Future<List<String>> getFavoritesOnlyCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesOnlyCategoriesKey) ?? [];
  }

  /// Set list of category IDs that should show only favorites
  static Future<void> setFavoritesOnlyCategories(List<String> categoryIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesOnlyCategoriesKey, categoryIds);
  }

  /// Check if a category is set to show only favorites
  static Future<bool> isFavoritesOnlyCategory(String categoryId) async {
    final favOnly = await getFavoritesOnlyCategories();
    return favOnly.contains(categoryId);
  }

  /// Toggle favorites-only mode for a category
  static Future<void> toggleFavoritesOnlyCategory(String categoryId) async {
    final favOnly = await getFavoritesOnlyCategories();
    if (favOnly.contains(categoryId)) {
      favOnly.remove(categoryId);
    } else {
      favOnly.add(categoryId);
    }
    await setFavoritesOnlyCategories(favOnly);
  }

  /// Enable favorites-only mode for a category
  static Future<void> setFavoritesOnly(String categoryId) async {
    final favOnly = await getFavoritesOnlyCategories();
    if (!favOnly.contains(categoryId)) {
      favOnly.add(categoryId);
      await setFavoritesOnlyCategories(favOnly);
    }
  }

  /// Disable favorites-only mode for a category
  static Future<void> clearFavoritesOnly(String categoryId) async {
    final favOnly = await getFavoritesOnlyCategories();
    if (favOnly.contains(categoryId)) {
      favOnly.remove(categoryId);
      await setFavoritesOnlyCategories(favOnly);
    }
  }

  // Category preview settings
  static const String _keyCategoryPreviewLimit = 'category_preview_limit';

  /// Get the number of items to show per category on the main page
  /// Default is 15, configurable by user
  static Future<int> getCategoryPreviewLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCategoryPreviewLimit) ?? 15;
  }

  /// Set the number of items to show per category on the main page
  static Future<void> setCategoryPreviewLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCategoryPreviewLimit, limit);
  }

  // Pinned categories - categories that should appear at the top of the list
  static const String _keyPinnedCategories = 'pinned_categories';

  /// Get list of pinned category IDs in order (first = top)
  static Future<List<String>> getPinnedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyPinnedCategories) ?? [];
  }

  /// Set list of pinned category IDs
  static Future<void> setPinnedCategories(List<String> categoryIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPinnedCategories, categoryIds);
  }

  /// Pin a category to the top (or move it to the very top if already pinned)
  static Future<void> pinCategoryToTop(String categoryId) async {
    final pinned = await getPinnedCategories();
    // Remove if already exists to avoid duplicates
    pinned.remove(categoryId);
    // Insert at the beginning (top)
    pinned.insert(0, categoryId);
    await setPinnedCategories(pinned);
  }

  /// Unpin a category (remove from pinned list)
  static Future<void> unpinCategory(String categoryId) async {
    final pinned = await getPinnedCategories();
    pinned.remove(categoryId);
    await setPinnedCategories(pinned);
  }

  /// Check if a category is pinned
  static Future<bool> isCategoryPinned(String categoryId) async {
    final pinned = await getPinnedCategories();
    return pinned.contains(categoryId);
  }

  // Demoted categories - categories that should appear at the bottom of the list
  static const String _keyDemotedCategories = 'demoted_categories';

  /// Get list of demoted category IDs (shown at bottom)
  static Future<List<String>> getDemotedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyDemotedCategories) ?? [];
  }

  /// Set list of demoted category IDs
  static Future<void> setDemotedCategories(List<String> categoryIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDemotedCategories, categoryIds);
  }

  /// Demote a category to the bottom
  static Future<void> demoteCategoryToBottom(String categoryId) async {
    // Remove from pinned if it was pinned
    await unpinCategory(categoryId);

    final demoted = await getDemotedCategories();
    // Remove if already exists to avoid duplicates
    demoted.remove(categoryId);
    // Add to the end (bottom)
    demoted.add(categoryId);
    await setDemotedCategories(demoted);
  }

  /// Undemote a category (remove from demoted list)
  static Future<void> undemoteCategory(String categoryId) async {
    final demoted = await getDemotedCategories();
    demoted.remove(categoryId);
    await setDemotedCategories(demoted);
  }

  /// Check if a category is demoted
  static Future<bool> isCategoryDemoted(String categoryId) async {
    final demoted = await getDemotedCategories();
    return demoted.contains(categoryId);
  }

  // Offline Stream settings
  static const String _keyOfflineStreamTempHideHours = 'offline_stream_temp_hide_hours';
  static const String _keyAutoOfflineEnabled = 'auto_offline_enabled';
  static const String _keyAutoOfflineTimeoutSeconds = 'auto_offline_timeout_seconds';

  /// Get temporary offline hide duration in hours (default: 48)
  static Future<int> getOfflineStreamTempHideHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOfflineStreamTempHideHours) ?? 48;
  }

  /// Set temporary offline hide duration in hours
  static Future<void> setOfflineStreamTempHideHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOfflineStreamTempHideHours, hours);
  }

  /// Get whether auto-offline detection is enabled (default: false)
  static Future<bool> getAutoOfflineEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoOfflineEnabled) ?? false;
  }

  /// Set whether auto-offline detection is enabled
  static Future<void> setAutoOfflineEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoOfflineEnabled, enabled);
  }

  /// Get auto-offline detection timeout in seconds (default: 10)
  static Future<int> getAutoOfflineTimeoutSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAutoOfflineTimeoutSeconds) ?? 10;
  }

  /// Set auto-offline detection timeout in seconds
  static Future<void> setAutoOfflineTimeoutSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoOfflineTimeoutSeconds, seconds);
  }

  // New Releases section settings
  static const String _keyShowNewReleases = 'show_new_releases';
  static const String _keyNewReleasesLookbackDays = 'new_releases_lookback_days';

  /// Get whether to show the "New Releases" section (default: true)
  static Future<bool> getShowNewReleases() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowNewReleases) ?? true;
  }

  /// Set whether to show the "New Releases" section
  static Future<void> setShowNewReleases(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowNewReleases, show);
  }

  /// Get the lookback period for "New Releases" in days (default: 7)
  static Future<int> getNewReleasesLookbackDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNewReleasesLookbackDays) ?? 7;
  }

  /// Set the lookback period for "New Releases" in days
  static Future<void> setNewReleasesLookbackDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNewReleasesLookbackDays, days);
  }
}

/// Helper class to avoid importing content_source_link.dart
/// which could cause circular dependencies
class _ContentQualityHelper {
  static const int uhd4k = 0;
  static const int hd1080p = 1;
  static const int hd720p = 2;
  static const int sd = 3;
}
