import 'package:flutter/foundation.dart';
import '../models/parental_control.dart';
import '../models/content_type.dart';
import '../models/playlist_content_model.dart';
import '../models/category.dart' as models;
import '../repositories/parental_control_repository.dart';
import 'event_bus.dart';

/// Service for managing parental controls and content filtering
class ParentalControlService extends ChangeNotifier {
  static final ParentalControlService _instance = ParentalControlService._internal();
  factory ParentalControlService() => _instance;
  ParentalControlService._internal();

  ParentalControlSettings _settings = const ParentalControlSettings();
  List<ParentalBlockedCategory> _blockedCategories = [];
  bool _isInitialized = false;

  ParentalControlSettings get settings => _settings;
  List<ParentalBlockedCategory> get blockedCategories => _blockedCategories;
  bool get isEnabled => _settings.enabled;
  bool get isUnlocked => _settings.isUnlocked;
  bool get hasPin => _settings.pin != null && _settings.pin!.isNotEmpty;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadSettings();
    _isInitialized = true;
  }

  /// Load settings from repository
  Future<void> _loadSettings() async {
    _settings = await ParentalControlRepository.getSettings();
    _blockedCategories = await ParentalControlRepository.getBlockedCategories();
    notifyListeners();
  }

  /// Refresh settings
  Future<void> refresh() async {
    await _loadSettings();
  }

  /// Enable parental controls
  Future<void> enable() async {
    await ParentalControlRepository.setEnabled(true);
    await _loadSettings();
    EventBus().emit('parental_controls_changed', true);
  }

  /// Disable parental controls
  Future<void> disable() async {
    await ParentalControlRepository.setEnabled(false);
    await _loadSettings();
    EventBus().emit('parental_controls_changed', false);
  }

  /// Set PIN
  Future<void> setPin(String pin) async {
    await ParentalControlRepository.setPin(pin);
    await _loadSettings();
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    return await ParentalControlRepository.verifyPin(pin);
  }

  /// Unlock (show parental content)
  Future<void> unlock() async {
    await ParentalControlRepository.unlock();
    await _loadSettings();
    EventBus().emit('parental_controls_unlocked', null);
  }

  /// Lock (hide parental content)
  Future<void> lock() async {
    await ParentalControlRepository.lock();
    await _loadSettings();
    EventBus().emit('parental_controls_locked', null);
  }

  /// Add a blocked keyword
  Future<void> addBlockedKeyword(String keyword) async {
    await ParentalControlRepository.addBlockedKeyword(keyword);
    await _loadSettings();
    EventBus().emit('parental_controls_changed', null);
  }

  /// Remove a blocked keyword
  Future<void> removeBlockedKeyword(String keyword) async {
    await ParentalControlRepository.removeBlockedKeyword(keyword);
    await _loadSettings();
    EventBus().emit('parental_controls_changed', null);
  }

  /// Add a blocked category
  Future<void> addBlockedCategory(String categoryId, String name, ContentType contentType) async {
    await ParentalControlRepository.addBlockedCategory(categoryId);

    final category = ParentalBlockedCategory(
      id: categoryId,
      name: name,
      contentType: contentType,
    );
    final categories = [..._blockedCategories];
    if (!categories.any((c) => c.id == categoryId)) {
      categories.add(category);
      await ParentalControlRepository.saveBlockedCategories(categories);
    }

    await _loadSettings();
    EventBus().emit('parental_controls_changed', null);
  }

  /// Remove a blocked category
  Future<void> removeBlockedCategory(String categoryId) async {
    await ParentalControlRepository.removeBlockedCategory(categoryId);

    final categories = _blockedCategories.where((c) => c.id != categoryId).toList();
    await ParentalControlRepository.saveBlockedCategories(categories);

    await _loadSettings();
    EventBus().emit('parental_controls_changed', null);
  }

  /// Get category ID from a ContentItem
  String? _getCategoryIdFromItem(ContentItem item) {
    // Try to get categoryId from the underlying stream objects
    if (item.liveStream != null) {
      return item.liveStream!.categoryId;
    } else if (item.vodStream != null) {
      return item.vodStream!.categoryId;
    } else if (item.seriesStream != null) {
      return item.seriesStream!.categoryId;
    } else if (item.m3uItem != null) {
      return item.m3uItem!.groupTitle;
    }
    return null;
  }

  /// Add a blocked item
  Future<void> addBlockedItem(ContentItem item) async {
    final blockedItem = ParentalBlockedItem(
      id: item.id,
      name: item.name,
      contentType: item.contentType,
      categoryId: _getCategoryIdFromItem(item),
      imagePath: item.imagePath,
    );
    await ParentalControlRepository.addBlockedItem(blockedItem);
    await _loadSettings();
    EventBus().emit('parental_controls_changed', null);
  }

  /// Remove a blocked item
  Future<void> removeBlockedItem(String id, ContentType contentType) async {
    await ParentalControlRepository.removeBlockedItem(id, contentType);
    await _loadSettings();
    EventBus().emit('parental_controls_changed', null);
  }

  /// Check if content should be hidden
  bool shouldHideContent(ContentItem item) {
    if (!_settings.enabled) return false;
    if (_settings.isUnlocked) return false;
    return isContentBlocked(item);
  }

  /// Check if content is blocked (regardless of unlock state)
  bool isContentBlocked(ContentItem item) {
    if (_settings.blockedItems.any((blocked) =>
        blocked.id == item.id && blocked.contentType == item.contentType)) {
      return true;
    }

    final categoryId = _getCategoryIdFromItem(item);
    if (categoryId != null &&
        _settings.blockedCategoryIds.contains(categoryId)) {
      return true;
    }

    final nameLower = item.name.toLowerCase();
    for (final keyword in _settings.blockedKeywords) {
      if (nameLower.contains(keyword.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// Check if a category should be hidden
  bool shouldHideCategory(String categoryId, String categoryName) {
    if (!_settings.enabled) return false;
    if (_settings.isUnlocked) return false;
    return isCategoryBlocked(categoryId, categoryName);
  }

  /// Check if a category is blocked
  bool isCategoryBlocked(String categoryId, String categoryName) {
    if (_settings.blockedCategoryIds.contains(categoryId)) {
      return true;
    }

    final nameLower = categoryName.toLowerCase();
    for (final keyword in _settings.blockedKeywords) {
      if (nameLower.contains(keyword.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// Filter a list of content items
  List<ContentItem> filterContent(List<ContentItem> items) {
    if (!_settings.enabled) return items;
    if (_settings.isUnlocked) return items;
    return items.where((item) => !isContentBlocked(item)).toList();
  }

  /// Filter a list of categories
  List<models.Category> filterCategories(List<models.Category> categories) {
    if (!_settings.enabled) return categories;
    if (_settings.isUnlocked) return categories;
    return categories
        .where((models.Category cat) => !isCategoryBlocked(cat.categoryId, cat.categoryName))
        .toList();
  }

  /// Get blocked content items
  List<ContentItem> getBlockedContent(List<ContentItem> allItems) {
    return allItems.where((item) => isContentBlocked(item)).toList();
  }

  /// Separate content into regular and blocked
  (List<ContentItem>, List<ContentItem>) separateContent(List<ContentItem> items) {
    if (!_settings.enabled) {
      return (items, []);
    }

    final regular = <ContentItem>[];
    final blocked = <ContentItem>[];

    for (final item in items) {
      if (isContentBlocked(item)) {
        blocked.add(item);
      } else {
        regular.add(item);
      }
    }

    return (regular, blocked);
  }

  /// Separate categories into regular and blocked
  (List<models.Category>, List<models.Category>) separateCategories(List<models.Category> categories) {
    if (!_settings.enabled) {
      return (categories, []);
    }

    final regular = <models.Category>[];
    final blocked = <models.Category>[];

    for (final category in categories) {
      if (isCategoryBlocked(category.categoryId, category.categoryName)) {
        blocked.add(category);
      } else {
        regular.add(category);
      }
    }

    return (regular, blocked);
  }

  /// Set lock timeout
  Future<void> setLockTimeout(int minutes) async {
    await ParentalControlRepository.setLockTimeout(minutes);
    await _loadSettings();
  }

  /// Clear all settings
  Future<void> clearAll() async {
    await ParentalControlRepository.clearAll();
    await _loadSettings();
    EventBus().emit('parental_controls_changed', null);
  }
}
