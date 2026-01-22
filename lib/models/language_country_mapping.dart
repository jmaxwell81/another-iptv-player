/// Represents a mapping between a tag (language code or country code) and a language.
class LanguageCountryMapping {
  final String tag;           // The tag to match (e.g., "US", "GB", "EN", "IT")
  final String languageCode;  // ISO 639-1 language code (e.g., "en", "it")
  final String displayName;   // Human-readable name (e.g., "English", "Italian")
  final bool isCountryCode;   // Whether this is a country code vs language code
  final bool isBuiltIn;       // Whether this is a built-in mapping (cannot be deleted)

  const LanguageCountryMapping({
    required this.tag,
    required this.languageCode,
    required this.displayName,
    this.isCountryCode = false,
    this.isBuiltIn = false,
  });

  /// Create from JSON map
  factory LanguageCountryMapping.fromJson(Map<String, dynamic> json) {
    return LanguageCountryMapping(
      tag: json['tag'] as String,
      languageCode: json['languageCode'] as String,
      displayName: json['displayName'] as String,
      isCountryCode: json['isCountryCode'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'languageCode': languageCode,
      'displayName': displayName,
      'isCountryCode': isCountryCode,
      'isBuiltIn': isBuiltIn,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageCountryMapping &&
        other.tag.toLowerCase() == tag.toLowerCase();
  }

  @override
  int get hashCode => tag.toLowerCase().hashCode;

  @override
  String toString() => 'LanguageCountryMapping($tag -> $languageCode)';
}

/// Default built-in language mappings
class BuiltInMappings {
  static const List<LanguageCountryMapping> languageMappings = [
    // English language codes
    LanguageCountryMapping(tag: 'EN', languageCode: 'en', displayName: 'English', isBuiltIn: true),
    LanguageCountryMapping(tag: 'ENG', languageCode: 'en', displayName: 'English', isBuiltIn: true),

    // Spanish
    LanguageCountryMapping(tag: 'ES', languageCode: 'es', displayName: 'Spanish', isBuiltIn: true),
    LanguageCountryMapping(tag: 'ESP', languageCode: 'es', displayName: 'Spanish', isBuiltIn: true),

    // French
    LanguageCountryMapping(tag: 'FR', languageCode: 'fr', displayName: 'French', isBuiltIn: true),
    LanguageCountryMapping(tag: 'FRA', languageCode: 'fr', displayName: 'French', isBuiltIn: true),

    // German
    LanguageCountryMapping(tag: 'DE', languageCode: 'de', displayName: 'German', isBuiltIn: true),
    LanguageCountryMapping(tag: 'GER', languageCode: 'de', displayName: 'German', isBuiltIn: true),
    LanguageCountryMapping(tag: 'DEU', languageCode: 'de', displayName: 'German', isBuiltIn: true),

    // Italian
    LanguageCountryMapping(tag: 'IT', languageCode: 'it', displayName: 'Italian', isBuiltIn: true),
    LanguageCountryMapping(tag: 'ITA', languageCode: 'it', displayName: 'Italian', isBuiltIn: true),

    // Portuguese
    LanguageCountryMapping(tag: 'PT', languageCode: 'pt', displayName: 'Portuguese', isBuiltIn: true),
    LanguageCountryMapping(tag: 'POR', languageCode: 'pt', displayName: 'Portuguese', isBuiltIn: true),

    // Russian
    LanguageCountryMapping(tag: 'RU', languageCode: 'ru', displayName: 'Russian', isBuiltIn: true),
    LanguageCountryMapping(tag: 'RUS', languageCode: 'ru', displayName: 'Russian', isBuiltIn: true),

    // Turkish
    LanguageCountryMapping(tag: 'TR', languageCode: 'tr', displayName: 'Turkish', isBuiltIn: true),
    LanguageCountryMapping(tag: 'TUR', languageCode: 'tr', displayName: 'Turkish', isBuiltIn: true),

    // Arabic
    LanguageCountryMapping(tag: 'AR', languageCode: 'ar', displayName: 'Arabic', isBuiltIn: true),
    LanguageCountryMapping(tag: 'ARA', languageCode: 'ar', displayName: 'Arabic', isBuiltIn: true),

    // Dutch
    LanguageCountryMapping(tag: 'NL', languageCode: 'nl', displayName: 'Dutch', isBuiltIn: true),
    LanguageCountryMapping(tag: 'NLD', languageCode: 'nl', displayName: 'Dutch', isBuiltIn: true),

    // Polish
    LanguageCountryMapping(tag: 'PL', languageCode: 'pl', displayName: 'Polish', isBuiltIn: true),
    LanguageCountryMapping(tag: 'POL', languageCode: 'pl', displayName: 'Polish', isBuiltIn: true),

    // Greek
    LanguageCountryMapping(tag: 'EL', languageCode: 'el', displayName: 'Greek', isBuiltIn: true),
    LanguageCountryMapping(tag: 'GRE', languageCode: 'el', displayName: 'Greek', isBuiltIn: true),

    // Hindi
    LanguageCountryMapping(tag: 'HI', languageCode: 'hi', displayName: 'Hindi', isBuiltIn: true),
    LanguageCountryMapping(tag: 'HIN', languageCode: 'hi', displayName: 'Hindi', isBuiltIn: true),

    // Japanese
    LanguageCountryMapping(tag: 'JA', languageCode: 'ja', displayName: 'Japanese', isBuiltIn: true),
    LanguageCountryMapping(tag: 'JPN', languageCode: 'ja', displayName: 'Japanese', isBuiltIn: true),

    // Korean
    LanguageCountryMapping(tag: 'KO', languageCode: 'ko', displayName: 'Korean', isBuiltIn: true),
    LanguageCountryMapping(tag: 'KOR', languageCode: 'ko', displayName: 'Korean', isBuiltIn: true),

    // Chinese
    LanguageCountryMapping(tag: 'ZH', languageCode: 'zh', displayName: 'Chinese', isBuiltIn: true),
    LanguageCountryMapping(tag: 'CHI', languageCode: 'zh', displayName: 'Chinese', isBuiltIn: true),
    LanguageCountryMapping(tag: 'ZHO', languageCode: 'zh', displayName: 'Chinese', isBuiltIn: true),

    // Armenian
    LanguageCountryMapping(tag: 'HY', languageCode: 'hy', displayName: 'Armenian', isBuiltIn: true),
    LanguageCountryMapping(tag: 'ARM', languageCode: 'hy', displayName: 'Armenian', isBuiltIn: true),
  ];

  static const List<LanguageCountryMapping> countryMappings = [
    // English-speaking countries
    LanguageCountryMapping(tag: 'US', languageCode: 'en', displayName: 'United States', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'USA', languageCode: 'en', displayName: 'United States', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'GB', languageCode: 'en', displayName: 'Great Britain', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'UK', languageCode: 'en', displayName: 'United Kingdom', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'AU', languageCode: 'en', displayName: 'Australia', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'CA', languageCode: 'en', displayName: 'Canada', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'NZ', languageCode: 'en', displayName: 'New Zealand', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'IE', languageCode: 'en', displayName: 'Ireland', isCountryCode: true, isBuiltIn: true),

    // Armenian (AM is Armenia country code)
    LanguageCountryMapping(tag: 'AM', languageCode: 'hy', displayName: 'Armenia', isCountryCode: true, isBuiltIn: true),

    // Spanish-speaking countries
    LanguageCountryMapping(tag: 'MX', languageCode: 'es', displayName: 'Mexico', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'AR', languageCode: 'es', displayName: 'Argentina', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'CL', languageCode: 'es', displayName: 'Chile', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'CO', languageCode: 'es', displayName: 'Colombia', isCountryCode: true, isBuiltIn: true),

    // French-speaking countries
    LanguageCountryMapping(tag: 'BE', languageCode: 'fr', displayName: 'Belgium', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'CH', languageCode: 'fr', displayName: 'Switzerland', isCountryCode: true, isBuiltIn: true),

    // German-speaking countries
    LanguageCountryMapping(tag: 'AT', languageCode: 'de', displayName: 'Austria', isCountryCode: true, isBuiltIn: true),

    // Portuguese-speaking countries
    LanguageCountryMapping(tag: 'BR', languageCode: 'pt', displayName: 'Brazil', isCountryCode: true, isBuiltIn: true),

    // Italian
    LanguageCountryMapping(tag: 'IT', languageCode: 'it', displayName: 'Italy', isCountryCode: true, isBuiltIn: true),

    // Netherlands
    LanguageCountryMapping(tag: 'NL', languageCode: 'nl', displayName: 'Netherlands', isCountryCode: true, isBuiltIn: true),

    // Poland
    LanguageCountryMapping(tag: 'PL', languageCode: 'pl', displayName: 'Poland', isCountryCode: true, isBuiltIn: true),

    // Greece
    LanguageCountryMapping(tag: 'GR', languageCode: 'el', displayName: 'Greece', isCountryCode: true, isBuiltIn: true),

    // Russia
    LanguageCountryMapping(tag: 'RU', languageCode: 'ru', displayName: 'Russia', isCountryCode: true, isBuiltIn: true),

    // Turkey
    LanguageCountryMapping(tag: 'TR', languageCode: 'tr', displayName: 'Turkey', isCountryCode: true, isBuiltIn: true),

    // India
    LanguageCountryMapping(tag: 'IN', languageCode: 'hi', displayName: 'India', isCountryCode: true, isBuiltIn: true),

    // Japan
    LanguageCountryMapping(tag: 'JP', languageCode: 'ja', displayName: 'Japan', isCountryCode: true, isBuiltIn: true),

    // South Korea
    LanguageCountryMapping(tag: 'KR', languageCode: 'ko', displayName: 'South Korea', isCountryCode: true, isBuiltIn: true),

    // China
    LanguageCountryMapping(tag: 'CN', languageCode: 'zh', displayName: 'China', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'TW', languageCode: 'zh', displayName: 'Taiwan', isCountryCode: true, isBuiltIn: true),
    LanguageCountryMapping(tag: 'HK', languageCode: 'zh', displayName: 'Hong Kong', isCountryCode: true, isBuiltIn: true),
  ];

  /// Get all built-in mappings
  static List<LanguageCountryMapping> get all => [...languageMappings, ...countryMappings];
}

/// Represents a pattern-based content filter rule
class ContentFilterRule {
  final String id;
  final String pattern;           // The pattern to match (supports * wildcard)
  final bool isRegex;             // Whether pattern is a regex
  final bool hideMatching;        // If true, hide matching items; if false, show only matching
  final bool appliesToCategories; // Whether this rule applies to category names
  final bool appliesToContent;    // Whether this rule applies to content names
  final Set<String>? categoryIds; // Specific categories to apply to (null = all)
  final DateTime createdAt;
  final bool isEnabled;

  ContentFilterRule({
    required this.id,
    required this.pattern,
    this.isRegex = false,
    this.hideMatching = true,
    this.appliesToCategories = false,
    this.appliesToContent = true,
    this.categoryIds,
    DateTime? createdAt,
    this.isEnabled = true,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if a name matches this rule
  bool matches(String name) {
    if (!isEnabled) return false;

    if (isRegex) {
      try {
        return RegExp(pattern, caseSensitive: false).hasMatch(name);
      } catch (e) {
        return false;
      }
    } else {
      // Simple wildcard matching (* = any characters)
      // If pattern has no wildcards, do a "contains" match
      if (!pattern.contains('*')) {
        // No wildcards - check if name contains the pattern (case-insensitive)
        return name.toLowerCase().contains(pattern.toLowerCase());
      }

      // Pattern has wildcards - convert to regex
      final regexPattern = pattern
          .replaceAll(RegExp(r'[.+?^${}()|[\]\\#]'), r'\$&') // Escape special chars including #
          .replaceAll('*', '.*'); // Convert * to .*
      return RegExp('^$regexPattern\$', caseSensitive: false).hasMatch(name);
    }
  }

  /// Create from JSON
  factory ContentFilterRule.fromJson(Map<String, dynamic> json) {
    return ContentFilterRule(
      id: json['id'] as String,
      pattern: json['pattern'] as String,
      isRegex: json['isRegex'] as bool? ?? false,
      hideMatching: json['hideMatching'] as bool? ?? true,
      appliesToCategories: json['appliesToCategories'] as bool? ?? false,
      appliesToContent: json['appliesToContent'] as bool? ?? true,
      categoryIds: json['categoryIds'] != null
          ? Set<String>.from(json['categoryIds'] as List)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pattern': pattern,
      'isRegex': isRegex,
      'hideMatching': hideMatching,
      'appliesToCategories': appliesToCategories,
      'appliesToContent': appliesToContent,
      'categoryIds': categoryIds?.toList(),
      'createdAt': createdAt.toIso8601String(),
      'isEnabled': isEnabled,
    };
  }

  ContentFilterRule copyWith({
    String? id,
    String? pattern,
    bool? isRegex,
    bool? hideMatching,
    bool? appliesToCategories,
    bool? appliesToContent,
    Set<String>? categoryIds,
    DateTime? createdAt,
    bool? isEnabled,
  }) {
    return ContentFilterRule(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      isRegex: isRegex ?? this.isRegex,
      hideMatching: hideMatching ?? this.hideMatching,
      appliesToCategories: appliesToCategories ?? this.appliesToCategories,
      appliesToContent: appliesToContent ?? this.appliesToContent,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt ?? this.createdAt,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  String toString() => 'ContentFilterRule($pattern, hide=$hideMatching)';
}
