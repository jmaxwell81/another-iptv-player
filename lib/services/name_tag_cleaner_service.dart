import 'package:shared_preferences/shared_preferences.dart';

/// Service for cleaning language/country tags from content and category names
/// Removes patterns like "[MULTI-SUB]", "EN|", "EN - ", "(US)", etc.
class NameTagCleanerService {
  static const String _enabledKey = 'name_tag_cleaner_enabled';

  static final NameTagCleanerService _instance = NameTagCleanerService._internal();
  factory NameTagCleanerService() => _instance;
  NameTagCleanerService._internal();

  bool _enabled = false;
  bool _initialized = false;

  bool get isEnabled => _enabled;

  /// Initialize the service by loading saved preferences
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _initialized = true;
    } catch (e) {
      _enabled = false;
      _initialized = true;
    }
  }

  /// Set whether tag cleaning is enabled
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Clean a name by removing language/country tags
  /// Returns the cleaned name if enabled, otherwise returns the original
  String cleanName(String name) {
    if (!_enabled || name.isEmpty) {
      return name;
    }

    return _removeAllTags(name);
  }

  /// Synchronous version for use in extensions
  /// Must call initialize() before using this
  String cleanNameSync(String name) {
    if (!_enabled || name.isEmpty) {
      return name;
    }

    return _removeAllTags(name);
  }

  /// Remove all recognized tags from a name
  String _removeAllTags(String name) {
    var result = name;

    // Remove bracket tags: [EN], [US], [MULTI-SUB], [HD], [4K], etc.
    result = _removeBracketTags(result);

    // Remove parenthesis tags: (US), (English), (HD), etc.
    result = _removeParenthesisTags(result);

    // Remove prefix patterns: "EN|", "EN -", "US:", etc.
    result = _removePrefixPatterns(result);

    // Remove suffix patterns: "| EN", "- US", etc.
    result = _removeSuffixPatterns(result);

    // Remove inline separator patterns: "| EN |", "- US -", etc.
    result = _removeInlinePatterns(result);

    // Clean up extra whitespace and separators
    result = _cleanupWhitespace(result);

    return result.trim();
  }

  /// Remove tags in square brackets
  String _removeBracketTags(String name) {
    // Language/country codes
    final langCountryCodes = [
      'EN', 'US', 'USA', 'UK', 'GB', 'CA', 'AU', 'NZ', 'IE',
      'ENGLISH', 'AMERICAN', 'BRITISH', 'CANADIAN', 'AUSTRALIAN',
      'FR', 'FRENCH', 'FRANCAIS',
      'ES', 'SPANISH', 'ESPANOL',
      'DE', 'GERMAN', 'DEUTSCH',
      'IT', 'ITALIAN', 'ITALIANO',
      'PT', 'PORTUGUESE',
      'RU', 'RUSSIAN',
      'AR', 'ARABIC',
      'TR', 'TURKISH',
      'NL', 'DUTCH',
      'PL', 'POLISH',
      'JP', 'JA', 'JAPANESE',
      'KR', 'KO', 'KOREAN',
      'ZH', 'CHINESE', 'MANDARIN',
      'HI', 'HINDI',
      'TH', 'THAI',
    ];

    // Quality indicators
    final qualityTags = [
      'HD', 'SD', 'FHD', 'UHD', '4K', '720P', '1080P', '2160P', '480P',
      'HEVC', 'H264', 'H265', 'H.264', 'H.265', 'X264', 'X265',
    ];

    // Multi-subtitle tags
    final multiSubTags = [
      'MULTI-SUB', 'MULTI SUB', 'MULTI-SUBS', 'MULTISUB', 'SUBS',
      'DUBBED', 'DUB', 'SUBBED', 'SUB',
    ];

    var result = name;

    // Build pattern for all bracket tags
    final allTags = [...langCountryCodes, ...qualityTags, ...multiSubTags];
    for (final tag in allTags) {
      // Case insensitive removal of [TAG]
      result = result.replaceAll(RegExp('\\[$tag\\]', caseSensitive: false), '');
    }

    // Also remove any remaining 2-3 letter codes in brackets: [XX] or [XXX]
    result = result.replaceAll(RegExp(r'\[[A-Z]{2,3}\]', caseSensitive: false), '');

    return result;
  }

  /// Remove tags in parentheses
  String _removeParenthesisTags(String name) {
    final tagsToRemove = [
      'EN', 'US', 'USA', 'UK', 'GB', 'CA', 'AU', 'NZ', 'IE',
      'ENGLISH', 'AMERICAN', 'BRITISH', 'CANADIAN', 'AUSTRALIAN',
      'FR', 'FRENCH', 'ES', 'SPANISH', 'DE', 'GERMAN', 'IT', 'ITALIAN',
      'HD', 'SD', 'FHD', 'UHD', '4K', '720P', '1080P',
      'MULTI-SUB', 'MULTI SUB', 'DUBBED', 'SUBBED',
    ];

    var result = name;

    for (final tag in tagsToRemove) {
      result = result.replaceAll(RegExp('\\($tag\\)', caseSensitive: false), '');
    }

    // Also remove any remaining 2-3 letter codes in parens: (XX) or (XXX)
    result = result.replaceAll(RegExp(r'\([A-Z]{2,3}\)', caseSensitive: false), '');

    return result;
  }

  /// Remove prefix patterns like "EN|", "EN -", "US:", "EN | "
  String _removePrefixPatterns(String name) {
    final prefixes = [
      'EN', 'US', 'USA', 'UK', 'GB', 'CA', 'AU', 'NZ', 'IE', 'ENGLISH',
    ];

    var result = name;

    for (final prefix in prefixes) {
      // Patterns: "EN|", "EN |", "EN-", "EN -", "EN:", "EN :"
      result = result.replaceAll(
        RegExp('^$prefix\\s*[|:\\-]\\s*', caseSensitive: false),
        '',
      );
    }

    return result;
  }

  /// Remove suffix patterns like "| EN", "- US", " (EN)"
  String _removeSuffixPatterns(String name) {
    final suffixes = [
      'EN', 'US', 'USA', 'UK', 'GB', 'CA', 'AU', 'NZ', 'IE', 'ENGLISH',
      'HD', 'SD', 'FHD', 'UHD', '4K',
    ];

    var result = name;

    for (final suffix in suffixes) {
      // Patterns: "| EN", "|EN", "- EN", "-EN" at end
      result = result.replaceAll(
        RegExp('\\s*[|:\\-]\\s*$suffix\$', caseSensitive: false),
        '',
      );
    }

    return result;
  }

  /// Remove inline separator patterns
  String _removeInlinePatterns(String name) {
    final codes = [
      'EN', 'US', 'USA', 'UK', 'GB', 'CA', 'AU', 'NZ', 'IE',
      'HD', 'SD', 'FHD', 'UHD', '4K',
    ];

    var result = name;

    for (final code in codes) {
      // Pattern: " | EN | " or " - US - " in the middle
      result = result.replaceAll(
        RegExp('\\s+[|:\\-]\\s*$code\\s*[|:\\-]\\s+', caseSensitive: false),
        ' ',
      );
      // Pattern: " EN | " (code followed by separator)
      result = result.replaceAll(
        RegExp('\\s+$code\\s*[|:\\-]\\s+', caseSensitive: false),
        ' ',
      );
    }

    return result;
  }

  /// Clean up extra whitespace and dangling separators
  String _cleanupWhitespace(String name) {
    var result = name;

    // Remove multiple spaces
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Remove leading/trailing separators
    result = result.replaceAll(RegExp(r'^[\s|:\-]+'), '');
    result = result.replaceAll(RegExp(r'[\s|:\-]+$'), '');

    // Remove dangling separators (e.g., "Movie |" or "| Movie")
    result = result.replaceAll(RegExp(r'\s+[|:\-]\s*$'), '');
    result = result.replaceAll(RegExp(r'^\s*[|:\-]\s+'), '');

    // Remove double separators
    result = result.replaceAll(RegExp(r'[|:\-]\s*[|:\-]'), '');

    return result.trim();
  }

  /// Get a list of example tags that will be removed
  static List<String> get removableTags => [
    '[MULTI-SUB]',
    '[EN]',
    '[US]',
    '[HD]',
    '[4K]',
    '(US)',
    '(English)',
    'EN|',
    'EN -',
    'US:',
    '| EN',
    '- US',
  ];
}
