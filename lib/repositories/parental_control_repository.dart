import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parental_control.dart';
import '../models/content_type.dart';

class ParentalControlRepository {
  static const String _keySettings = 'parental_control_settings';
  static const String _keyBlockedCategories = 'parental_blocked_categories';

  /// Get parental control settings
  static Future<ParentalControlSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keySettings);
    if (json == null) {
      return const ParentalControlSettings();
    }
    try {
      return ParentalControlSettings.fromJson(jsonDecode(json));
    } catch (e) {
      return const ParentalControlSettings();
    }
  }

  /// Save parental control settings
  static Future<void> saveSettings(ParentalControlSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  /// Enable/disable parental controls
  static Future<void> setEnabled(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(enabled: enabled));
  }

  /// Set PIN
  static Future<void> setPin(String pin) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(pin: pin));
  }

  /// Verify PIN
  static Future<bool> verifyPin(String pin) async {
    final settings = await getSettings();
    return settings.pin == pin;
  }

  /// Unlock parental controls (after PIN verification)
  static Future<void> unlock() async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(lastUnlockTime: DateTime.now()));
  }

  /// Lock parental controls
  static Future<void> lock() async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(lastUnlockTime: null));
  }

  /// Check if currently unlocked
  static Future<bool> isUnlocked() async {
    final settings = await getSettings();
    return settings.isUnlocked;
  }

  /// Add a blocked keyword
  static Future<void> addBlockedKeyword(String keyword) async {
    final settings = await getSettings();
    if (!settings.blockedKeywords.contains(keyword.toLowerCase())) {
      final newKeywords = [...settings.blockedKeywords, keyword.toLowerCase()];
      await saveSettings(settings.copyWith(blockedKeywords: newKeywords));
    }
  }

  /// Remove a blocked keyword
  static Future<void> removeBlockedKeyword(String keyword) async {
    final settings = await getSettings();
    final newKeywords = settings.blockedKeywords
        .where((k) => k != keyword.toLowerCase())
        .toList();
    await saveSettings(settings.copyWith(blockedKeywords: newKeywords));
  }

  /// Get blocked keywords
  static Future<List<String>> getBlockedKeywords() async {
    final settings = await getSettings();
    return settings.blockedKeywords;
  }

  /// Add a blocked category
  static Future<void> addBlockedCategory(String categoryId) async {
    final settings = await getSettings();
    if (!settings.blockedCategoryIds.contains(categoryId)) {
      final newIds = [...settings.blockedCategoryIds, categoryId];
      await saveSettings(settings.copyWith(blockedCategoryIds: newIds));
    }
  }

  /// Remove a blocked category
  static Future<void> removeBlockedCategory(String categoryId) async {
    final settings = await getSettings();
    final newIds = settings.blockedCategoryIds
        .where((id) => id != categoryId)
        .toList();
    await saveSettings(settings.copyWith(blockedCategoryIds: newIds));
  }

  /// Get blocked category IDs
  static Future<List<String>> getBlockedCategoryIds() async {
    final settings = await getSettings();
    return settings.blockedCategoryIds;
  }

  /// Add a blocked item
  static Future<void> addBlockedItem(ParentalBlockedItem item) async {
    final settings = await getSettings();
    if (!settings.blockedItems.contains(item)) {
      final newItems = [...settings.blockedItems, item];
      await saveSettings(settings.copyWith(blockedItems: newItems));
    }
  }

  /// Remove a blocked item
  static Future<void> removeBlockedItem(String id, ContentType contentType) async {
    final settings = await getSettings();
    final newItems = settings.blockedItems
        .where((item) => !(item.id == id && item.contentType == contentType))
        .toList();
    await saveSettings(settings.copyWith(blockedItems: newItems));
  }

  /// Get blocked items
  static Future<List<ParentalBlockedItem>> getBlockedItems() async {
    final settings = await getSettings();
    return settings.blockedItems;
  }

  /// Check if an item is blocked
  static Future<bool> isItemBlocked(String id, ContentType contentType) async {
    final settings = await getSettings();
    return settings.blockedItems.any(
      (item) => item.id == id && item.contentType == contentType,
    );
  }

  /// Check if a category is blocked
  static Future<bool> isCategoryBlocked(String categoryId) async {
    final settings = await getSettings();
    return settings.blockedCategoryIds.contains(categoryId);
  }

  /// Set lock timeout in minutes
  static Future<void> setLockTimeout(int minutes) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(lockTimeoutMinutes: minutes));
  }

  /// Save blocked categories with metadata
  static Future<void> saveBlockedCategories(List<ParentalBlockedCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(categories.map((c) => c.toJson()).toList());
    await prefs.setString(_keyBlockedCategories, json);
  }

  /// Get blocked categories with metadata
  static Future<List<ParentalBlockedCategory>> getBlockedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyBlockedCategories);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => ParentalBlockedCategory.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear all parental control settings
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySettings);
    await prefs.remove(_keyBlockedCategories);
  }
}
