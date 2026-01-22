import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:drift/drift.dart';

/// OpenSubtitles API service for searching and downloading subtitles
/// API documentation: https://opensubtitles.stoplight.io/
class OpenSubtitlesService {
  static const String _baseUrl = 'https://api.opensubtitles.com/api/v1';
  static const String _userAgent = 'AnotherIPTVPlayer v1.0';

  String? _apiKey;
  String? _authToken;
  DateTime? _tokenExpiry;

  final AppDatabase _database = getIt<AppDatabase>();

  /// Initialize the service with stored API key
  Future<void> initialize() async {
    _apiKey = await UserPreferences.getOpenSubtitlesApiKey();
  }

  /// Check if the service is configured with an API key
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Set API key
  Future<void> setApiKey(String apiKey) async {
    _apiKey = apiKey;
    await UserPreferences.setOpenSubtitlesApiKey(apiKey);
    // Clear existing token when API key changes
    _authToken = null;
    _tokenExpiry = null;
  }

  /// Get current API key
  String? get apiKey => _apiKey;

  /// Login to get authentication token (optional, increases rate limit)
  Future<bool> login() async {
    if (!isConfigured) return false;

    final username = await UserPreferences.getOpenSubtitlesUsername();
    final password = await UserPreferences.getOpenSubtitlesPassword();

    if (username == null || password == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        // Token expires in 24 hours
        _tokenExpiry = DateTime.now().add(const Duration(hours: 24));
        return true;
      }

      debugPrint('OpenSubtitles login failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('OpenSubtitles login error: $e');
      return false;
    }
  }

  /// Search for subtitles by query (movie/series title)
  Future<List<SubtitleSearchResult>> searchByQuery({
    required String query,
    String? language,
    int? year,
    String? type, // 'movie', 'episode'
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    if (!isConfigured) return [];

    try {
      final params = <String, String>{
        'query': query,
      };

      if (language != null) params['languages'] = language;
      if (year != null) params['year'] = year.toString();
      if (type != null) params['type'] = type;
      if (seasonNumber != null) params['season_number'] = seasonNumber.toString();
      if (episodeNumber != null) params['episode_number'] = episodeNumber.toString();

      final uri = Uri.parse('$_baseUrl/subtitles').replace(queryParameters: params);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <SubtitleSearchResult>[];

        for (final item in data['data'] ?? []) {
          results.add(SubtitleSearchResult.fromJson(item));
        }

        return results;
      }

      debugPrint('OpenSubtitles search failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('OpenSubtitles search error: $e');
      return [];
    }
  }

  /// Search for subtitles by IMDB ID
  Future<List<SubtitleSearchResult>> searchByImdbId({
    required String imdbId,
    String? language,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    if (!isConfigured) return [];

    try {
      final params = <String, String>{
        'imdb_id': imdbId.replaceAll('tt', ''),
      };

      if (language != null) params['languages'] = language;
      if (seasonNumber != null) params['season_number'] = seasonNumber.toString();
      if (episodeNumber != null) params['episode_number'] = episodeNumber.toString();

      final uri = Uri.parse('$_baseUrl/subtitles').replace(queryParameters: params);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <SubtitleSearchResult>[];

        for (final item in data['data'] ?? []) {
          results.add(SubtitleSearchResult.fromJson(item));
        }

        return results;
      }

      return [];
    } catch (e) {
      debugPrint('OpenSubtitles search by IMDB error: $e');
      return [];
    }
  }

  /// Search for subtitles by TMDB ID
  Future<List<SubtitleSearchResult>> searchByTmdbId({
    required int tmdbId,
    String? language,
    String? type, // 'movie', 'episode'
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    if (!isConfigured) return [];

    try {
      final params = <String, String>{
        'tmdb_id': tmdbId.toString(),
      };

      if (language != null) params['languages'] = language;
      if (type != null) params['type'] = type;
      if (seasonNumber != null) params['season_number'] = seasonNumber.toString();
      if (episodeNumber != null) params['episode_number'] = episodeNumber.toString();

      final uri = Uri.parse('$_baseUrl/subtitles').replace(queryParameters: params);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <SubtitleSearchResult>[];

        for (final item in data['data'] ?? []) {
          results.add(SubtitleSearchResult.fromJson(item));
        }

        return results;
      }

      return [];
    } catch (e) {
      debugPrint('OpenSubtitles search by TMDB error: $e');
      return [];
    }
  }

  /// Download a subtitle file
  Future<String?> downloadSubtitle({
    required int fileId,
    required String contentId,
    required String contentName,
    required String contentType,
    required String language,
    required String languageName,
    String format = 'srt',
  }) async {
    if (!isConfigured) return null;

    try {
      // Request download link
      final response = await http.post(
        Uri.parse('$_baseUrl/download'),
        headers: _getHeaders(),
        body: jsonEncode({
          'file_id': fileId,
          'sub_format': format,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final downloadLink = data['link'] as String?;

        if (downloadLink == null) {
          debugPrint('OpenSubtitles: No download link in response');
          return null;
        }

        // Download the subtitle file
        final subtitleResponse = await http.get(Uri.parse(downloadLink));

        if (subtitleResponse.statusCode == 200) {
          // Save to local storage
          final dir = await _getSubtitleDirectory();
          final sanitizedName = _sanitizeFilename(contentName);
          final filename = '${sanitizedName}_$language.$format';
          final filePath = path.join(dir.path, filename);

          final file = File(filePath);
          await file.writeAsBytes(subtitleResponse.bodyBytes);

          // Cache in database
          final subtitleId = '${contentId}_$language';
          await _database.upsertCachedSubtitle(
            CachedSubtitlesCompanion(
              id: Value(subtitleId),
              contentId: Value(contentId),
              contentType: Value(contentType),
              contentName: Value(contentName),
              language: Value(language),
              languageName: Value(languageName),
              subtitleFormat: Value(format),
              filePath: Value(filePath),
              openSubtitlesId: Value(fileId.toString()),
              downloadedAt: Value(DateTime.now()),
            ),
          );

          return filePath;
        }
      } else if (response.statusCode == 406) {
        debugPrint('OpenSubtitles: Download quota exceeded');
      }

      debugPrint('OpenSubtitles download failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('OpenSubtitles download error: $e');
      return null;
    }
  }

  /// Get cached subtitle file path for content
  Future<String?> getCachedSubtitlePath(String contentId, String language) async {
    final cached = await _database.getCachedSubtitle(contentId, language);
    if (cached != null && File(cached.filePath).existsSync()) {
      // Update last used time
      await _database.updateSubtitleLastUsed(cached.id);
      return cached.filePath;
    }
    return null;
  }

  /// Get all cached subtitles for content
  Future<List<CachedSubtitleData>> getCachedSubtitlesForContent(String contentId) async {
    return _database.getCachedSubtitles(contentId);
  }

  /// Delete cached subtitle
  Future<void> deleteCachedSubtitle(String subtitleId, String filePath) async {
    // Delete file
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    // Delete from database
    await _database.deleteCachedSubtitle(subtitleId);
  }

  /// Get available languages
  Future<List<SubtitleLanguage>> getLanguages() async {
    if (!isConfigured) return _defaultLanguages;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/infos/languages'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final languages = <SubtitleLanguage>[];

        for (final item in data['data'] ?? []) {
          languages.add(SubtitleLanguage(
            code: item['language_code'] ?? '',
            name: item['language_name'] ?? '',
          ));
        }

        return languages;
      }

      return _defaultLanguages;
    } catch (e) {
      debugPrint('OpenSubtitles get languages error: $e');
      return _defaultLanguages;
    }
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': _userAgent,
    };

    if (_apiKey != null) {
      headers['Api-Key'] = _apiKey!;
    }

    if (_authToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  Future<Directory> _getSubtitleDirectory() async {
    final customPath = await UserPreferences.getSubtitleDownloadPath();
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) return dir;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final subtitleDir = Directory(path.join(appDir.path, 'subtitles'));
    if (!await subtitleDir.exists()) {
      await subtitleDir.create(recursive: true);
    }
    return subtitleDir;
  }

  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  static const List<SubtitleLanguage> _defaultLanguages = [
    SubtitleLanguage(code: 'en', name: 'English'),
    SubtitleLanguage(code: 'es', name: 'Spanish'),
    SubtitleLanguage(code: 'fr', name: 'French'),
    SubtitleLanguage(code: 'de', name: 'German'),
    SubtitleLanguage(code: 'it', name: 'Italian'),
    SubtitleLanguage(code: 'pt', name: 'Portuguese'),
    SubtitleLanguage(code: 'ru', name: 'Russian'),
    SubtitleLanguage(code: 'zh', name: 'Chinese'),
    SubtitleLanguage(code: 'ja', name: 'Japanese'),
    SubtitleLanguage(code: 'ko', name: 'Korean'),
    SubtitleLanguage(code: 'ar', name: 'Arabic'),
    SubtitleLanguage(code: 'tr', name: 'Turkish'),
    SubtitleLanguage(code: 'nl', name: 'Dutch'),
    SubtitleLanguage(code: 'pl', name: 'Polish'),
    SubtitleLanguage(code: 'sv', name: 'Swedish'),
  ];
}

/// Subtitle search result from OpenSubtitles
class SubtitleSearchResult {
  final String id;
  final String type; // 'movie', 'episode'
  final String language;
  final String languageName;
  final int downloadCount;
  final String? moviehash;
  final bool hearingImpaired;
  final bool foreignPartsOnly;
  final String? releaseInfo;
  final String format;
  final int fps;
  final List<SubtitleFile> files;
  final String? movieTitle;
  final String? parentTitle; // Series title for episodes
  final int? seasonNumber;
  final int? episodeNumber;
  final int? year;
  final String? imdbId;
  final int? tmdbId;
  final double? matchScore;

  SubtitleSearchResult({
    required this.id,
    required this.type,
    required this.language,
    required this.languageName,
    required this.downloadCount,
    this.moviehash,
    required this.hearingImpaired,
    required this.foreignPartsOnly,
    this.releaseInfo,
    required this.format,
    required this.fps,
    required this.files,
    this.movieTitle,
    this.parentTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.year,
    this.imdbId,
    this.tmdbId,
    this.matchScore,
  });

  factory SubtitleSearchResult.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] ?? {};
    final featureDetails = attributes['feature_details'] ?? {};
    final files = <SubtitleFile>[];

    for (final file in attributes['files'] ?? []) {
      files.add(SubtitleFile(
        fileId: file['file_id'] ?? 0,
        cdNumber: file['cd_number'] ?? 1,
        fileName: file['file_name'] ?? '',
      ));
    }

    return SubtitleSearchResult(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'movie',
      language: attributes['language'] ?? '',
      languageName: attributes['language_name'] ?? attributes['language'] ?? '',
      downloadCount: attributes['download_count'] ?? 0,
      moviehash: attributes['moviehash'],
      hearingImpaired: attributes['hearing_impaired'] ?? false,
      foreignPartsOnly: attributes['foreign_parts_only'] ?? false,
      releaseInfo: attributes['release'],
      format: attributes['format'] ?? 'srt',
      fps: (attributes['fps'] ?? 0).toInt(),
      files: files,
      movieTitle: featureDetails['title'] ?? featureDetails['movie_name'],
      parentTitle: featureDetails['parent_title'],
      seasonNumber: featureDetails['season_number'],
      episodeNumber: featureDetails['episode_number'],
      year: featureDetails['year'],
      imdbId: featureDetails['imdb_id']?.toString(),
      tmdbId: featureDetails['tmdb_id'],
      matchScore: (attributes['scores']?['total_score'] ?? 0).toDouble(),
    );
  }

  /// Get the primary file ID for download
  int? get primaryFileId => files.isNotEmpty ? files.first.fileId : null;

  /// Get display title
  String get displayTitle {
    if (parentTitle != null && seasonNumber != null && episodeNumber != null) {
      return '$parentTitle S${seasonNumber!.toString().padLeft(2, '0')}E${episodeNumber!.toString().padLeft(2, '0')}';
    }
    return movieTitle ?? 'Unknown';
  }
}

/// Subtitle file info
class SubtitleFile {
  final int fileId;
  final int cdNumber;
  final String fileName;

  SubtitleFile({
    required this.fileId,
    required this.cdNumber,
    required this.fileName,
  });
}

/// Subtitle language
class SubtitleLanguage {
  final String code;
  final String name;

  const SubtitleLanguage({
    required this.code,
    required this.name,
  });
}
