import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/parental_settings.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// Service for managing parental controls
/// When parentModeActive is false, adult/locked content is hidden
/// When parentModeActive is true, all content is visible
class ParentalControlService extends ChangeNotifier {
  static final ParentalControlService _instance = ParentalControlService._internal();
  factory ParentalControlService() => _instance;
  ParentalControlService._internal();

  ParentalSettings _settings = ParentalSettings();
  bool _parentModeActive = false;
  bool _isInitialized = false;

  ParentalSettings get settings => _settings;
  bool get parentModeActive => _parentModeActive;
  bool get isEnabled => _settings.isEnabled;
  bool get isInitialized => _isInitialized;

  /// Initialize the service by loading settings
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadSettings();
    _isInitialized = true;
  }

  Future<void> _loadSettings() async {
    _settings = await UserPreferences.getParentalSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await UserPreferences.setParentalSettings(_settings);
    notifyListeners();
  }

  /// Verify PIN and enter parent mode if correct
  bool verifyPin(String enteredPin) {
    if (enteredPin == _settings.pin) {
      _parentModeActive = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Exit parent mode (re-enable content filtering)
  void exitParentMode() {
    _parentModeActive = false;
    notifyListeners();
  }

  /// Change the PIN (requires current PIN verification)
  Future<bool> changePin(String currentPin, String newPin) async {
    if (currentPin != _settings.pin) return false;
    if (newPin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(newPin)) return false;

    _settings = _settings.copyWith(pin: newPin);
    await _saveSettings();
    return true;
  }

  /// Reset PIN to default (0000) - emergency reset
  Future<void> resetPinToDefault() async {
    _settings = _settings.copyWith(pin: '0000');
    await _saveSettings();
  }

  /// Enable or disable parental controls entirely
  Future<void> setEnabled(bool enabled) async {
    _settings = _settings.copyWith(isEnabled: enabled);
    await _saveSettings();
  }

  /// Enable or disable auto-lock for adult content
  Future<void> setAutoLockAdultContent(bool autoLock) async {
    _settings = _settings.copyWith(autoLockAdultContent: autoLock);
    await _saveSettings();
  }

  /// Add a keyword to the blocked list
  Future<void> addBlockedKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final keywords = List<String>.from(_settings.blockedKeywords);
    final lowerKeyword = keyword.toLowerCase().trim();
    if (!keywords.any((k) => k.toLowerCase() == lowerKeyword)) {
      keywords.add(keyword.trim());
      _settings = _settings.copyWith(blockedKeywords: keywords);
      await _saveSettings();
    }
  }

  /// Remove a keyword from the blocked list
  Future<void> removeBlockedKeyword(String keyword) async {
    final keywords = List<String>.from(_settings.blockedKeywords);
    keywords.removeWhere((k) => k.toLowerCase() == keyword.toLowerCase());
    _settings = _settings.copyWith(blockedKeywords: keywords);
    await _saveSettings();
  }

  /// Reset keywords to default adult content keywords
  Future<void> resetKeywordsToDefault() async {
    _settings = _settings.copyWith(
      blockedKeywords: List.from(ParentalSettings.defaultAdultKeywords),
    );
    await _saveSettings();
  }

  /// Lock a specific category
  Future<void> lockCategory(String categoryId) async {
    final locked = Set<String>.from(_settings.lockedCategoryIds);
    locked.add(categoryId);
    _settings = _settings.copyWith(lockedCategoryIds: locked);
    await _saveSettings();
  }

  /// Unlock a specific category
  Future<void> unlockCategory(String categoryId) async {
    final locked = Set<String>.from(_settings.lockedCategoryIds);
    locked.remove(categoryId);
    _settings = _settings.copyWith(lockedCategoryIds: locked);
    await _saveSettings();
  }

  /// Lock a specific content item
  Future<void> lockContent(String contentId) async {
    final locked = Set<String>.from(_settings.lockedContentIds);
    locked.add(contentId);
    _settings = _settings.copyWith(lockedContentIds: locked);
    await _saveSettings();
  }

  /// Unlock a specific content item
  Future<void> unlockContent(String contentId) async {
    final locked = Set<String>.from(_settings.lockedContentIds);
    locked.remove(contentId);
    _settings = _settings.copyWith(lockedContentIds: locked);
    await _saveSettings();
  }

  /// Check if content is locked (returns true if content should be hidden)
  bool isContentLocked(String contentId) {
    return _settings.lockedContentIds.contains(contentId);
  }

  /// Check if category is locked
  bool isCategoryLocked(String categoryId) {
    return _settings.lockedCategoryIds.contains(categoryId);
  }

  /// Check if content should be hidden based on current mode and settings
  /// Returns true if content should be HIDDEN
  bool shouldHideContent({
    required String contentId,
    required String contentName,
    String? categoryId,
    String? categoryName,
  }) {
    // If parental controls are disabled, nothing is hidden
    if (!_settings.isEnabled) return false;

    // If parent mode is active, nothing is hidden
    if (_parentModeActive) return false;

    // Check if content should be hidden
    return _settings.shouldHideContent(
      contentId: contentId,
      contentName: contentName,
      categoryId: categoryId,
      categoryName: categoryName,
    );
  }

  /// Check if a category should be hidden
  bool shouldHideCategory(String categoryId, String categoryName) {
    if (!_settings.isEnabled) return false;
    if (_parentModeActive) return false;

    // Check if category is manually locked
    if (_settings.isCategoryLocked(categoryId)) return true;

    // Check keyword matches
    if (_settings.isCategoryBlocked(categoryName)) return true;

    return false;
  }

  /// Filter a list of content items, removing those that should be hidden
  List<T> filterContent<T>(
    List<T> items, {
    required String Function(T) getId,
    required String Function(T) getName,
    String? Function(T)? getCategoryId,
    String? Function(T)? getCategoryName,
  }) {
    if (!_settings.isEnabled || _parentModeActive) return items;

    return items.where((item) {
      return !shouldHideContent(
        contentId: getId(item),
        contentName: getName(item),
        categoryId: getCategoryId?.call(item),
        categoryName: getCategoryName?.call(item),
      );
    }).toList();
  }

  /// Get list of all blocked keywords
  List<String> get blockedKeywords => List.unmodifiable(_settings.blockedKeywords);

  /// Get count of manually locked categories
  int get lockedCategoryCount => _settings.lockedCategoryIds.length;

  /// Get count of manually locked content items
  int get lockedContentCount => _settings.lockedContentIds.length;
}
