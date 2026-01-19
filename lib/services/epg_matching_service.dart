import 'package:another_iptv_player/models/epg_channel.dart';
import 'package:another_iptv_player/models/live_stream.dart';
import 'package:another_iptv_player/models/m3u_item.dart';

class EpgMatchingService {
  /// Build mapping from stream channels to EPG channel IDs
  /// Returns a map where key is the stream identifier and value is the matched EPG channel ID
  Map<String, String> buildChannelEpgMapping(
    List<dynamic> channels, // LiveStream or M3uItem
    List<EpgChannel> epgChannels,
  ) {
    final mapping = <String, String>{};

    // Build lookup maps for efficient matching
    final epgById = <String, EpgChannel>{};
    final epgByIdLower = <String, EpgChannel>{};
    final epgByNameNormalized = <String, EpgChannel>{};
    final epgByNameLower = <String, EpgChannel>{};

    for (final epgChannel in epgChannels) {
      epgById[epgChannel.channelId] = epgChannel;
      epgByIdLower[epgChannel.channelId.toLowerCase()] = epgChannel;

      final normalizedName = _normalizeName(epgChannel.displayName);
      epgByNameNormalized[normalizedName] = epgChannel;
      epgByNameLower[epgChannel.displayName.toLowerCase()] = epgChannel;
    }

    for (final channel in channels) {
      String? streamId;
      String? epgChannelId;
      String? channelName;

      if (channel is LiveStream) {
        streamId = channel.streamId;
        epgChannelId = channel.epgChannelId.isNotEmpty ? channel.epgChannelId : null;
        channelName = channel.name;
      } else if (channel is M3uItem) {
        streamId = channel.id;
        epgChannelId = channel.tvgId;
        channelName = channel.name ?? channel.tvgName;
      } else {
        continue;
      }

      // Try to find a match
      final matchedEpgId = _findMatch(
        epgChannelId,
        channelName,
        epgById,
        epgByIdLower,
        epgByNameNormalized,
        epgByNameLower,
      );

      if (matchedEpgId != null) {
        mapping[streamId] = matchedEpgId;
      }
    }

    return mapping;
  }

  /// Find matching EPG channel ID using multiple strategies
  String? _findMatch(
    String? epgChannelId,
    String? channelName,
    Map<String, EpgChannel> epgById,
    Map<String, EpgChannel> epgByIdLower,
    Map<String, EpgChannel> epgByNameNormalized,
    Map<String, EpgChannel> epgByNameLower,
  ) {
    // Strategy 1: Exact ID match
    if (epgChannelId != null && epgChannelId.isNotEmpty) {
      if (epgById.containsKey(epgChannelId)) {
        return epgById[epgChannelId]!.channelId;
      }

      // Strategy 2: Case-insensitive ID match
      final lowerEpgId = epgChannelId.toLowerCase();
      if (epgByIdLower.containsKey(lowerEpgId)) {
        return epgByIdLower[lowerEpgId]!.channelId;
      }
    }

    // Name-based matching
    if (channelName != null && channelName.isNotEmpty) {
      // Strategy 3: Exact name match (case-insensitive)
      final lowerName = channelName.toLowerCase();
      if (epgByNameLower.containsKey(lowerName)) {
        return epgByNameLower[lowerName]!.channelId;
      }

      // Strategy 4: Normalized name match
      final normalizedName = _normalizeName(channelName);
      if (epgByNameNormalized.containsKey(normalizedName)) {
        return epgByNameNormalized[normalizedName]!.channelId;
      }

      // Strategy 5: Fuzzy name match
      final fuzzyMatch = _findFuzzyMatch(normalizedName, epgByNameNormalized);
      if (fuzzyMatch != null) {
        return fuzzyMatch.channelId;
      }
    }

    return null;
  }

  /// Normalize channel name for matching
  /// Removes HD, FHD, 4K, country prefixes, provider prefixes, and other common suffixes
  String _normalizeName(String name) {
    var normalized = name.toLowerCase().trim();

    // Remove common provider/category prefixes like "SLING:", "US:", "UK |", "HU:", etc.
    // Match pattern: word(s) followed by : or | at the start
    normalized = normalized.replaceAll(RegExp(r'^[a-z0-9\s]+[\s]*[:\|][\s]*', caseSensitive: false), '');

    // Remove common quality indicators
    normalized = normalized.replaceAll(RegExp(r'\s*(hd|fhd|uhd|4k|8k|sd|720p|1080p|2160p)\s*', caseSensitive: false), ' ');

    // Remove country suffixes like ".us", ".hu", ".uk" at the end
    normalized = normalized.replaceAll(RegExp(r'\.[a-z]{2}$', caseSensitive: false), '');

    // Remove superscript markers like ᴿᴬᵂ
    normalized = normalized.replaceAll(RegExp(r'[ᴬᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᴿˢᵀᵁⱽᵂᴬᴮᶜᴰᴱᶠᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᵠᴿˢᵀᵁⱽᵂˣʸᶻ]+', caseSensitive: false), '');

    // Remove common suffixes like "(+1)", "(backup)", "[HD]", etc.
    normalized = normalized.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*'), ' ');

    // Remove special characters and extra whitespace
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    return normalized.trim();
  }

  /// Find best fuzzy match using similarity score
  EpgChannel? _findFuzzyMatch(
    String normalizedName,
    Map<String, EpgChannel> epgByNameNormalized, {
    double threshold = 0.8,
  }) {
    if (normalizedName.isEmpty) return null;

    EpgChannel? bestMatch;
    double bestScore = 0;

    for (final entry in epgByNameNormalized.entries) {
      final score = _calculateSimilarity(normalizedName, entry.key);
      if (score > bestScore && score >= threshold) {
        bestScore = score;
        bestMatch = entry.value;
      }
    }

    return bestMatch;
  }

  /// Calculate similarity score between two strings (0.0 to 1.0)
  /// Uses a combination of Jaccard similarity and longest common subsequence
  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;

    // Token-based Jaccard similarity
    final tokensA = a.split(' ').where((t) => t.isNotEmpty).toSet();
    final tokensB = b.split(' ').where((t) => t.isNotEmpty).toSet();

    if (tokensA.isEmpty || tokensB.isEmpty) return 0;

    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;

    final jaccardSimilarity = intersection / union;

    // LCS ratio for substring matching
    final lcsLength = _longestCommonSubsequence(a, b);
    final lcsRatio = (2 * lcsLength) / (a.length + b.length);

    // Combine scores with weights
    return (jaccardSimilarity * 0.6) + (lcsRatio * 0.4);
  }

  /// Calculate length of longest common subsequence
  int _longestCommonSubsequence(String a, String b) {
    final m = a.length;
    final n = b.length;

    // Use space-optimized version
    var prev = List.filled(n + 1, 0);
    var curr = List.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          curr[j] = prev[j - 1] + 1;
        } else {
          curr[j] = curr[j - 1] > prev[j] ? curr[j - 1] : prev[j];
        }
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[n];
  }

  /// Cross-source matching - find EPG channel ID from multiple sources
  String? findCrossSourceMatch(
    String channelName,
    String? tvgId,
    Map<String, List<EpgChannel>> allSourceChannels,
  ) {
    // Try direct ID match first across all sources
    if (tvgId != null && tvgId.isNotEmpty) {
      for (final channels in allSourceChannels.values) {
        for (final channel in channels) {
          if (channel.channelId == tvgId ||
              channel.channelId.toLowerCase() == tvgId.toLowerCase()) {
            return channel.channelId;
          }
        }
      }
    }

    // Try name matching across all sources
    final normalizedName = _normalizeName(channelName);

    for (final channels in allSourceChannels.values) {
      // Exact name match
      for (final channel in channels) {
        if (_normalizeName(channel.displayName) == normalizedName) {
          return channel.channelId;
        }
      }

      // Fuzzy match
      final epgByNameNormalized = <String, EpgChannel>{};
      for (final channel in channels) {
        epgByNameNormalized[_normalizeName(channel.displayName)] = channel;
      }

      final fuzzyMatch = _findFuzzyMatch(normalizedName, epgByNameNormalized);
      if (fuzzyMatch != null) {
        return fuzzyMatch.channelId;
      }
    }

    return null;
  }
}
