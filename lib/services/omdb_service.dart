import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:another_iptv_player/repositories/user_preferences.dart';

/// OMDB API service for fetching IMDB ratings and Rotten Tomatoes scores
/// API documentation: http://www.omdbapi.com/
class OmdbService {
  static const String _baseUrl = 'http://www.omdbapi.com/';

  String? _apiKey;

  /// Initialize the service with stored API key
  Future<void> initialize() async {
    _apiKey = await UserPreferences.getOmdbApiKey();
  }

  /// Check if the service is configured with an API key
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Set API key
  Future<void> setApiKey(String apiKey) async {
    _apiKey = apiKey;
    await UserPreferences.setOmdbApiKey(apiKey);
  }

  /// Get current API key
  String? get apiKey => _apiKey;

  /// Get movie/series details by IMDB ID
  Future<OmdbDetails?> getDetailsByImdbId(String imdbId) async {
    if (!isConfigured) return null;
    if (imdbId.isEmpty) return null;

    try {
      final params = <String, String>{
        'apikey': _apiKey!,
        'i': imdbId,
        'plot': 'full',
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if the response contains an error
        if (data['Response'] == 'False') {
          debugPrint('OMDB API error: ${data['Error']}');
          return null;
        }

        return OmdbDetails.fromJson(data);
      }

      return null;
    } catch (e) {
      debugPrint('OMDB get details error: $e');
      return null;
    }
  }

  /// Get movie/series details by title and year
  Future<OmdbDetails?> getDetailsByTitle(String title, {int? year}) async {
    if (!isConfigured) return null;
    if (title.isEmpty) return null;

    try {
      final params = <String, String>{
        'apikey': _apiKey!,
        't': title,
        'plot': 'full',
      };
      if (year != null) params['y'] = year.toString();

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if the response contains an error
        if (data['Response'] == 'False') {
          debugPrint('OMDB API error: ${data['Error']}');
          return null;
        }

        return OmdbDetails.fromJson(data);
      }

      return null;
    } catch (e) {
      debugPrint('OMDB get details error: $e');
      return null;
    }
  }
}

/// OMDB details model
class OmdbDetails {
  final String imdbId;
  final String title;
  final String? year;
  final String? rated; // Rating like "PG-13", "R", etc.
  final String? released;
  final String? runtime;
  final String? genre;
  final String? director;
  final String? writer;
  final String? actors;
  final String? plot;
  final String? language;
  final String? country;
  final String? awards;
  final String? poster;
  final List<Rating> ratings;
  final String? imdbRating;
  final String? imdbVotes;
  final String? metascore;
  final String? type; // "movie", "series", "episode"

  OmdbDetails({
    required this.imdbId,
    required this.title,
    this.year,
    this.rated,
    this.released,
    this.runtime,
    this.genre,
    this.director,
    this.writer,
    this.actors,
    this.plot,
    this.language,
    this.country,
    this.awards,
    this.poster,
    required this.ratings,
    this.imdbRating,
    this.imdbVotes,
    this.metascore,
    this.type,
  });

  factory OmdbDetails.fromJson(Map<String, dynamic> json) {
    final ratingsList = json['Ratings'] as List? ?? [];
    final ratings = ratingsList
        .map((r) => Rating.fromJson(r as Map<String, dynamic>))
        .toList();

    return OmdbDetails(
      imdbId: json['imdbID'] ?? '',
      title: json['Title'] ?? '',
      year: json['Year'],
      rated: json['Rated'],
      released: json['Released'],
      runtime: json['Runtime'],
      genre: json['Genre'],
      director: json['Director'],
      writer: json['Writer'],
      actors: json['Actors'],
      plot: json['Plot'],
      language: json['Language'],
      country: json['Country'],
      awards: json['Awards'],
      poster: json['Poster'],
      ratings: ratings,
      imdbRating: json['imdbRating'],
      imdbVotes: json['imdbVotes'],
      metascore: json['Metascore'],
      type: json['Type'],
    );
  }

  /// Get Rotten Tomatoes score
  String? get rottenTomatoesScore {
    final rtRating = ratings.firstWhere(
      (r) => r.source == 'Rotten Tomatoes',
      orElse: () => Rating(source: '', value: ''),
    );
    return rtRating.value.isNotEmpty ? rtRating.value : null;
  }

  /// Get Metacritic score
  String? get metacriticScore {
    final mcRating = ratings.firstWhere(
      (r) => r.source == 'Metacritic',
      orElse: () => Rating(source: '', value: ''),
    );
    return mcRating.value.isNotEmpty ? mcRating.value : null;
  }
}

/// Rating from various sources (IMDB, Rotten Tomatoes, Metacritic)
class Rating {
  final String source;
  final String value;

  Rating({
    required this.source,
    required this.value,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      source: json['Source'] ?? '',
      value: json['Value'] ?? '',
    );
  }
}
