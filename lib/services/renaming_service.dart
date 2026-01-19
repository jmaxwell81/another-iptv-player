import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/renaming_rule.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// Service for applying renaming rules to content names
/// Uses a singleton pattern with caching for performance
class RenamingService {
  static final RenamingService _instance = RenamingService._internal();
  factory RenamingService() => _instance;
  RenamingService._internal();

  List<RenamingRule>? _cachedRules;
  bool _isLoading = false;

  /// Load and cache rules from storage
  Future<void> loadRules() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      _cachedRules = await UserPreferences.getRenamingRules();
    } finally {
      _isLoading = false;
    }
  }

  /// Clear the cache (call after rules are modified)
  void invalidateCache() {
    _cachedRules = null;
  }

  /// Get cached rules, loading if necessary
  Future<List<RenamingRule>> getRules() async {
    if (_cachedRules == null) {
      await loadRules();
    }
    return _cachedRules ?? [];
  }

  /// Apply renaming rules to a content name
  /// Returns the transformed name
  Future<String> applyRules(
    String name, {
    ContentType? contentType,
    bool isCategory = false,
  }) async {
    final rules = await getRules();
    if (rules.isEmpty) return name;

    String result = name;

    for (final rule in rules) {
      if (!rule.isEnabled) continue;

      // Check if rule applies to this content type
      if (isCategory) {
        if (!rule.appliesTo.appliesToCategories()) {
          continue;
        }
      } else {
        if (rule.appliesTo == RuleAppliesTo.categories) {
          continue;
        }
        if (rule.appliesTo != RuleAppliesTo.all &&
            !rule.appliesTo.appliesTo(contentType)) {
          continue;
        }
      }

      result = _applyRule(result, rule);
    }

    return result;
  }

  /// Convert special placeholders in find text to regex patterns
  /// Supported placeholders:
  /// - %DATE% or %YEAR% - matches 4-digit year (e.g., 2022)
  /// - %NUM% - matches any number
  /// - %ANY% - matches any characters (non-greedy)
  /// - %WORD% - matches a single word
  String _convertPlaceholdersToRegex(String findText) {
    String pattern = RegExp.escape(findText);

    // Replace placeholders with regex patterns
    // Note: % is not a special regex char, so it's not escaped by RegExp.escape
    // %DATE% or %YEAR% - matches 4-digit year
    pattern = pattern.replaceAll('%DATE%', r'\d{4}');
    pattern = pattern.replaceAll('%YEAR%', r'\d{4}');

    // %NUM% - matches any number (one or more digits)
    pattern = pattern.replaceAll('%NUM%', r'\d+');

    // %ANY% - matches any characters (non-greedy)
    pattern = pattern.replaceAll('%ANY%', r'.*?');

    // %WORD% - matches a single word (letters, numbers, some special chars)
    pattern = pattern.replaceAll('%WORD%', r'[\w\-]+');

    return pattern;
  }

  /// Check if find text contains any special placeholders
  bool _hasPlaceholders(String findText) {
    return findText.contains('%DATE%') ||
        findText.contains('%YEAR%') ||
        findText.contains('%NUM%') ||
        findText.contains('%ANY%') ||
        findText.contains('%WORD%');
  }

  /// Apply a single rule to a string
  String _applyRule(String input, RenamingRule rule) {
    if (rule.findText.isEmpty) return input;

    // Check if the rule uses special placeholders
    if (_hasPlaceholders(rule.findText)) {
      final regexPattern = _convertPlaceholdersToRegex(rule.findText);
      try {
        final pattern = RegExp(regexPattern, caseSensitive: true);
        return input.replaceAll(pattern, rule.replaceText);
      } catch (e) {
        // Invalid regex pattern, return original input
        return input;
      }
    }

    if (rule.fullWordsOnly) {
      // Use word boundary regex for full word matching
      // Note: \b only works with word characters (letters, digits, underscore)
      // For text with special chars like [MY], we use a more flexible approach
      final escapedFind = RegExp.escape(rule.findText);

      // Check if findText contains non-word characters
      final hasSpecialChars = RegExp(r'[^\w]').hasMatch(rule.findText);

      if (hasSpecialChars) {
        // For special chars, match with optional surrounding spaces
        // This handles cases like "[MY]" where word boundaries don't work
        final pattern = RegExp(
          r'(?:^|\s)' + escapedFind + r'(?:\s|$)',
          caseSensitive: true,
        );
        // Replace and preserve spacing
        return input.replaceAllMapped(pattern, (match) {
          final matchStr = match.group(0)!;
          final leadingSpace = matchStr.startsWith(' ') ? ' ' : '';
          final trailingSpace = matchStr.endsWith(' ') ? ' ' : '';
          return leadingSpace + rule.replaceText + trailingSpace;
        });
      } else {
        // Standard word boundary matching
        final pattern = RegExp(r'\b' + escapedFind + r'\b', caseSensitive: true);
        return input.replaceAll(pattern, rule.replaceText);
      }
    } else {
      // Simple string replacement
      return input.replaceAll(rule.findText, rule.replaceText);
    }
  }

  /// Apply rules synchronously using cached rules (for use in build methods)
  /// Returns original name if rules not yet loaded
  String applyRulesSync(
    String name, {
    ContentType? contentType,
    bool isCategory = false,
  }) {
    if (_cachedRules == null) {
      // Cache not loaded yet - schedule a load for next time
      loadRules();
      return name;
    }

    if (_cachedRules!.isEmpty) return name;

    String result = name;

    for (final rule in _cachedRules!) {
      if (!rule.isEnabled) continue;

      // Check if rule applies to this content type
      if (isCategory) {
        if (!rule.appliesTo.appliesToCategories()) {
          continue;
        }
      } else {
        if (rule.appliesTo == RuleAppliesTo.categories) {
          continue;
        }
        if (rule.appliesTo != RuleAppliesTo.all &&
            !rule.appliesTo.appliesTo(contentType)) {
          continue;
        }
      }

      result = _applyRule(result, rule);
    }

    return result;
  }
}
