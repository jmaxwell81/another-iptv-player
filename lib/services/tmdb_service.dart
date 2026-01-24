import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:drift/drift.dart';

/// TMDB API service for fetching movie and TV series details
/// API documentation: https://developers.themoviedb.org/3
class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p';

  String? _apiKey;
  final AppDatabase _database = getIt<AppDatabase>();

  /// Initialize the service with stored API key
  Future<void> initialize() async {
    _apiKey = await UserPreferences.getTmdbApiKey();
  }

  /// Check if the service is configured with an API key
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Set API key
  Future<void> setApiKey(String apiKey) async {
    _apiKey = apiKey;
    await UserPreferences.setTmdbApiKey(apiKey);
  }

  /// Get current API key
  String? get apiKey => _apiKey;

  /// Search for movies by title
  Future<List<TmdbSearchResult>> searchMovies(String query, {int? year}) async {
    if (!isConfigured) return [];

    try {
      final params = <String, String>{
        'api_key': _apiKey!,
        'query': query,
        'include_adult': 'false',
      };
      if (year != null) params['year'] = year.toString();

      final uri = Uri.parse('$_baseUrl/search/movie').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List)
            .map((r) => TmdbSearchResult.fromJson(r, 'movie'))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('TMDB search movies error: $e');
      return [];
    }
  }

  /// Search for TV series by title
  Future<List<TmdbSearchResult>> searchTvSeries(String query, {int? year}) async {
    if (!isConfigured) return [];

    try {
      final params = <String, String>{
        'api_key': _apiKey!,
        'query': query,
        'include_adult': 'false',
      };
      if (year != null) params['first_air_date_year'] = year.toString();

      final uri = Uri.parse('$_baseUrl/search/tv').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List)
            .map((r) => TmdbSearchResult.fromJson(r, 'tv'))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('TMDB search TV error: $e');
      return [];
    }
  }

  /// Multi-search (movies and TV)
  Future<List<TmdbSearchResult>> multiSearch(String query) async {
    if (!isConfigured) return [];

    try {
      final params = <String, String>{
        'api_key': _apiKey!,
        'query': query,
        'include_adult': 'false',
      };

      final uri = Uri.parse('$_baseUrl/search/multi').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List)
            .where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv')
            .map((r) => TmdbSearchResult.fromJson(r, r['media_type']))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('TMDB multi search error: $e');
      return [];
    }
  }

  /// Get movie details with credits and similar movies
  Future<TmdbMovieDetails?> getMovieDetails(int tmdbId, {bool fetchCredits = true, bool fetchSimilar = true}) async {
    if (!isConfigured) return null;

    try {
      final appendToResponse = <String>[];
      if (fetchCredits) appendToResponse.add('credits');
      if (fetchSimilar) appendToResponse.add('similar');
      appendToResponse.add('release_dates'); // For certifications
      appendToResponse.add('keywords');

      final params = <String, String>{
        'api_key': _apiKey!,
      };
      if (appendToResponse.isNotEmpty) {
        params['append_to_response'] = appendToResponse.join(',');
      }

      final uri = Uri.parse('$_baseUrl/movie/$tmdbId').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TmdbMovieDetails.fromJson(data);
      }

      return null;
    } catch (e) {
      debugPrint('TMDB get movie details error: $e');
      return null;
    }
  }

  /// Get TV series details with credits and similar series
  Future<TmdbTvDetails?> getTvDetails(int tmdbId, {bool fetchCredits = true, bool fetchSimilar = true}) async {
    if (!isConfigured) return null;

    try {
      final appendToResponse = <String>[];
      if (fetchCredits) appendToResponse.add('credits');
      if (fetchSimilar) appendToResponse.add('similar');
      appendToResponse.add('content_ratings'); // For certifications
      appendToResponse.add('keywords');

      final params = <String, String>{
        'api_key': _apiKey!,
      };
      if (appendToResponse.isNotEmpty) {
        params['append_to_response'] = appendToResponse.join(',');
      }

      final uri = Uri.parse('$_baseUrl/tv/$tmdbId').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TmdbTvDetails.fromJson(data);
      }

      return null;
    } catch (e) {
      debugPrint('TMDB get TV details error: $e');
      return null;
    }
  }

  /// Find by IMDB ID
  Future<TmdbSearchResult?> findByImdbId(String imdbId) async {
    if (!isConfigured) return null;

    try {
      final params = <String, String>{
        'api_key': _apiKey!,
        'external_source': 'imdb_id',
      };

      final uri = Uri.parse('$_baseUrl/find/$imdbId').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check movie results
        final movieResults = data['movie_results'] as List?;
        if (movieResults != null && movieResults.isNotEmpty) {
          return TmdbSearchResult.fromJson(movieResults.first, 'movie');
        }

        // Check TV results
        final tvResults = data['tv_results'] as List?;
        if (tvResults != null && tvResults.isNotEmpty) {
          return TmdbSearchResult.fromJson(tvResults.first, 'tv');
        }
      }

      return null;
    } catch (e) {
      debugPrint('TMDB find by IMDB error: $e');
      return null;
    }
  }

  /// Fetch and cache content details
  Future<ContentDetailsData?> fetchAndCacheDetails({
    required String contentId,
    required String playlistId,
    required String contentType, // 'vod', 'series'
    required String title,
    String? imdbId,
    int? tmdbId,
    int? year,
  }) async {
    // Check if we have valid cached data
    if (await _database.hasValidContentDetails(contentId, playlistId)) {
      return _database.getContentDetails(contentId, playlistId);
    }

    if (!isConfigured) return null;

    try {
      TmdbSearchResult? searchResult;

      // Try to find by IMDB ID first
      if (imdbId != null && imdbId.isNotEmpty) {
        searchResult = await findByImdbId(imdbId);
      }

      // If not found by IMDB, search by title
      if (searchResult == null) {
        final searchResults = contentType == 'vod'
            ? await searchMovies(title, year: year)
            : await searchTvSeries(title, year: year);

        if (searchResults.isNotEmpty) {
          // Get best match (first result or closest year match)
          searchResult = searchResults.first;
        }
      }

      if (searchResult == null) return null;

      // Fetch full details
      dynamic details;
      if (searchResult.mediaType == 'movie') {
        details = await getMovieDetails(searchResult.id);
      } else {
        details = await getTvDetails(searchResult.id);
      }

      if (details == null) return null;

      // Convert to database model and cache
      final dbDetails = _convertToDbDetails(
        details: details,
        contentId: contentId,
        playlistId: playlistId,
        contentType: contentType,
      );

      await _database.upsertContentDetails(dbDetails);

      return _database.getContentDetails(contentId, playlistId);
    } catch (e) {
      debugPrint('TMDB fetch and cache error: $e');
      return null;
    }
  }

  ContentDetailsCompanion _convertToDbDetails({
    required dynamic details,
    required String contentId,
    required String playlistId,
    required String contentType,
  }) {
    final isMovie = details is TmdbMovieDetails;
    final now = DateTime.now();

    return ContentDetailsCompanion(
      id: Value('${contentId}_$playlistId'),
      contentId: Value(contentId),
      playlistId: Value(playlistId),
      contentType: Value(contentType),
      tmdbId: Value(details.id),
      imdbId: Value(isMovie ? details.imdbId : null),
      title: Value(isMovie ? details.title : details.name),
      originalTitle: Value(isMovie ? details.originalTitle : details.originalName),
      overview: Value(details.overview),
      posterPath: Value(details.posterPath != null ? '$_imageBaseUrl/w500${details.posterPath}' : null),
      backdropPath: Value(details.backdropPath != null ? '$_imageBaseUrl/w1280${details.backdropPath}' : null),
      voteAverage: Value(details.voteAverage),
      voteCount: Value(details.voteCount),
      releaseDate: Value(isMovie ? details.releaseDate : details.firstAirDate),
      runtime: Value(isMovie ? details.runtime : (details.episodeRunTime?.isNotEmpty == true ? details.episodeRunTime.first : null)),
      genres: Value(jsonEncode(details.genres.map((g) => g.name).toList())),
      cast: Value(jsonEncode(details.cast.take(10).map((c) => {'name': c.name, 'character': c.character, 'profile': c.profilePath}).toList())),
      director: Value(details.director),
      productionCompanies: Value(jsonEncode(details.productionCompanies.map((c) => c.name).toList())),
      similarContent: Value(jsonEncode(details.similar.take(10).map((s) => s.id).toList())),
      keywords: Value(jsonEncode(details.keywords.map((k) => k.name).toList())),
      certifications: Value(jsonEncode(details.certifications)),
      budget: Value(isMovie ? details.budget : null),
      revenue: Value(isMovie ? details.revenue : null),
      fetchedAt: Value(now),
      updatedAt: Value(now),
    );
  }

  /// Get cached details from database
  Future<ContentDetailsData?> getCachedDetails(String contentId, String playlistId) async {
    return _database.getContentDetails(contentId, playlistId);
  }

  /// Get poster URL
  static String? getPosterUrl(String? posterPath, {String size = 'w500'}) {
    if (posterPath == null || posterPath.isEmpty) return null;
    if (posterPath.startsWith('http')) return posterPath;
    return '$_imageBaseUrl/$size$posterPath';
  }

  /// Get backdrop URL
  static String? getBackdropUrl(String? backdropPath, {String size = 'w1280'}) {
    if (backdropPath == null || backdropPath.isEmpty) return null;
    if (backdropPath.startsWith('http')) return backdropPath;
    return '$_imageBaseUrl/$size$backdropPath';
  }

  /// Get profile image URL
  static String? getProfileUrl(String? profilePath, {String size = 'w185'}) {
    if (profilePath == null || profilePath.isEmpty) return null;
    if (profilePath.startsWith('http')) return profilePath;
    return '$_imageBaseUrl/$size$profilePath';
  }
}

/// Search result from TMDB
class TmdbSearchResult {
  final int id;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String? releaseDate;
  final List<int> genreIds;

  TmdbSearchResult({
    required this.id,
    required this.mediaType,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    this.releaseDate,
    required this.genreIds,
  });

  factory TmdbSearchResult.fromJson(Map<String, dynamic> json, String mediaType) {
    final isMovie = mediaType == 'movie';
    return TmdbSearchResult(
      id: json['id'] ?? 0,
      mediaType: mediaType,
      title: isMovie ? (json['title'] ?? '') : (json['name'] ?? ''),
      originalTitle: isMovie ? json['original_title'] : json['original_name'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      releaseDate: isMovie ? json['release_date'] : json['first_air_date'],
      genreIds: (json['genre_ids'] as List?)?.cast<int>() ?? [],
    );
  }

  int? get year {
    if (releaseDate == null || releaseDate!.isEmpty) return null;
    return int.tryParse(releaseDate!.split('-').first);
  }
}

/// Genre info
class TmdbGenre {
  final int id;
  final String name;

  TmdbGenre({required this.id, required this.name});

  factory TmdbGenre.fromJson(Map<String, dynamic> json) {
    return TmdbGenre(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

/// Cast member info
class TmdbCastMember {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;
  final int order;

  TmdbCastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
    required this.order,
  });

  factory TmdbCastMember.fromJson(Map<String, dynamic> json) {
    return TmdbCastMember(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      character: json['character'],
      profilePath: json['profile_path'],
      order: json['order'] ?? 999,
    );
  }
}

/// Crew member info
class TmdbCrewMember {
  final int id;
  final String name;
  final String? job;
  final String? department;
  final String? profilePath;

  TmdbCrewMember({
    required this.id,
    required this.name,
    this.job,
    this.department,
    this.profilePath,
  });

  factory TmdbCrewMember.fromJson(Map<String, dynamic> json) {
    return TmdbCrewMember(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      job: json['job'],
      department: json['department'],
      profilePath: json['profile_path'],
    );
  }
}

/// Production company info
class TmdbProductionCompany {
  final int id;
  final String name;
  final String? logoPath;
  final String? originCountry;

  TmdbProductionCompany({
    required this.id,
    required this.name,
    this.logoPath,
    this.originCountry,
  });

  factory TmdbProductionCompany.fromJson(Map<String, dynamic> json) {
    return TmdbProductionCompany(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      logoPath: json['logo_path'],
      originCountry: json['origin_country'],
    );
  }
}

/// Keyword info
class TmdbKeyword {
  final int id;
  final String name;

  TmdbKeyword({required this.id, required this.name});

  factory TmdbKeyword.fromJson(Map<String, dynamic> json) {
    return TmdbKeyword(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

/// Movie details from TMDB
class TmdbMovieDetails {
  final int id;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String? releaseDate;
  final int? runtime;
  final String? imdbId;
  final int? budget; // Production budget in USD
  final int? revenue; // Box office revenue in USD
  final List<TmdbGenre> genres;
  final List<TmdbCastMember> cast;
  final List<TmdbCrewMember> crew;
  final List<TmdbProductionCompany> productionCompanies;
  final List<TmdbSearchResult> similar;
  final List<TmdbKeyword> keywords;
  final Map<String, String> certifications; // country -> certification

  TmdbMovieDetails({
    required this.id,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    this.releaseDate,
    this.runtime,
    this.imdbId,
    this.budget,
    this.revenue,
    required this.genres,
    required this.cast,
    required this.crew,
    required this.productionCompanies,
    required this.similar,
    required this.keywords,
    required this.certifications,
  });

  factory TmdbMovieDetails.fromJson(Map<String, dynamic> json) {
    // Parse cast
    final castList = <TmdbCastMember>[];
    if (json['credits']?['cast'] != null) {
      for (final c in json['credits']['cast']) {
        castList.add(TmdbCastMember.fromJson(c));
      }
      castList.sort((a, b) => a.order.compareTo(b.order));
    }

    // Parse crew
    final crewList = <TmdbCrewMember>[];
    if (json['credits']?['crew'] != null) {
      for (final c in json['credits']['crew']) {
        crewList.add(TmdbCrewMember.fromJson(c));
      }
    }

    // Parse similar
    final similarList = <TmdbSearchResult>[];
    if (json['similar']?['results'] != null) {
      for (final s in json['similar']['results']) {
        similarList.add(TmdbSearchResult.fromJson(s, 'movie'));
      }
    }

    // Parse keywords
    final keywordsList = <TmdbKeyword>[];
    if (json['keywords']?['keywords'] != null) {
      for (final k in json['keywords']['keywords']) {
        keywordsList.add(TmdbKeyword.fromJson(k));
      }
    }

    // Parse certifications (release_dates)
    final certs = <String, String>{};
    if (json['release_dates']?['results'] != null) {
      for (final result in json['release_dates']['results']) {
        final country = result['iso_3166_1'] as String?;
        final releases = result['release_dates'] as List?;
        if (country != null && releases != null && releases.isNotEmpty) {
          for (final release in releases) {
            final cert = release['certification'] as String?;
            if (cert != null && cert.isNotEmpty) {
              certs[country] = cert;
              break;
            }
          }
        }
      }
    }

    return TmdbMovieDetails(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      releaseDate: json['release_date'],
      runtime: json['runtime'],
      imdbId: json['imdb_id'],
      budget: json['budget'] as int?,
      revenue: json['revenue'] as int?,
      genres: (json['genres'] as List?)?.map((g) => TmdbGenre.fromJson(g)).toList() ?? [],
      cast: castList,
      crew: crewList,
      productionCompanies: (json['production_companies'] as List?)?.map((c) => TmdbProductionCompany.fromJson(c)).toList() ?? [],
      similar: similarList,
      keywords: keywordsList,
      certifications: certs,
    );
  }

  /// Get director name from crew
  String? get director {
    try {
      return crew.firstWhere((c) => c.job == 'Director').name;
    } catch (_) {
      return null;
    }
  }

  int? get year {
    if (releaseDate == null || releaseDate!.isEmpty) return null;
    return int.tryParse(releaseDate!.split('-').first);
  }
}

/// TV series details from TMDB
class TmdbTvDetails {
  final int id;
  final String name;
  final String? originalName;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String? firstAirDate;
  final String? lastAirDate;
  final List<int>? episodeRunTime;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final String? status;
  final List<TmdbGenre> genres;
  final List<TmdbCastMember> cast;
  final List<TmdbCrewMember> crew;
  final List<TmdbProductionCompany> productionCompanies;
  final List<TmdbSearchResult> similar;
  final List<TmdbKeyword> keywords;
  final Map<String, String> certifications;

  TmdbTvDetails({
    required this.id,
    required this.name,
    this.originalName,
    this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    this.firstAirDate,
    this.lastAirDate,
    this.episodeRunTime,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.status,
    required this.genres,
    required this.cast,
    required this.crew,
    required this.productionCompanies,
    required this.similar,
    required this.keywords,
    required this.certifications,
  });

  factory TmdbTvDetails.fromJson(Map<String, dynamic> json) {
    // Parse cast
    final castList = <TmdbCastMember>[];
    if (json['credits']?['cast'] != null) {
      for (final c in json['credits']['cast']) {
        castList.add(TmdbCastMember.fromJson(c));
      }
      castList.sort((a, b) => a.order.compareTo(b.order));
    }

    // Parse crew
    final crewList = <TmdbCrewMember>[];
    if (json['credits']?['crew'] != null) {
      for (final c in json['credits']['crew']) {
        crewList.add(TmdbCrewMember.fromJson(c));
      }
    }

    // Parse similar
    final similarList = <TmdbSearchResult>[];
    if (json['similar']?['results'] != null) {
      for (final s in json['similar']['results']) {
        similarList.add(TmdbSearchResult.fromJson(s, 'tv'));
      }
    }

    // Parse keywords
    final keywordsList = <TmdbKeyword>[];
    if (json['keywords']?['results'] != null) {
      for (final k in json['keywords']['results']) {
        keywordsList.add(TmdbKeyword.fromJson(k));
      }
    }

    // Parse certifications (content_ratings)
    final certs = <String, String>{};
    if (json['content_ratings']?['results'] != null) {
      for (final result in json['content_ratings']['results']) {
        final country = result['iso_3166_1'] as String?;
        final rating = result['rating'] as String?;
        if (country != null && rating != null && rating.isNotEmpty) {
          certs[country] = rating;
        }
      }
    }

    return TmdbTvDetails(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      originalName: json['original_name'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      firstAirDate: json['first_air_date'],
      lastAirDate: json['last_air_date'],
      episodeRunTime: (json['episode_run_time'] as List?)?.cast<int>(),
      numberOfSeasons: json['number_of_seasons'],
      numberOfEpisodes: json['number_of_episodes'],
      status: json['status'],
      genres: (json['genres'] as List?)?.map((g) => TmdbGenre.fromJson(g)).toList() ?? [],
      cast: castList,
      crew: crewList,
      productionCompanies: (json['production_companies'] as List?)?.map((c) => TmdbProductionCompany.fromJson(c)).toList() ?? [],
      similar: similarList,
      keywords: keywordsList,
      certifications: certs,
    );
  }

  /// Get show runner/creator from crew
  String? get director {
    try {
      final creator = crew.firstWhere((c) => c.job == 'Executive Producer' || c.job == 'Creator');
      return creator.name;
    } catch (_) {
      return null;
    }
  }

  int? get year {
    if (firstAirDate == null || firstAirDate!.isEmpty) return null;
    return int.tryParse(firstAirDate!.split('-').first);
  }
}
