import 'package:another_iptv_player/models/content_source_link.dart';
import 'package:another_iptv_player/models/language_country_mapping.dart';

/// Service for normalizing content names and extracting metadata like quality and language.
/// Used for matching duplicate content across multiple IPTV sources.
class ContentNormalizationService {
  // Singleton instance
  static final ContentNormalizationService _instance =
      ContentNormalizationService._internal();
  factory ContentNormalizationService() => _instance;
  ContentNormalizationService._internal() {
    _initializeMappings();
  }

  // Combined mappings (built-in + user-defined)
  final Map<String, String> _tagToLanguage = {};
  List<LanguageCountryMapping> _userMappings = [];

  /// Initialize mappings from built-in defaults
  void _initializeMappings() {
    _tagToLanguage.clear();

    // Add all built-in mappings
    for (final mapping in BuiltInMappings.all) {
      _tagToLanguage[mapping.tag.toUpperCase()] = mapping.languageCode;
    }

    // Add user mappings (these override built-in if same tag)
    for (final mapping in _userMappings) {
      _tagToLanguage[mapping.tag.toUpperCase()] = mapping.languageCode;
    }
  }

  /// Update user-defined mappings
  void setUserMappings(List<LanguageCountryMapping> mappings) {
    _userMappings = mappings;
    _initializeMappings();
  }

  /// Add a user-defined mapping
  void addUserMapping(LanguageCountryMapping mapping) {
    _userMappings.removeWhere((m) => m.tag.toUpperCase() == mapping.tag.toUpperCase());
    _userMappings.add(mapping);
    _tagToLanguage[mapping.tag.toUpperCase()] = mapping.languageCode;
  }

  /// Remove a user-defined mapping
  void removeUserMapping(String tag) {
    _userMappings.removeWhere((m) => m.tag.toUpperCase() == tag.toUpperCase());
    _initializeMappings();
  }

  /// Get all current mappings (for settings UI)
  List<LanguageCountryMapping> getAllMappings() {
    final result = <LanguageCountryMapping>[];
    final added = <String>{};

    // Add user mappings first (they override)
    for (final mapping in _userMappings) {
      if (!added.contains(mapping.tag.toUpperCase())) {
        result.add(mapping);
        added.add(mapping.tag.toUpperCase());
      }
    }

    // Add built-in mappings that weren't overridden
    for (final mapping in BuiltInMappings.all) {
      if (!added.contains(mapping.tag.toUpperCase())) {
        result.add(mapping);
        added.add(mapping.tag.toUpperCase());
      }
    }

    return result;
  }

  // Quality detection patterns
  static final List<_QualityPattern> _qualityPatterns = [
    // 4K patterns (highest priority)
    _QualityPattern(RegExp(r'\b4k\b', caseSensitive: false), ContentQuality.uhd4k),
    _QualityPattern(RegExp(r'\buhd\b', caseSensitive: false), ContentQuality.uhd4k),
    _QualityPattern(RegExp(r'\b2160p\b', caseSensitive: false), ContentQuality.uhd4k),
    _QualityPattern(RegExp(r'\bultra\s*hd\b', caseSensitive: false), ContentQuality.uhd4k),

    // 1080p patterns
    _QualityPattern(RegExp(r'\b1080p\b', caseSensitive: false), ContentQuality.hd1080p),
    _QualityPattern(RegExp(r'\bfhd\b', caseSensitive: false), ContentQuality.hd1080p),
    _QualityPattern(RegExp(r'\bfull\s*hd\b', caseSensitive: false), ContentQuality.hd1080p),
    _QualityPattern(RegExp(r'\b1080i\b', caseSensitive: false), ContentQuality.hd1080p),

    // 720p patterns
    _QualityPattern(RegExp(r'\b720p\b', caseSensitive: false), ContentQuality.hd720p),
    _QualityPattern(RegExp(r'\bhd\b(?!\s*$)', caseSensitive: false), ContentQuality.hd720p),

    // SD patterns (lowest priority)
    _QualityPattern(RegExp(r'\bsd\b', caseSensitive: false), ContentQuality.sd),
    _QualityPattern(RegExp(r'\b480p\b', caseSensitive: false), ContentQuality.sd),
    _QualityPattern(RegExp(r'\b360p\b', caseSensitive: false), ContentQuality.sd),
    _QualityPattern(RegExp(r'\b576p\b', caseSensitive: false), ContentQuality.sd),
  ];

  // Patterns to detect language/country tags in content names
  // These patterns extract tags that we then look up in _tagToLanguage
  static final List<RegExp> _tagExtractionPatterns = [
    // Bracketed tags: [US], [EN], [IT], etc.
    RegExp(r'\[([A-Za-z]{2,3})\]'),
    // Parenthesized tags: (US), (EN), (IT)
    RegExp(r'\(([A-Za-z]{2,3})\)'),
    // Prefix tags: US: , UK| , EN -
    RegExp(r'^([A-Za-z]{2,3})\s*[\|:\-]\s*'),
    // Suffix tags: - US, | UK
    RegExp(r'\s*[\|:\-]\s*([A-Za-z]{2,3})$'),
    // Full language names in brackets/parens
    RegExp(r'[\[\(](english|spanish|french|german|italian|portuguese|russian|turkish|arabic|dutch|polish|greek|hindi|japanese|korean|chinese|armenian)[\]\)]', caseSensitive: false),
  ];

  // Map full language names to codes
  static const Map<String, String> _languageNameToCode = {
    'english': 'en',
    'spanish': 'es',
    'french': 'fr',
    'german': 'de',
    'italian': 'it',
    'portuguese': 'pt',
    'russian': 'ru',
    'turkish': 'tr',
    'arabic': 'ar',
    'dutch': 'nl',
    'polish': 'pl',
    'greek': 'el',
    'hindi': 'hi',
    'japanese': 'ja',
    'korean': 'ko',
    'chinese': 'zh',
    'armenian': 'hy',
  };

  // Patterns to remove from names for matching (prefixes, suffixes, etc.)
  static final List<RegExp> _removePatterns = [
    // Provider/channel prefixes (common IPTV patterns)
    RegExp(r'^[A-Z]{2,4}\s*[\|:\-]\s*', caseSensitive: false),
    RegExp(r'^\[[^\]]+\]\s*'),
    RegExp(r'^{[^}]+}\s*'),
    RegExp(r'^\([^)]+\)\s*'),
    RegExp(r'^[A-Za-z]{2,3}\d+[\|:\-]\s*'),

    // Quality tags (including HD/SD without other indicators)
    RegExp(r'\s*[\[\(]?\b(4k|uhd|2160p|1080p|fhd|full\s*hd|720p|hd|sd|480p|360p)\b[\]\)]?\s*', caseSensitive: false),

    // Frame rate patterns (must be before quality to catch "HD 60fps")
    RegExp(r'\s*\b\d{2,3}\s*f(?:ps|r)?\b', caseSensitive: false), // 60fps, 25fps, 30fr, etc.
    RegExp(r'\s*\bfps\b', caseSensitive: false),

    // RAW indicator (common in IPTV for unprocessed streams)
    RegExp(r'\s*\braw\b', caseSensitive: false),

    // Language/country tags
    RegExp(r'\s*[\[\(][a-z]{2,3}[\]\)]\s*', caseSensitive: false),
    RegExp(r'\s*\((?:english|turkish|spanish|french|german|portuguese|italian|russian|arabic|armenian)\)\s*', caseSensitive: false),

    // Year
    RegExp(r'\s*[\[\(]?(19|20)\d{2}[\]\)]?\s*'),

    // Common suffixes
    RegExp(r'\s*\+\d+\s*$'),
    RegExp(r'\s*H\.?265\s*', caseSensitive: false),
    RegExp(r'\s*HEVC\s*', caseSensitive: false),
    RegExp(r'\s*HDR\d*\s*', caseSensitive: false),
    RegExp(r'\s*(?:x264|x265|h264|h265)\s*', caseSensitive: false),
    RegExp(r'\s*(?:AAC|AC3|DTS)\s*', caseSensitive: false),

    // Bitrate indicators
    RegExp(r'\s*\d+\s*(?:kbps|mbps)\s*', caseSensitive: false),

    // Extra whitespace and special chars
    RegExp(r'\s+'),
    RegExp(r'[\|:\-_]+$'),
    RegExp(r'^[\|:\-_]+'),
  ];

  /// Normalize a name for matching purposes.
  String normalizeForMatching(String name) {
    if (name.isEmpty) return '';

    String normalized = name.trim();

    for (final pattern in _removePatterns) {
      normalized = normalized.replaceAll(pattern, ' ');
    }

    normalized = normalized
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();

    return normalized;
  }

  /// Extract quality from content name and optional file extension
  ContentQuality extractQuality(String name, {String? containerExtension}) {
    for (final pattern in _qualityPatterns) {
      if (pattern.regex.hasMatch(name)) {
        return pattern.quality;
      }
    }

    if (containerExtension != null) {
      final ext = containerExtension.toLowerCase();
      if (ext == 'mkv') return ContentQuality.hd1080p;
      if (ext == 'ts') return ContentQuality.hd720p;
    }

    return ContentQuality.unknown;
  }

  /// Extract language from content name using both language codes and country codes
  String? extractLanguage(String name) {
    // Try each extraction pattern
    for (final pattern in _tagExtractionPatterns) {
      final matches = pattern.allMatches(name);
      for (final match in matches) {
        if (match.groupCount >= 1) {
          final tag = match.group(1)!.toUpperCase();

          // Check if it's a full language name
          final lowerTag = tag.toLowerCase();
          if (_languageNameToCode.containsKey(lowerTag)) {
            return _languageNameToCode[lowerTag];
          }

          // Look up in our tag-to-language mapping
          if (_tagToLanguage.containsKey(tag)) {
            return _tagToLanguage[tag];
          }
        }
      }
    }

    return null;
  }

  /// Extract all detected tags from a name (for debugging/display)
  List<String> extractAllTags(String name) {
    final tags = <String>[];

    for (final pattern in _tagExtractionPatterns) {
      final matches = pattern.allMatches(name);
      for (final match in matches) {
        if (match.groupCount >= 1) {
          tags.add(match.group(1)!.toUpperCase());
        }
      }
    }

    return tags;
  }

  /// Check if content matches a specific language (checks both language and country codes)
  bool contentMatchesLanguage(String name, String targetLanguageCode) {
    final detectedLanguage = extractLanguage(name);
    return detectedLanguage?.toLowerCase() == targetLanguageCode.toLowerCase();
  }

  /// Get all tags that map to a specific language
  List<String> getTagsForLanguage(String languageCode) {
    final tags = <String>[];
    final lowerCode = languageCode.toLowerCase();

    for (final entry in _tagToLanguage.entries) {
      if (entry.value.toLowerCase() == lowerCode) {
        tags.add(entry.key);
      }
    }

    return tags;
  }

  /// Extract year from content name
  int? extractYear(String name) {
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(name);
    if (yearMatch != null) {
      return int.tryParse(yearMatch.group(0)!);
    }
    return null;
  }

  /// Check if two names represent the same content after normalization
  bool areNamesMatching(String name1, String name2) {
    final normalized1 = normalizeForMatching(name1);
    final normalized2 = normalizeForMatching(name2);
    return normalized1 == normalized2 && normalized1.isNotEmpty;
  }

  /// Get the best display name from a list of source names.
  String selectBestDisplayName(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;

    final scored = names.map((name) {
      int score = 0;

      if (RegExp(r'^[A-Z]{2,4}\s*[\|:\-]').hasMatch(name)) score += 10;
      if (RegExp(r'^\[[^\]]+\]').hasMatch(name)) score += 10;
      score += (RegExp(r'[\[\]\(\)]').allMatches(name).length * 2);
      if (name.length > 50) score += (name.length - 50) ~/ 10;
      if (name == name.toUpperCase()) score += 5;
      if (name == name.toLowerCase()) score += 5;

      return _ScoredName(name, score);
    }).toList();

    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored.first.name;
  }

  /// Get the best image path from a list of URLs.
  String selectBestImagePath(List<String?> paths) {
    final validPaths = paths.where((p) => p != null && p.isNotEmpty).toList();
    if (validPaths.isEmpty) return '';
    if (validPaths.length == 1) return validPaths.first!;

    final httpsPaths = validPaths.where((p) => p!.startsWith('https')).toList();
    if (httpsPaths.isNotEmpty) return httpsPaths.first!;

    return validPaths.first!;
  }
}

class _QualityPattern {
  final RegExp regex;
  final ContentQuality quality;

  _QualityPattern(this.regex, this.quality);
}

class _ScoredName {
  final String name;
  final int score;

  _ScoredName(this.name, this.score);
}
