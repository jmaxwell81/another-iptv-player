import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:another_iptv_player/models/language_country_mapping.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/content_normalization_service.dart';

/// Service for managing content filtering based on patterns, language, and categories.
class ContentFilterService {
  static final ContentFilterService _instance = ContentFilterService._internal();
  factory ContentFilterService() => _instance;
  ContentFilterService._internal();

  static const String _keyFilterRules = 'content_filter_rules';
  static const String _keyHiddenCategories = 'hidden_categories';
  static const String _keyLanguageFilter = 'language_filter_settings';
  static const String _keyUserMappings = 'user_language_mappings';

  // Cached data
  List<ContentFilterRule> _filterRules = [];
  Set<String> _hiddenCategoryIds = {};
  LanguageFilterSettings _languageSettings = LanguageFilterSettings();
  List<LanguageCountryMapping> _userMappings = [];
  bool _isInitialized = false;

  final _normalizationService = ContentNormalizationService();
  final _uuid = const Uuid();

  /// Initialize the service and load saved settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadFilterRules();
    await _loadHiddenCategories();
    await _loadLanguageSettings();
    await _loadUserMappings();

    // Apply user mappings to normalization service
    _normalizationService.setUserMappings(_userMappings);

    _isInitialized = true;
  }

  // ==================== Filter Rules ====================

  /// Get all filter rules
  List<ContentFilterRule> get filterRules => List.unmodifiable(_filterRules);

  /// Add a new filter rule
  Future<ContentFilterRule> addFilterRule({
    required String pattern,
    bool isRegex = false,
    bool hideMatching = true,
    bool appliesToCategories = false,
    bool appliesToContent = true,
    Set<String>? categoryIds,
  }) async {
    final rule = ContentFilterRule(
      id: _uuid.v4(),
      pattern: pattern,
      isRegex: isRegex,
      hideMatching: hideMatching,
      appliesToCategories: appliesToCategories,
      appliesToContent: appliesToContent,
      categoryIds: categoryIds,
    );

    _filterRules.add(rule);
    await _saveFilterRules();
    return rule;
  }

  /// Update an existing filter rule
  Future<void> updateFilterRule(ContentFilterRule rule) async {
    final index = _filterRules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _filterRules[index] = rule;
      await _saveFilterRules();
    }
  }

  /// Remove a filter rule
  Future<void> removeFilterRule(String ruleId) async {
    _filterRules.removeWhere((r) => r.id == ruleId);
    await _saveFilterRules();
  }

  /// Toggle a filter rule enabled/disabled
  Future<void> toggleFilterRule(String ruleId) async {
    final index = _filterRules.indexWhere((r) => r.id == ruleId);
    if (index >= 0) {
      _filterRules[index] = _filterRules[index].copyWith(
        isEnabled: !_filterRules[index].isEnabled,
      );
      await _saveFilterRules();
    }
  }

  /// Check if content should be hidden based on filter rules
  bool shouldHideContent(String name, {String? categoryId}) {
    for (final rule in _filterRules) {
      if (!rule.isEnabled || !rule.appliesToContent) continue;

      // Check if rule applies to this category
      if (rule.categoryIds != null &&
          categoryId != null &&
          !rule.categoryIds!.contains(categoryId)) {
        continue;
      }

      if (rule.matches(name)) {
        return rule.hideMatching;
      }
    }
    return false;
  }

  /// Check if a category should be hidden based on filter rules
  bool shouldHideCategory(String categoryName, String categoryId) {
    // Check explicit category hiding first
    if (_hiddenCategoryIds.contains(categoryId)) {
      return true;
    }

    // Check pattern-based category rules
    for (final rule in _filterRules) {
      if (!rule.isEnabled || !rule.appliesToCategories) continue;

      if (rule.matches(categoryName)) {
        return rule.hideMatching;
      }
    }
    return false;
  }

  /// Get all content items matching a pattern (for preview before hiding)
  List<ContentItem> getMatchingItems(
    String pattern,
    List<ContentItem> items, {
    bool isRegex = false,
  }) {
    final rule = ContentFilterRule(
      id: 'preview',
      pattern: pattern,
      isRegex: isRegex,
    );

    return items.where((item) => rule.matches(item.name)).toList();
  }

  /// Bulk hide items matching a pattern
  Future<ContentFilterRule> bulkHideByPattern(
    String pattern, {
    bool isRegex = false,
    Set<String>? categoryIds,
  }) async {
    return addFilterRule(
      pattern: pattern,
      isRegex: isRegex,
      hideMatching: true,
      appliesToContent: true,
      categoryIds: categoryIds,
    );
  }

  // ==================== Hidden Categories ====================

  /// Get all hidden category IDs
  Set<String> get hiddenCategoryIds => Set.unmodifiable(_hiddenCategoryIds);

  /// Hide a category
  Future<void> hideCategory(String categoryId) async {
    _hiddenCategoryIds.add(categoryId);
    await _saveHiddenCategories();
  }

  /// Unhide a category
  Future<void> unhideCategory(String categoryId) async {
    _hiddenCategoryIds.remove(categoryId);
    await _saveHiddenCategories();
  }

  /// Toggle category visibility
  Future<void> toggleCategoryVisibility(String categoryId) async {
    if (_hiddenCategoryIds.contains(categoryId)) {
      _hiddenCategoryIds.remove(categoryId);
    } else {
      _hiddenCategoryIds.add(categoryId);
    }
    await _saveHiddenCategories();
  }

  /// Check if a category is hidden
  bool isCategoryHidden(String categoryId) {
    return _hiddenCategoryIds.contains(categoryId);
  }

  // ==================== Language Filtering ====================

  /// Get current language filter settings
  LanguageFilterSettings get languageSettings => _languageSettings;

  /// Update language filter settings
  Future<void> updateLanguageSettings(LanguageFilterSettings settings) async {
    _languageSettings = settings;
    await _saveLanguageSettings();
  }

  /// Filter content by language preference
  List<ContentItem> filterByLanguage(List<ContentItem> items) {
    if (!_languageSettings.enabled) return items;
    if (_languageSettings.preferredLanguages.isEmpty) return items;

    return items.where((item) {
      final detectedLanguage = _normalizationService.extractLanguage(item.name);

      // If no language detected and we're set to hide unknown, hide it
      if (detectedLanguage == null) {
        return !_languageSettings.hideUnknownLanguage;
      }

      // Check if the detected language is in our preferred list
      return _languageSettings.preferredLanguages.contains(detectedLanguage.toLowerCase());
    }).toList();
  }

  /// Check if content matches language preferences
  bool contentMatchesLanguagePreference(String name) {
    if (!_languageSettings.enabled) return true;
    if (_languageSettings.preferredLanguages.isEmpty) return true;

    final detectedLanguage = _normalizationService.extractLanguage(name);

    if (detectedLanguage == null) {
      return !_languageSettings.hideUnknownLanguage;
    }

    return _languageSettings.preferredLanguages.contains(detectedLanguage.toLowerCase());
  }

  // ==================== User Mappings ====================

  /// Get user-defined language/country mappings
  List<LanguageCountryMapping> get userMappings => List.unmodifiable(_userMappings);

  /// Add a user-defined mapping
  Future<void> addUserMapping(LanguageCountryMapping mapping) async {
    _userMappings.removeWhere((m) => m.tag.toUpperCase() == mapping.tag.toUpperCase());
    _userMappings.add(mapping);
    _normalizationService.addUserMapping(mapping);
    await _saveUserMappings();
  }

  /// Remove a user-defined mapping
  Future<void> removeUserMapping(String tag) async {
    _userMappings.removeWhere((m) => m.tag.toUpperCase() == tag.toUpperCase());
    _normalizationService.removeUserMapping(tag);
    await _saveUserMappings();
  }

  /// Get all mappings (built-in + user-defined)
  List<LanguageCountryMapping> getAllMappings() {
    return _normalizationService.getAllMappings();
  }

  // ==================== Apply All Filters ====================

  /// Apply all active filters to a list of content items
  List<ContentItem> applyFilters(List<ContentItem> items, {String? categoryId}) {
    var filtered = items;

    // Apply language filter
    if (_languageSettings.enabled) {
      filtered = filterByLanguage(filtered);
    }

    // Apply content filter rules
    filtered = filtered.where((item) {
      return !shouldHideContent(item.name, categoryId: categoryId);
    }).toList();

    return filtered;
  }

  /// Apply all active filters but preserve favorited items.
  /// If a category is hidden but contains favorites, return only the favorites.
  /// [favoriteItemIds] is a set of item IDs that are favorited.
  List<ContentItem> applyFiltersWithFavorites(
    List<ContentItem> items, {
    String? categoryId,
    required Set<String> favoriteItemIds,
  }) {
    // First, check if the category itself is hidden
    // If category is hidden, only return favorited items from it
    // If category is not hidden, apply normal filters but preserve favorites

    var filtered = items;

    // Apply language filter (but preserve favorites)
    if (_languageSettings.enabled) {
      filtered = filtered.where((item) {
        // Always keep favorites
        if (favoriteItemIds.contains(item.id)) return true;
        // Apply language filter to non-favorites
        return contentMatchesLanguagePreference(item.name);
      }).toList();
    }

    // Apply content filter rules (but preserve favorites)
    filtered = filtered.where((item) {
      // Always keep favorites
      if (favoriteItemIds.contains(item.id)) return true;
      // Apply content filters to non-favorites
      return !shouldHideContent(item.name, categoryId: categoryId);
    }).toList();

    return filtered;
  }

  /// Get items from a hidden category that are favorited
  List<ContentItem> getFavoritesFromHiddenCategory(
    List<ContentItem> items,
    Set<String> favoriteItemIds,
  ) {
    return items.where((item) => favoriteItemIds.contains(item.id)).toList();
  }

  // ==================== Persistence ====================

  Future<void> _loadFilterRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyFilterRules);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _filterRules = list.map((e) => ContentFilterRule.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('ContentFilterService: Error loading filter rules: $e');
    }
  }

  Future<void> _saveFilterRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_filterRules.map((r) => r.toJson()).toList());
      await prefs.setString(_keyFilterRules, json);
    } catch (e) {
      debugPrint('ContentFilterService: Error saving filter rules: $e');
    }
  }

  Future<void> _loadHiddenCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyHiddenCategories);
      if (list != null) {
        _hiddenCategoryIds = list.toSet();
      }
    } catch (e) {
      debugPrint('ContentFilterService: Error loading hidden categories: $e');
    }
  }

  Future<void> _saveHiddenCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyHiddenCategories, _hiddenCategoryIds.toList());
    } catch (e) {
      debugPrint('ContentFilterService: Error saving hidden categories: $e');
    }
  }

  Future<void> _loadLanguageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyLanguageFilter);
      if (json != null) {
        _languageSettings = LanguageFilterSettings.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('ContentFilterService: Error loading language settings: $e');
    }
  }

  Future<void> _saveLanguageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_languageSettings.toJson());
      await prefs.setString(_keyLanguageFilter, json);
    } catch (e) {
      debugPrint('ContentFilterService: Error saving language settings: $e');
    }
  }

  Future<void> _loadUserMappings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyUserMappings);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _userMappings = list.map((e) => LanguageCountryMapping.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('ContentFilterService: Error loading user mappings: $e');
    }
  }

  Future<void> _saveUserMappings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_userMappings.map((m) => m.toJson()).toList());
      await prefs.setString(_keyUserMappings, json);
    } catch (e) {
      debugPrint('ContentFilterService: Error saving user mappings: $e');
    }
  }

  /// Clear all filters and settings
  Future<void> clearAll() async {
    _filterRules.clear();
    _hiddenCategoryIds.clear();
    _languageSettings = LanguageFilterSettings();
    _userMappings.clear();

    await _saveFilterRules();
    await _saveHiddenCategories();
    await _saveLanguageSettings();
    await _saveUserMappings();

    _normalizationService.setUserMappings([]);
  }
}

/// Settings for language-based content filtering
class LanguageFilterSettings {
  final bool enabled;
  final Set<String> preferredLanguages;
  final bool hideUnknownLanguage;

  LanguageFilterSettings({
    this.enabled = false,
    Set<String>? preferredLanguages,
    this.hideUnknownLanguage = false,
  }) : preferredLanguages = preferredLanguages ?? {};

  factory LanguageFilterSettings.fromJson(Map<String, dynamic> json) {
    return LanguageFilterSettings(
      enabled: json['enabled'] as bool? ?? false,
      preferredLanguages: json['preferredLanguages'] != null
          ? Set<String>.from(json['preferredLanguages'] as List)
          : {},
      hideUnknownLanguage: json['hideUnknownLanguage'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'preferredLanguages': preferredLanguages.toList(),
      'hideUnknownLanguage': hideUnknownLanguage,
    };
  }

  LanguageFilterSettings copyWith({
    bool? enabled,
    Set<String>? preferredLanguages,
    bool? hideUnknownLanguage,
  }) {
    return LanguageFilterSettings(
      enabled: enabled ?? this.enabled,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      hideUnknownLanguage: hideUnknownLanguage ?? this.hideUnknownLanguage,
    );
  }
}
