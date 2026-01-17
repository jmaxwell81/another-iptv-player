import 'package:flutter/foundation.dart';
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
      debugPrint('RenamingService: Loaded ${_cachedRules?.length ?? 0} rules');
      for (final rule in _cachedRules ?? []) {
        debugPrint('  Rule: "${rule.findText}" → "${rule.replaceText}" (enabled: ${rule.isEnabled}, appliesTo: ${rule.appliesTo}, fullWords: ${rule.fullWordsOnly})');
      }
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

  /// Apply a single rule to a string
  String _applyRule(String input, RenamingRule rule) {
    if (rule.findText.isEmpty) return input;

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
      debugPrint('RenamingService: Cache is null for "$name", scheduling load');
      // Load rules asynchronously for next time
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

      final before = result;
      result = _applyRule(result, rule);
      if (before != result) {
        debugPrint('RenamingService: Applied rule "${rule.findText}" → "${rule.replaceText}" to "$before" = "$result"');
      }
    }

    return result;
  }
}
