import 'package:another_iptv_player/models/consolidated_content_item.dart';
import 'package:another_iptv_player/models/content_source_link.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// Service for selecting the best source from consolidated content
/// based on user preferences for quality and language.
class ContentPreferenceService {
  // Singleton instance
  static final ContentPreferenceService _instance =
      ContentPreferenceService._internal();
  factory ContentPreferenceService() => _instance;
  ContentPreferenceService._internal();

  // Cached preferences
  ContentQuality? _preferredQuality;
  String? _preferredLanguage;
  bool _consolidationEnabled = true;
  DateTime? _lastPreferencesLoad;

  /// Score weights for source selection
  static const int _languageMatchScore = 50;
  static const int _qualityMatchScore = 15;
  static const int _xtreamBonusScore = 5;

  /// Load user preferences (caches for 5 minutes)
  Future<void> loadPreferences({bool forceReload = false}) async {
    final now = DateTime.now();
    if (!forceReload &&
        _lastPreferencesLoad != null &&
        now.difference(_lastPreferencesLoad!) < const Duration(minutes: 5)) {
      return;
    }

    _consolidationEnabled = await UserPreferences.getConsolidationEnabled();
    _preferredQuality = await UserPreferences.getPreferredContentQuality();
    _preferredLanguage = await UserPreferences.getPreferredContentLanguage();
    _lastPreferencesLoad = now;
  }

  /// Whether consolidation is enabled
  bool get isConsolidationEnabled => _consolidationEnabled;

  /// Get current preferred quality
  ContentQuality? get preferredQuality => _preferredQuality;

  /// Get current preferred language
  String? get preferredLanguage => _preferredLanguage;

  /// Select the best source from a consolidated content item
  Future<ContentSourceLink> selectBestSource(
    ConsolidatedContentItem item,
  ) async {
    await loadPreferences();
    return selectBestSourceSync(item.sourceLinks);
  }

  /// Synchronous version when preferences are already loaded
  ContentSourceLink selectBestSourceSync(List<ContentSourceLink> sources) {
    if (sources.isEmpty) {
      throw ArgumentError('Sources list cannot be empty');
    }
    if (sources.length == 1) return sources.first;

    // Score each source
    int bestScore = -1;
    ContentSourceLink bestSource = sources.first;

    for (final source in sources) {
      final score = calculateSourceScore(source);
      if (score > bestScore) {
        bestScore = score;
        bestSource = source;
      }
    }

    return bestSource;
  }

  /// Calculate score for a source based on current preferences
  int calculateSourceScore(ContentSourceLink source) {
    int score = 0;

    // Language match bonus (highest priority)
    if (_preferredLanguage != null &&
        source.language != null &&
        source.language!.toLowerCase() == _preferredLanguage!.toLowerCase()) {
      score += _languageMatchScore;
    }

    // Base quality score (10-40 points)
    score += source.quality.score;

    // Bonus for matching preferred quality exactly
    if (_preferredQuality != null && source.quality == _preferredQuality) {
      score += _qualityMatchScore;
    }

    // Small bonus for Xtream sources (richer metadata)
    if (source.sourceType == PlaylistType.xtream) {
      score += _xtreamBonusScore;
    }

    return score;
  }

  /// Apply preferences to a list of consolidated items
  Future<void> applyPreferences(List<ConsolidatedContentItem> items) async {
    await loadPreferences();

    for (final item in items) {
      if (item.hasMultipleSources) {
        item.preferredSource = selectBestSourceSync(item.sourceLinks);
      }
    }
  }

  /// Get sources ranked by preference (best first)
  List<ContentSourceLink> getRankedSources(
    List<ContentSourceLink> sources,
  ) {
    if (sources.isEmpty) return [];

    final scored = sources.map((source) {
      return _ScoredSource(source, calculateSourceScore(source));
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.source).toList();
  }

  /// Get a user-friendly explanation of why a source was preferred
  String getPreferenceExplanation(ContentSourceLink source) {
    final reasons = <String>[];

    if (_preferredLanguage != null &&
        source.language != null &&
        source.language!.toLowerCase() == _preferredLanguage!.toLowerCase()) {
      reasons.add('matches language preference (${source.language!.toUpperCase()})');
    }

    if (_preferredQuality != null && source.quality == _preferredQuality) {
      reasons.add('matches quality preference (${source.quality.label})');
    } else if (source.quality != ContentQuality.unknown) {
      reasons.add('${source.quality.label} quality');
    }

    if (source.sourceType == PlaylistType.xtream) {
      reasons.add('from Xtream source');
    }

    if (reasons.isEmpty) {
      return 'Default selection';
    }

    return reasons.join(', ');
  }

  /// Update and persist user preferences
  Future<void> updatePreferences({
    bool? consolidationEnabled,
    ContentQuality? preferredQuality,
    String? preferredLanguage,
  }) async {
    if (consolidationEnabled != null) {
      await UserPreferences.setConsolidationEnabled(consolidationEnabled);
      _consolidationEnabled = consolidationEnabled;
    }

    if (preferredQuality != null) {
      await UserPreferences.setPreferredContentQuality(preferredQuality);
      _preferredQuality = preferredQuality;
    }

    if (preferredLanguage != null) {
      await UserPreferences.setPreferredContentLanguage(preferredLanguage);
      _preferredLanguage = preferredLanguage;
    }
  }

  /// Reset preferences to defaults
  Future<void> resetPreferences() async {
    await UserPreferences.setConsolidationEnabled(true);
    await UserPreferences.setPreferredContentQuality(ContentQuality.hd1080p);
    await UserPreferences.setPreferredContentLanguage('en');

    _consolidationEnabled = true;
    _preferredQuality = ContentQuality.hd1080p;
    _preferredLanguage = 'en';
  }

  /// Clear cached preferences (force reload on next access)
  void clearCache() {
    _lastPreferencesLoad = null;
  }
}

class _ScoredSource {
  final ContentSourceLink source;
  final int score;

  _ScoredSource(this.source, this.score);
}
