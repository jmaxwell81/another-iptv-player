import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auto_combine_rule.dart';
import '../models/category_view_model.dart';
import '../models/category.dart' as category_model;
import '../models/playlist_content_model.dart';

/// Service for managing auto-combine category rules
class AutoCombineService {
  static const String _configKey = 'auto_combine_config';

  static final AutoCombineService _instance = AutoCombineService._internal();
  factory AutoCombineService() => _instance;
  AutoCombineService._internal();

  AutoCombineConfig _config = const AutoCombineConfig();
  bool _initialized = false;

  AutoCombineConfig get config => _config;
  bool get isEnabled => _config.enabled;

  /// Initialize the service by loading saved configuration
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);

      if (configJson != null) {
        _config = AutoCombineConfig.fromJson(jsonDecode(configJson));
      }

      _initialized = true;
      // debugPrint('AutoCombineService: Initialized with enabled=${_config.enabled}');
    } catch (e) {
      // debugPrint('AutoCombineService: Error loading config: $e');
      _config = const AutoCombineConfig();
      _initialized = true;
    }
  }

  /// Save the current configuration
  Future<void> saveConfig(AutoCombineConfig config) async {
    _config = config;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(config.toJson()));
      // debugPrint('AutoCombineService: Saved config');
    } catch (e) {
      // debugPrint('AutoCombineService: Error saving config: $e');
    }
  }

  /// Update a specific setting
  Future<void> updateConfig({
    bool? enabled,
    bool? mergeKidsCategories,
    bool? mergeGenreCategories,
    bool? hideNonEnglishCountries,
    bool? consolidateLiveChannels,
    List<String>? englishSpeakingCountries,
  }) async {
    final newConfig = _config.copyWith(
      enabled: enabled,
      mergeKidsCategories: mergeKidsCategories,
      mergeGenreCategories: mergeGenreCategories,
      hideNonEnglishCountries: hideNonEnglishCountries,
      consolidateLiveChannels: consolidateLiveChannels,
      englishSpeakingCountries: englishSpeakingCountries,
    );
    await saveConfig(newConfig);
  }

  /// Apply auto-combine rules to a list of categories
  /// Returns a new list with merged categories and hidden categories removed
  List<CategoryViewModel> applyRules(List<CategoryViewModel> categories) {
    if (!_config.enabled || categories.isEmpty) {
      // debugPrint('AutoCombineService: Rules disabled or no categories (enabled=${_config.enabled}, count=${categories.length})');
      return categories;
    }

    // debugPrint('AutoCombineService: Applying rules - hideNonEnglish=${_config.hideNonEnglishCountries}, mergeKids=${_config.mergeKidsCategories}, mergeGenre=${_config.mergeGenreCategories}, consolidateChannels=${_config.consolidateLiveChannels}');

    var result = List<CategoryViewModel>.from(categories);

    // First, hide non-English country categories if enabled
    if (_config.hideNonEnglishCountries) {
      // debugPrint('AutoCombineService: Filtering non-English content (English countries: ${_config.englishSpeakingCountries.join(", ")})');
      final beforeCatCount = result.length;
      result = _hideNonEnglishCategories(result);
      // debugPrint('AutoCombineService: Hid ${beforeCatCount - result.length} non-English categories');
      // Also filter non-English items within remaining categories
      result = _filterNonEnglishItems(result);
    } else {
      // debugPrint('AutoCombineService: NOTE - hideNonEnglishCountries is DISABLED. Enable in Settings to filter non-English content.');
    }

    // Then merge KIDS categories if enabled
    if (_config.mergeKidsCategories) {
      result = _mergeByKeyword(result, ['KIDS', 'KIDZ', 'CHILDREN', 'ENFANTS', 'KINDER', 'FEMIJET', 'COCUK', 'NIÑOS'], 'KIDS');
    }

    // Then merge genre categories if enabled
    if (_config.mergeGenreCategories) {
      result = _mergeGenreCategories(result);
    }

    // Apply custom rules
    for (final rule in _config.customRules.where((r) => r.enabled)) {
      if (rule.type == AutoCombineRuleType.mergeByKeyword && rule.targetCategoryName != null) {
        result = _mergeByKeyword(result, rule.patterns, rule.targetCategoryName!);
      } else if (rule.type == AutoCombineRuleType.hideByCountry) {
        result = _hideByPatterns(result, rule.patterns);
      }
    }

    // Finally, consolidate live channels if enabled
    if (_config.consolidateLiveChannels) {
      result = _consolidateLiveChannels(result);
    }

    // Final pass: if hideNonEnglishCountries is enabled, filter items again
    // This ensures merged categories don't contain non-English items
    if (_config.hideNonEnglishCountries) {
      // debugPrint('AutoCombineService: Final pass - filtering non-English items from merged categories');
      result = _filterNonEnglishItems(result);
    }

    return result;
  }

  /// Filter non-English items from all categories
  List<CategoryViewModel> _filterNonEnglishItems(List<CategoryViewModel> categories) {
    int totalFiltered = 0;
    final filteredExamples = <String>[];

    final filtered = categories.map((category) {
      final originalCount = category.contentItems.length;
      final filteredItems = <ContentItem>[];

      for (final item in category.contentItems) {
        if (_isNonEnglishContentItem(item.name)) {
          totalFiltered++;
          if (filteredExamples.length < 10) {
            filteredExamples.add(item.name);
          }
        } else {
          filteredItems.add(item);
        }
      }

      if (filteredItems.length == originalCount) {
        return category; // No change
      }

      // Return category with filtered items
      return CategoryViewModel(
        category: category.category,
        contentItems: filteredItems,
        consolidatedItems: category.consolidatedItems,
      );
    }).where((cat) => cat.contentItems.isNotEmpty).toList(); // Remove empty categories

    if (totalFiltered > 0) {
      // debugPrint('AutoCombineService: Filtered $totalFiltered non-English items from ${categories.length} categories');
      // debugPrint('AutoCombineService: Sample filtered items: ${filteredExamples.join(", ")}');
    } else {
      // debugPrint('AutoCombineService: No non-English items found to filter (checked ${categories.fold<int>(0, (sum, cat) => sum + cat.contentItems.length)} items)');
    }

    return filtered;
  }

  /// Consolidate live channels by known channel names
  /// Groups variants like "CBS HD", "CBS SD", "CBS 4K" into a single entry
  List<CategoryViewModel> _consolidateLiveChannels(List<CategoryViewModel> categories) {
    return categories.map((category) {
      // Consolidate duplicate channels within the category
      final consolidatedItems = _consolidateChannelItems(category.contentItems);

      if (consolidatedItems.length == category.contentItems.length) {
        return category; // No consolidation needed
      }

      // debugPrint('AutoCombineService: Consolidated ${category.contentItems.length} items to ${consolidatedItems.length} in "${category.category.categoryName}"');

      // Return category with consolidated items
      return CategoryViewModel(
        category: category.category,
        contentItems: consolidatedItems,
        consolidatedItems: category.consolidatedItems,
      );
    }).toList();
  }

  /// Consolidate channel items by detecting known channel names
  /// Returns one item per unique channel (preferring HD/4K versions)
  List<ContentItem> _consolidateChannelItems(List<ContentItem> items) {
    if (items.isEmpty) return items;

    // Group items by detected channel name
    final channelGroups = <String, List<ContentItem>>{};
    final ungroupedItems = <ContentItem>[];

    for (final item in items) {
      final channelName = _detectChannelName(item.name);
      if (channelName != null) {
        channelGroups.putIfAbsent(channelName, () => []).add(item);
      } else {
        ungroupedItems.add(item);
      }
    }

    // For each channel group, pick the best variant
    final consolidatedItems = <ContentItem>[];

    for (final entry in channelGroups.entries) {
      if (entry.value.length == 1) {
        // Only one item, no consolidation needed
        consolidatedItems.add(entry.value.first);
      } else {
        // Multiple variants - pick the best one (prefer HD/4K, then first)
        final bestItem = _pickBestChannelVariant(entry.value);
        consolidatedItems.add(bestItem);
      }
    }

    // Add ungrouped items
    consolidatedItems.addAll(ungroupedItems);

    return consolidatedItems;
  }

  /// Detect if an item name contains a known channel name
  /// Returns the canonical channel name if found, null otherwise
  String? _detectChannelName(String itemName) {
    final upperName = itemName.toUpperCase();

    // Sort channel names by length (descending) to match longer names first
    // e.g., "ESPN NEWS" before "ESPN"
    final sortedChannels = List<String>.from(AutoCombineConfig.knownChannelNames)
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final channelName in sortedChannels) {
      final upperChannel = channelName.toUpperCase();

      // Check if the item name starts with or contains the channel name
      // with word boundaries (space, |, -, start/end)
      final patterns = [
        RegExp('^$upperChannel(\\s|\\||\\-|\$)', caseSensitive: false),
        RegExp('(\\s|\\||\\-)$upperChannel(\\s|\\||\\-|\$)', caseSensitive: false),
      ];

      for (final pattern in patterns) {
        if (pattern.hasMatch(upperName)) {
          return channelName; // Return canonical name
        }
      }

      // Also check for exact match or channel at start
      if (upperName == upperChannel ||
          upperName.startsWith('$upperChannel ') ||
          upperName.startsWith('$upperChannel|') ||
          upperName.startsWith('$upperChannel-')) {
        return channelName;
      }
    }

    return null;
  }

  /// Pick the best variant from multiple channel items
  /// Prefers: 4K > FHD/1080 > HD/720 > SD > others
  ContentItem _pickBestChannelVariant(List<ContentItem> items) {
    if (items.length == 1) return items.first;

    // Score each item based on quality indicators
    int scoreItem(ContentItem item) {
      final upperName = item.name.toUpperCase();

      // 4K/UHD is best
      if (upperName.contains('4K') || upperName.contains('UHD') || upperName.contains('2160')) {
        return 100;
      }
      // FHD/1080p
      if (upperName.contains('FHD') || upperName.contains('1080')) {
        return 80;
      }
      // HD/720p
      if (upperName.contains(' HD') || upperName.contains('|HD') ||
          upperName.contains('-HD') || upperName.contains('720')) {
        return 60;
      }
      // SD
      if (upperName.contains(' SD') || upperName.contains('|SD') ||
          upperName.contains('-SD') || upperName.contains('480')) {
        return 40;
      }
      // HEVC/H265 (efficient codec, usually good quality)
      if (upperName.contains('HEVC') || upperName.contains('H265') || upperName.contains('H.265')) {
        return 70;
      }

      return 50; // Default score
    }

    // Sort by score (descending) and return the best
    final scored = items.map((item) => MapEntry(item, scoreItem(item))).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.first.key;
  }

  /// Check if a category should be hidden based on rules
  bool shouldHideCategory(String categoryName) {
    if (!_config.enabled || !_config.hideNonEnglishCountries) {
      return false;
    }

    return _isNonEnglishCountryCategory(categoryName);
  }

  /// Hide categories that match non-English speaking country patterns
  List<CategoryViewModel> _hideNonEnglishCategories(List<CategoryViewModel> categories) {
    return categories.where((cat) => !_isNonEnglishCountryCategory(cat.category.categoryName)).toList();
  }

  /// Check if a category is for a non-English speaking country
  /// Returns true if the category should be hidden (is non-English)
  bool _isNonEnglishCountryCategory(String categoryName) {
    final upperName = categoryName.toUpperCase().trim();

    // Special check: filter any content containing "FR" (France/French) as a code
    // This catches categories like "CA FR", "AM FR", "CANADA FR" which are French Canadian
    if (_containsFrenchLanguageCode(upperName)) {
      return true;
    }

    // Special check for ASIA (AS prefix)
    if (_isAsiaContent(upperName)) {
      return true;
    }

    // Special check for AM (Americas) - filter if followed by non-English country
    if (_isNonEnglishAmericas(upperName)) {
      return true;
    }

    // Check for English country + non-English language patterns FIRST
    // e.g., "CA FR" = Canada French, "UK AR" = UK Arabic, etc.
    if (_isEnglishCountryWithNonEnglishLanguage(upperName)) {
      return true;
    }

    // Build a set of uppercase English-speaking codes for quick lookup
    final englishCodes = _config.englishSpeakingCountries
        .map((e) => e.toUpperCase())
        .toSet();

    // First check if it's an English-speaking country - if so, don't hide
    for (final upperEnglish in englishCodes) {
      // Check for prefix patterns like "US|", "UK |", "EN -", "US-", etc.
      if (upperName.startsWith('$upperEnglish|') ||
          upperName.startsWith('$upperEnglish |') ||
          upperName.startsWith('$upperEnglish-') ||
          upperName.startsWith('$upperEnglish -') ||
          upperName.startsWith('$upperEnglish:') ||
          upperName.startsWith('$upperEnglish :') ||
          upperName.startsWith('$upperEnglish ')) {
        return false; // It's English-speaking, don't hide
      }
      // Also check for "| USA", "| UK", etc. patterns
      if (upperName.contains('| $upperEnglish') ||
          upperName.contains('|$upperEnglish') ||
          upperName.contains(' $upperEnglish ') ||
          upperName.contains('($upperEnglish)') ||
          upperName.contains('[$upperEnglish]')) {
        return false; // Contains English-speaking country reference
      }
    }

    // Check if it starts with a 2-3 letter country/language code followed by separator
    // Common patterns: "AR|", "IT|", "FR-", "DE:", "RU |", "AR-KIDS", etc.
    final separators = ['|', ':', '-', ' '];

    for (final sep in separators) {
      // Pattern: CODE + separator (e.g., "IT|", "AR-", "FR:")
      final prefixWithSepPattern = RegExp('^([A-Z]{2,3})\\$sep', caseSensitive: false);
      final match = prefixWithSepPattern.firstMatch(upperName);
      if (match != null) {
        final prefix = match.group(1)!.toUpperCase();
        if (!englishCodes.contains(prefix)) {
          // debugPrint('AutoCombineService: Hiding category "$categoryName" - prefix "$prefix" with sep "$sep"');
          return true;
        }
      }

      // Pattern: CODE + space + separator (e.g., "IT |", "AR -")
      final prefixWithSpaceSepPattern = RegExp('^([A-Z]{2,3}) \\$sep', caseSensitive: false);
      final spaceMatch = prefixWithSpaceSepPattern.firstMatch(upperName);
      if (spaceMatch != null) {
        final prefix = spaceMatch.group(1)!.toUpperCase();
        if (!englishCodes.contains(prefix)) {
          // debugPrint('AutoCombineService: Hiding category "$categoryName" - prefix "$prefix" with space+sep');
          return true;
        }
      }
    }

    // Check if it matches any explicit non-English country/language pattern
    for (final pattern in AutoCombineConfig.defaultCountryPatterns) {
      final upperPattern = pattern.toUpperCase();
      if (upperName.startsWith(upperPattern) ||
          upperName.contains(' $upperPattern') ||
          upperName.contains('|$upperPattern') ||
          upperName.contains('| $upperPattern') ||
          upperName.contains('($upperPattern)') ||
          upperName.contains('[$upperPattern]')) {
        // debugPrint('AutoCombineService: Hiding category "$categoryName" - matches pattern "$pattern"');
        return true; // It's a non-English country category
      }
    }

    return false; // Assume English or neutral (no country prefix)
  }

  /// Merge categories containing specific keywords into a single category
  /// If hideNonEnglishCountries is enabled, filters out non-English items
  List<CategoryViewModel> _mergeByKeyword(
    List<CategoryViewModel> categories,
    List<String> keywords,
    String targetName,
  ) {
    final matchingCategories = <CategoryViewModel>[];
    final nonMatchingCategories = <CategoryViewModel>[];

    for (final cat in categories) {
      final upperName = cat.category.categoryName.toUpperCase();
      bool matches = false;

      for (final keyword in keywords) {
        if (upperName.contains(keyword.toUpperCase())) {
          matches = true;
          break;
        }
      }

      if (matches) {
        matchingCategories.add(cat);
      } else {
        nonMatchingCategories.add(cat);
      }
    }

    if (matchingCategories.length <= 1) {
      return categories; // Nothing to merge
    }

    // Merge all matching categories into one
    final mergedItems = <ContentItem>[];
    int skippedCategoriesCount = 0;
    int skippedItemsCount = 0;

    for (final cat in matchingCategories) {
      final categoryName = cat.category.categoryName;

      // If hideNonEnglishCountries is enabled, check if the source category is non-English
      if (_config.hideNonEnglishCountries) {
        // Skip entire category if it's from a non-English country
        if (_isNonEnglishCountryCategory(categoryName)) {
          skippedCategoriesCount++;
          skippedItemsCount += cat.contentItems.length;
          continue;
        }

        // For English or neutral categories, filter individual items
        for (final item in cat.contentItems) {
          if (!_isNonEnglishContentItem(item.name)) {
            mergedItems.add(item);
          } else {
            skippedItemsCount++;
          }
        }
      } else {
        // No filtering, add all items
        mergedItems.addAll(cat.contentItems);
      }
    }

    // If all items were filtered out, don't create the merged category
    if (mergedItems.isEmpty) {
      // debugPrint('AutoCombineService: All items filtered out for "$targetName", skipping merge');
      return nonMatchingCategories;
    }

    // Use the first matching category's type and playlistId for the merged category
    final firstCategory = matchingCategories.first.category;

    // Create a merged category
    final mergedCategory = CategoryViewModel(
      category: category_model.Category(
        categoryId: 'auto_merge_${targetName.toLowerCase().replaceAll(' ', '_')}',
        categoryName: targetName,
        parentId: 0, // Root level
        playlistId: firstCategory.playlistId,
        type: firstCategory.type,
      ),
      contentItems: mergedItems,
    );

    // if (_config.hideNonEnglishCountries && (skippedCategoriesCount > 0 || skippedItemsCount > 0)) {
    //   debugPrint('AutoCombineService: Merged ${matchingCategories.length} categories into "$targetName" '
    //       'with ${mergedItems.length} items (filtered: $skippedCategoriesCount categories, $skippedItemsCount items)');
    // } else {
    //   debugPrint('AutoCombineService: Merged ${matchingCategories.length} categories into "$targetName" with ${mergedItems.length} items');
    // }

    // Return merged category at the start, followed by non-matching categories
    return [mergedCategory, ...nonMatchingCategories];
  }

  /// Non-English speaking countries in the Americas region
  static const List<String> _nonEnglishAmericasCountries = [
    'MEXICO', 'MEXICAN', 'MX',
    'BRAZIL', 'BRAZILIAN', 'BRASIL', 'BR',
    'ARGENTINA', 'ARGENTINIAN', 'AR',
    'COLOMBIA', 'COLOMBIAN', 'CO',
    'CHILE', 'CHILEAN', 'CL',
    'PERU', 'PERUVIAN', 'PE',
    'VENEZUELA', 'VENEZUELAN', 'VE',
    'ECUADOR', 'ECUADORIAN', 'EC',
    'GUATEMALA', 'GT',
    'CUBA', 'CUBAN', 'CU',
    'BOLIVIA', 'BOLIVIAN', 'BO',
    'DOMINICAN', 'DOMINICANA', 'DO',
    'HONDURAS', 'HN',
    'PARAGUAY', 'PY',
    'NICARAGUA', 'NI',
    'COSTA RICA', 'CR',
    'PANAMA', 'PA',
    'URUGUAY', 'UY',
    'PUERTO RICO', 'PR', // Spanish-speaking
    'LATINO', 'LATINA', 'LATIN',
    'SPANISH', 'ESPANOL', 'ESPAÑOL',
    'PORTUGUESE', 'PORTUGUES',
    'HAITI', 'HAITIAN', 'HT',
  ];

  /// Check if an "AM" (Americas) prefixed name contains a non-English country
  bool _isNonEnglishAmericas(String upperName) {
    // Check if it starts with AM prefix
    if (!upperName.startsWith('AM ') &&
        !upperName.startsWith('AM|') &&
        !upperName.startsWith('AM-') &&
        !upperName.startsWith('AM:')) {
      return false;
    }

    // Check if any non-English Americas country is mentioned
    for (final country in _nonEnglishAmericasCountries) {
      if (upperName.contains(country)) {
        return true; // It's AM + non-English country
      }
    }

    return false; // AM without non-English country indicator
  }

  /// Non-English language codes that indicate content should be filtered
  static const List<String> _nonEnglishLanguageCodes = [
    'FR', 'FRENCH', 'FRANCAIS', 'FRANÇAIS',
    'ES', 'SPANISH', 'ESPANOL', 'ESPAÑOL',
    'DE', 'GERMAN', 'DEUTSCH',
    'IT', 'ITALIAN', 'ITALIANO',
    'PT', 'PORTUGUESE', 'PORTUGUES', 'PORTUGUÊS',
    'AR', 'ARABIC', 'ARABE',
    'RU', 'RUSSIAN', 'RUSSKIY',
    'ZH', 'CHINESE', 'MANDARIN', 'CANTONESE',
    'JA', 'JP', 'JAPANESE',
    'KO', 'KR', 'KOREAN',
    'HI', 'HINDI',
    'TR', 'TURKISH', 'TURK',
    'PL', 'POLISH', 'POLSKI',
    'NL', 'DUTCH', 'NEDERLANDS',
    'SV', 'SWEDISH', 'SVENSKA',
    'NO', 'NORWEGIAN', 'NORSK',
    'DA', 'DANISH', 'DANSK',
    'FI', 'FINNISH', 'SUOMI',
    'EL', 'GREEK',
    'HE', 'HEBREW',
    'TH', 'THAI',
    'VI', 'VIETNAMESE',
    'ID', 'INDONESIAN',
    'MS', 'MALAY',
    'TL', 'TAGALOG', 'FILIPINO',
    'UK', 'UKRAINIAN', // Note: UK as language code (Ukrainian), not country
    'RO', 'ROMANIAN',
    'HU', 'HUNGARIAN',
    'CS', 'CZECH',
    'SK', 'SLOVAK',
    'BG', 'BULGARIAN',
    'HR', 'CROATIAN',
    'SR', 'SERBIAN',
    'SL', 'SLOVENIAN', // Note: different from SLING TV service
    'ET', 'ESTONIAN',
    'LV', 'LATVIAN',
    'LT', 'LITHUANIAN',
    'FA', 'PERSIAN', 'FARSI',
    'UR', 'URDU',
    'BN', 'BENGALI',
    'TA', 'TAMIL',
    'TE', 'TELUGU',
    'PA', 'PUNJABI',
  ];

  /// English-speaking country prefixes (for checking country + language patterns)
  /// Note: IE (Ireland) and NZ (New Zealand) removed per user preference
  static const List<String> _englishCountryPrefixes = [
    'US', 'USA', 'UK', 'GB', 'CA', 'AU',
  ];

  /// Check if the name follows pattern: English Country + Non-English Language
  /// e.g., "CA FR" (Canada French), "UK AR" (UK Arabic), "US ES" (US Spanish)
  bool _isEnglishCountryWithNonEnglishLanguage(String upperName) {
    for (final country in _englishCountryPrefixes) {
      // Check for patterns like "CA FR", "CA-FR", "CA|FR", "CA:FR"
      for (final langCode in _nonEnglishLanguageCodes) {
        // Direct patterns: "CA FR", "CA-FR", "CA|FR"
        if (upperName.startsWith('$country $langCode') ||
            upperName.startsWith('$country-$langCode') ||
            upperName.startsWith('$country|$langCode') ||
            upperName.startsWith('$country:$langCode')) {
          return true;
        }
        // With space after: "CA FR ", "CA FR|", "CA FR-"
        if (upperName.startsWith('$country $langCode ') ||
            upperName.startsWith('$country $langCode|') ||
            upperName.startsWith('$country $langCode-') ||
            upperName.startsWith('$country $langCode:')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if name contains French language code (FR) as a distinct pattern
  /// This catches "CA FR", "AM FR", "CANADA FR", "FR|", etc.
  bool _containsFrenchLanguageCode(String upperName) {
    // Check for FR as a prefix pattern
    if (upperName.startsWith('FR|') ||
        upperName.startsWith('FR |') ||
        upperName.startsWith('FR-') ||
        upperName.startsWith('FR -') ||
        upperName.startsWith('FR:')) {
      return true;
    }

    // Check for FR as a suffix or inline code
    if (upperName.contains(' FR|') ||
        upperName.contains(' FR ') ||
        upperName.contains('|FR|') ||
        upperName.contains('|FR ') ||
        upperName.contains(' FR-') ||
        upperName.contains('-FR-') ||
        upperName.contains('-FR ') ||
        upperName.endsWith(' FR') ||
        upperName.endsWith('|FR') ||
        upperName.endsWith('-FR')) {
      return true;
    }

    // Check for [FR] or (FR) tags
    if (upperName.contains('[FR]') || upperName.contains('(FR)')) {
      return true;
    }

    // Check for FRENCH keyword
    if (upperName.contains('FRENCH') ||
        upperName.contains('FRANCAIS') ||
        upperName.contains('FRANÇAIS')) {
      return true;
    }

    return false;
  }

  /// Check if name contains ASIA or AS (Asia) patterns
  bool _isAsiaContent(String upperName) {
    // Check for ASIA as a prefix or inline pattern
    if (upperName.startsWith('ASIA|') ||
        upperName.startsWith('ASIA |') ||
        upperName.startsWith('ASIA-') ||
        upperName.startsWith('ASIA -') ||
        upperName.startsWith('ASIA:') ||
        upperName.contains(' ASIA|') ||
        upperName.contains(' ASIA ') ||
        upperName.contains('|ASIA|') ||
        upperName.contains('|ASIA ') ||
        upperName.endsWith(' ASIA') ||
        upperName.endsWith('|ASIA')) {
      return true;
    }

    // Check for AS (Asia abbreviation) as a prefix pattern
    // Be careful not to match words starting with "AS" like "ASSUMED"
    if (upperName.startsWith('AS|') ||
        upperName.startsWith('AS |') ||
        upperName.startsWith('AS-') ||
        upperName.startsWith('AS -') ||
        upperName.startsWith('AS:')) {
      return true;
    }

    // Check for AS as suffix or inline (with separators to avoid false positives)
    if (upperName.contains(' AS|') ||
        upperName.contains('|AS|') ||
        upperName.contains('|AS ') ||
        upperName.endsWith('|AS') ||
        upperName.endsWith(' AS|')) {
      return true;
    }

    // Check for [ASIA] or (ASIA) or [AS] or (AS) tags
    if (upperName.contains('[ASIA]') || upperName.contains('(ASIA)') ||
        upperName.contains('[AS]') || upperName.contains('(AS)')) {
      return true;
    }

    // Check for ASIAN keyword
    if (upperName.contains('ASIAN')) {
      return true;
    }

    return false;
  }

  /// Check if a content item name indicates non-English content
  bool _isNonEnglishContentItem(String itemName) {
    final upperName = itemName.toUpperCase().trim();

    // Special check: filter any content containing "FR" (France/French) as a code
    // This catches items like "CA FR", "AM FR", "CANADA FR" which are French Canadian
    if (_containsFrenchLanguageCode(upperName)) {
      return true;
    }

    // Special check for ASIA (AS prefix)
    if (_isAsiaContent(upperName)) {
      return true;
    }

    // Special check for AM (Americas) - filter if followed by non-English country
    if (_isNonEnglishAmericas(upperName)) {
      return true;
    }

    // Build a set of uppercase English-speaking codes for quick lookup
    final englishCodes = _config.englishSpeakingCountries
        .map((e) => e.toUpperCase())
        .toSet();

    // Check for multi-sub content (usually English available)
    if (upperName.contains('[MULTI-SUB]') ||
        upperName.contains('[MULTI SUB]') ||
        upperName.contains('(MULTI-SUB)') ||
        upperName.contains('(MULTI SUB)') ||
        upperName.contains('MULTI-SUBS') ||
        upperName.contains('MULTISUB')) {
      return false; // Multi-sub content typically has English, don't filter
    }

    // First check if it's English content - if so, don't filter
    for (final upperEnglish in englishCodes) {
      // Check for patterns like "[EN]", "(English)", "EN -", "| US", "EN|", etc.
      if (upperName.contains('[$upperEnglish]') ||
          upperName.contains('($upperEnglish)') ||
          upperName.startsWith('$upperEnglish -') ||
          upperName.startsWith('$upperEnglish|') ||
          upperName.startsWith('$upperEnglish |') ||
          upperName.startsWith('$upperEnglish:') ||
          upperName.startsWith('$upperEnglish-') ||
          upperName.contains('| $upperEnglish') ||
          upperName.contains('|$upperEnglish') ||
          upperName.contains(' $upperEnglish ') ||
          upperName.contains('|$upperEnglish|') ||
          upperName.contains(' $upperEnglish|') ||
          upperName.endsWith(' $upperEnglish') ||
          upperName.endsWith('|$upperEnglish')) {
        return false; // It's English content, don't filter
      }
    }

    // Check if it starts with a 2-3 letter country/language code followed by separator
    // Common patterns: "AR|", "IT|", "FR-", "DE:", "RU |", "AR-KIDS", etc.
    // Use multiple simpler patterns instead of complex character class
    final separators = ['|', ':', '-', ' '];

    for (final sep in separators) {
      // Pattern: CODE + separator (e.g., "IT|", "AR-", "FR:")
      final prefixWithSepPattern = RegExp('^([A-Z]{2,3})\\$sep', caseSensitive: false);
      final match = prefixWithSepPattern.firstMatch(upperName);
      if (match != null) {
        final prefix = match.group(1)!.toUpperCase();
        if (!englishCodes.contains(prefix)) {
          // debugPrint('AutoCombineService: Item "$itemName" filtered - prefix "$prefix" with sep "$sep"');
          return true; // Non-English item
        }
      }

      // Pattern: CODE + space + separator (e.g., "IT |", "AR -")
      final prefixWithSpaceSepPattern = RegExp('^([A-Z]{2,3}) \\$sep', caseSensitive: false);
      final spaceMatch = prefixWithSpaceSepPattern.firstMatch(upperName);
      if (spaceMatch != null) {
        final prefix = spaceMatch.group(1)!.toUpperCase();
        if (!englishCodes.contains(prefix)) {
          // debugPrint('AutoCombineService: Item "$itemName" filtered - prefix "$prefix" with space+sep');
          return true; // Non-English item
        }
      }
    }

    // Check for language/country tags in brackets or parentheses: [FR], (DE), etc.
    final tagPattern = RegExp(r'[\[\(]([A-Z]{2,3})[\]\)]', caseSensitive: false);
    final tagMatches = tagPattern.allMatches(upperName);
    for (final tagMatch in tagMatches) {
      final tag = tagMatch.group(1)!.toUpperCase();
      if (!englishCodes.contains(tag)) {
        // debugPrint('AutoCombineService: Item "$itemName" filtered - tag [$tag]');
        return true; // Non-English item
      }
    }

    // Check for explicit non-English language/region names
    final nonEnglishLanguageNames = [
      'FRENCH', 'GERMAN', 'SPANISH', 'ITALIAN', 'PORTUGUESE',
      'RUSSIAN', 'TURKISH', 'ARABIC', 'POLISH', 'DUTCH', 'GREEK',
      'CZECH', 'HUNGARIAN', 'ROMANIAN', 'BULGARIAN', 'SWEDISH',
      'NORWEGIAN', 'DANISH', 'FINNISH', 'JAPANESE', 'KOREAN',
      'CHINESE', 'MANDARIN', 'CANTONESE', 'HINDI', 'TAMIL', 'TELUGU',
      'THAI', 'VIETNAMESE', 'INDONESIAN', 'MALAY', 'TAGALOG',
      'BRAZILIAN', 'MEXICAN', 'UKRAINIAN', 'PERSIAN', 'FARSI',
      'HEBREW', 'KURDISH', 'ALBANIAN', 'SERBIAN', 'CROATIAN',
      'LATINO', 'LATIN', 'AFRICAIN', 'AFRICAN',
      'ASIA', 'ASIAN', 'BOLLYWOOD', 'INDIAN',
    ];

    for (final langName in nonEnglishLanguageNames) {
      if (upperName.contains('($langName)') ||
          upperName.contains('[$langName]') ||
          upperName.contains(' $langName ') ||
          upperName.endsWith(' $langName')) {
        // debugPrint('AutoCombineService: Item "$itemName" filtered - language name "$langName"');
        return true; // Non-English item
      }
    }

    return false; // Assume English or neutral
  }

  /// Merge categories by genre keywords
  /// Handles categories like "AM | USA THRILLER TV" -> "THRILLER"
  List<CategoryViewModel> _mergeGenreCategories(List<CategoryViewModel> categories) {
    var result = List<CategoryViewModel>.from(categories);

    // Define genre groups to merge - include singular, plural, and common variations
    // These will match anywhere in the category name (e.g., "AM | USA THRILLER TV" matches THRILLER)
    final genreGroups = <String, List<String>>{
      'DOCUMENTARY': [
        'DOCUMENTARY', 'DOCUMENTARIES', 'DOCU', 'DOCS',
        'DOCUMENTAIRE', 'DOCUMENTAIRES', 'BELGESEL', 'DOCUMENTAL',
      ],
      'DRAMA': [
        'DRAMA', 'DRAMAS', 'DRAME', 'DRAMATIC',
      ],
      'COMEDY': [
        'COMEDY', 'COMEDIES', 'COMEDIA', 'COMÉDIE', 'KOMEDI', 'COMEDIC',
      ],
      'HORROR': [
        'HORROR', 'HORRORS', 'TERREUR', 'TERROR', 'SCARY',
      ],
      'ACTION': [
        'ACTION', 'ACCIÓN', 'AÇÃO', 'AKSIYON',
      ],
      'THRILLER': [
        'THRILLER', 'THRILLERS', 'SUSPENSE', 'SUSPENSEFUL',
      ],
      'ROMANCE': [
        'ROMANCE', 'ROMANCES', 'ROMANTIC', 'ROMANTIQUE', 'ROMANTICO',
      ],
      'CRIME': [
        'CRIME', 'CRIMES', 'CRIMINAL', 'KRIMI', 'CRIMEN',
      ],
      'SCI-FI': [
        'SCI-FI', 'SCIFI', 'SCI FI', 'SCIENCE FICTION', 'CIENCIA FICCIÓN',
        'SCIENCEFICTION', 'SF',
      ],
      'FANTASY': [
        'FANTASY', 'FANTASIES', 'FANTAISIE', 'FANTASIA', 'FANTASTIQUE',
      ],
      'ANIMATION': [
        'ANIMATION', 'ANIMATIONS', 'ANIMATED', 'ANIMACIÓN', 'ANIMAÇÃO',
        'ANIME', 'CARTOON', 'CARTOONS',
      ],
      'WESTERN': [
        'WESTERN', 'WESTERNS',
      ],
      'MUSICAL': [
        'MUSICAL', 'MUSICALS', 'MUSIQUE', 'MUSIC',
      ],
      'WAR': [
        'WAR', 'WARS', 'GUERRE', 'GUERRA', 'MILITARY',
      ],
      'MYSTERY': [
        'MYSTERY', 'MYSTERIES', 'MYSTÈRE', 'MISTERIO', 'MYSTERIOUS',
      ],
      'ADVENTURE': [
        'ADVENTURE', 'ADVENTURES', 'AVENTURE', 'AVENTURA', 'MACERA',
      ],
      'FAMILY': [
        'FAMILY', 'FAMILIAL', 'FAMILLE', 'FAMILIA',
      ],
      'HISTORY': [
        'HISTORY', 'HISTORICAL', 'HISTOIRE', 'HISTORIA', 'HISTORIC',
      ],
      'BIOGRAPHY': [
        'BIOGRAPHY', 'BIOGRAPHIES', 'BIO', 'BIOPIC', 'BIOGRAPHICAL',
      ],
      'SPORTS': [
        'SPORT', 'SPORTS', 'SPORTING', 'DEPORTE', 'DEPORTES',
      ],
      'NEWS': [
        'NEWS', 'NOTICIAS', 'ACTUALITÉS', 'NOUVELLES',
      ],
      'REALITY': [
        'REALITY', 'REALITY TV', 'REALITE', 'REAL',
      ],
    };

    for (final entry in genreGroups.entries) {
      result = _mergeByKeyword(result, entry.value, entry.key);
    }

    return result;
  }

  /// Hide categories matching specific patterns
  List<CategoryViewModel> _hideByPatterns(
    List<CategoryViewModel> categories,
    List<String> patterns,
  ) {
    return categories.where((cat) {
      final upperName = cat.category.categoryName.toUpperCase();
      for (final pattern in patterns) {
        if (upperName.contains(pattern.toUpperCase())) {
          return false; // Hide this category
        }
      }
      return true; // Keep this category
    }).toList();
  }

  /// Add a custom rule
  Future<void> addCustomRule(AutoCombineRule rule) async {
    final rules = List<AutoCombineRule>.from(_config.customRules);
    rules.add(rule);
    await saveConfig(_config.copyWith(customRules: rules));
  }

  /// Update a custom rule
  Future<void> updateCustomRule(String ruleId, AutoCombineRule updatedRule) async {
    final rules = _config.customRules.map((r) {
      if (r.id == ruleId) return updatedRule;
      return r;
    }).toList();
    await saveConfig(_config.copyWith(customRules: rules));
  }

  /// Remove a custom rule
  Future<void> removeCustomRule(String ruleId) async {
    final rules = _config.customRules.where((r) => r.id != ruleId).toList();
    await saveConfig(_config.copyWith(customRules: rules));
  }

  /// Toggle a rule's enabled state
  Future<void> toggleRuleEnabled(String ruleId, bool enabled) async {
    final rules = _config.customRules.map((r) {
      if (r.id == ruleId) return r.copyWith(enabled: enabled);
      return r;
    }).toList();
    await saveConfig(_config.copyWith(customRules: rules));
  }

  /// Get statistics about what would be affected by current rules
  Map<String, int> getAffectedCategoriesStats(List<CategoryViewModel> categories) {
    int kidsCount = 0;
    int genreCount = 0;
    int hiddenCount = 0;

    for (final cat in categories) {
      final name = cat.category.categoryName.toUpperCase();

      if (_config.mergeKidsCategories) {
        if (name.contains('KIDS') || name.contains('CHILDREN') ||
            name.contains('ENFANTS') || name.contains('KINDER')) {
          kidsCount++;
        }
      }

      if (_config.mergeGenreCategories) {
        for (final genre in AutoCombineConfig.defaultGenreKeywords) {
          if (name.contains(genre.toUpperCase())) {
            genreCount++;
            break;
          }
        }
      }

      if (_config.hideNonEnglishCountries) {
        if (_isNonEnglishCountryCategory(cat.category.categoryName)) {
          hiddenCount++;
        }
      }
    }

    return {
      'kidsCategories': kidsCount,
      'genreCategories': genreCount,
      'hiddenCategories': hiddenCount,
    };
  }
}
