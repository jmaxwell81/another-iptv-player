import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:another_iptv_player/database/drift_flutter.dart';
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/live_stream.dart';
import 'package:another_iptv_player/models/series.dart';
import 'package:another_iptv_player/models/vod_streams.dart';
import 'package:another_iptv_player/models/server_info.dart';
import 'package:another_iptv_player/models/user_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/category_type.dart';
import '../models/m3u_item.dart';
import '../models/m3u_series.dart';
import '../models/playlist_model.dart';
import '../models/playlist_url.dart';
import '../models/favorite.dart';

part 'database.g.dart';

@DataClassName('PlaylistData')
class Playlists extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get url => text().nullable()();

  TextColumn get username => text().nullable()();

  TextColumn get password => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// JSON-encoded list of additional URLs
  TextColumn get additionalUrls => text().withDefault(const Constant('[]'))();

  /// Index of currently active URL (0 = primary)
  IntColumn get activeUrlIndex => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoriesData')
class Categories extends Table {
  TextColumn get categoryId => text()();

  TextColumn get categoryName => text()();

  IntColumn get parentId => integer().withDefault(const Constant(0))();

  TextColumn get playlistId => text()();

  TextColumn get type => text()(); // 'live', 'vod', 'series'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {categoryId, playlistId, type};
}

@DataClassName('UserInfosData')
class UserInfos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get playlistId => text()();

  TextColumn get username => text()();

  TextColumn get password => text()();

  TextColumn get message => text()();

  IntColumn get auth => integer()();

  TextColumn get status => text()();

  TextColumn get expDate => text()();

  TextColumn get isTrial => text()();

  TextColumn get activeCons => text()();

  TextColumn get createdAt => text()();

  TextColumn get maxConnections => text()();

  TextColumn get allowedOutputFormats => text()();
}

@DataClassName('ServerInfosData')
class ServerInfos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get playlistId => text()();

  TextColumn get url => text()();

  TextColumn get port => text()();

  TextColumn get httpsPort => text()();

  TextColumn get serverProtocol => text()();

  TextColumn get rtmpPort => text()();

  TextColumn get timezone => text()();

  IntColumn get timestampNow => integer()();

  TextColumn get timeNow => text()();
}

@DataClassName('LiveStreamsData')
class LiveStreams extends Table {
  TextColumn get streamId => text()();

  TextColumn get name => text()();

  TextColumn get streamIcon => text()();

  TextColumn get categoryId => text()();

  TextColumn get epgChannelId => text()();

  TextColumn get playlistId => text()(); // Ekstra property
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {streamId, playlistId};
}

@DataClassName('VodStreamsData')
class VodStreams extends Table {
  TextColumn get streamId => text()();

  TextColumn get name => text()();

  TextColumn get streamIcon => text()();

  TextColumn get categoryId => text()();

  TextColumn get rating => text()();

  RealColumn get rating5based => real()();

  TextColumn get containerExtension => text()();

  TextColumn get playlistId => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get genre => text().nullable()();

  TextColumn get youtubeTrailer => text().nullable()();

  @override
  Set<Column> get primaryKey => {streamId, playlistId};
}

@DataClassName('SeriesStreamsData')
class SeriesStreams extends Table {
  TextColumn get seriesId => text()();

  TextColumn get name => text()();

  TextColumn get cover => text().nullable()();

  TextColumn get plot => text().nullable()();

  TextColumn get cast => text().nullable()();

  TextColumn get director => text().nullable()();

  TextColumn get genre => text().nullable()();

  TextColumn get releaseDate => text().nullable()();

  TextColumn get rating => text().nullable()();

  RealColumn get rating5based => real().nullable()();

  TextColumn get youtubeTrailer => text().nullable()();

  TextColumn get episodeRunTime => text().nullable()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get playlistId => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get lastModified => text().nullable()();

  TextColumn get backdropPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {seriesId, playlistId};
}

@DataClassName('SeriesInfosData')
class SeriesInfos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get seriesId => text()();

  TextColumn get name => text()();

  TextColumn get cover => text().nullable()();

  TextColumn get plot => text().nullable()();

  TextColumn get cast => text().nullable()();

  TextColumn get director => text().nullable()();

  TextColumn get genre => text().nullable()();

  TextColumn get releaseDate => text().nullable()();

  TextColumn get lastModified => text().nullable()();

  TextColumn get rating => text().nullable()();

  IntColumn get rating5based => integer().nullable()();

  TextColumn get backdropPath => text().nullable()();

  TextColumn get youtubeTrailer => text().nullable()();

  TextColumn get episodeRunTime => text().nullable()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get playlistId => text()();
}

@DataClassName('SeasonsData')
class Seasons extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get seriesId => text()();

  TextColumn get airDate => text().nullable()();

  IntColumn get episodeCount => integer().nullable()();

  IntColumn get seasonId => integer()();

  TextColumn get name => text()();

  TextColumn get overview => text().nullable()();

  IntColumn get seasonNumber => integer()();

  IntColumn get voteAverage => integer().nullable()();

  TextColumn get cover => text().nullable()();

  TextColumn get coverBig => text().nullable()();

  TextColumn get playlistId => text()();
}

@DataClassName('EpisodesData')
class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get seriesId => text()();

  TextColumn get episodeId => text()();

  IntColumn get episodeNum => integer()();

  TextColumn get title => text()();

  TextColumn get containerExtension => text().nullable()();

  IntColumn get season => integer()();

  TextColumn get customSid => text().nullable()();

  TextColumn get added => text().nullable()();

  TextColumn get directSource => text().nullable()();

  TextColumn get playlistId => text()();

  // Episode Info
  IntColumn get tmdbId => integer().nullable()();

  TextColumn get releasedate => text().nullable()();

  TextColumn get plot => text().nullable()();

  IntColumn get durationSecs => integer().nullable()();

  TextColumn get duration => text().nullable()();

  TextColumn get movieImage => text().nullable()();

  IntColumn get bitrate => integer().nullable()();

  RealColumn get rating => real().nullable()();
}

@DataClassName('WatchHistoriesData')
class WatchHistories extends Table {
  TextColumn get playlistId => text()();

  IntColumn get contentType => intEnum<ContentType>()();

  TextColumn get streamId => text()();

  TextColumn get seriesId => text().nullable()();

  IntColumn get seasonNumber => integer().nullable()();

  IntColumn get episodeNumber => integer().nullable()();

  IntColumn get totalEpisodes => integer().nullable()();

  IntColumn get watchDuration => integer().nullable()();

  IntColumn get totalDuration => integer().nullable()();

  DateTimeColumn get lastWatched => dateTime()();

  TextColumn get imagePath => text().nullable()();

  TextColumn get title => text()();

  @override
  Set<Column> get primaryKey => {playlistId, streamId};
}

@DataClassName('M3uItemData')
class M3uItems extends Table {
  TextColumn get id => text()();

  TextColumn get playlistId => text()();

  TextColumn get url => text()();

  TextColumn get name => text().nullable()();

  TextColumn get tvgId => text().nullable()();

  TextColumn get tvgName => text().nullable()();

  TextColumn get tvgLogo => text().nullable()();

  TextColumn get tvgUrl => text().nullable()();

  TextColumn get tvgRec => text().nullable()();

  TextColumn get tvgShift => text().nullable()();

  TextColumn get groupTitle => text().nullable()();

  TextColumn get groupName => text().nullable()();

  TextColumn get userAgent => text().nullable()();

  TextColumn get referrer => text().nullable()();

  TextColumn get categoryId => text().nullable()();

  IntColumn get contentType => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (LENGTH(id) > 0)',
    'CHECK (LENGTH(url) > 0)',
    'CHECK (LENGTH(playlist_id) > 0)',
  ];
}

@DataClassName('M3uSeriesData')
class M3uSeries extends Table {
  TextColumn get playlistId => text()();

  TextColumn get seriesId => text()();

  TextColumn get name => text()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get cover => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {playlistId, seriesId};
}

@DataClassName('M3uEpisodesData')
class M3uEpisodes extends Table {
  TextColumn get playlistId => text()();

  TextColumn get seriesId => text()();

  IntColumn get seasonNumber => integer()();

  IntColumn get episodeNumber => integer()();

  TextColumn get name => text()();

  TextColumn get url => text()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get cover => text().nullable()();

  @override
  Set<Column> get primaryKey => {
    playlistId,
    seriesId,
    seasonNumber,
    episodeNumber,
  };
}

@DataClassName('FavoritesData')
class Favorites extends Table {
  TextColumn get id => text()();

  TextColumn get playlistId => text()();

  IntColumn get contentType => integer()();

  TextColumn get streamId => text()();

  TextColumn get episodeId => text().nullable()();

  TextColumn get m3uItemId => text().nullable()();

  TextColumn get name => text()();

  TextColumn get imagePath => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HiddenItemsData')
class HiddenItems extends Table {
  TextColumn get id => text()();

  TextColumn get playlistId => text()();

  IntColumn get contentType => integer()();

  TextColumn get streamId => text()();

  TextColumn get name => text()();

  TextColumn get imagePath => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OfflineItemsData')
class OfflineItems extends Table {
  TextColumn get id => text()();

  TextColumn get playlistId => text()();

  IntColumn get contentType => integer()();

  TextColumn get streamId => text()();

  TextColumn get name => text()();

  TextColumn get imagePath => text().nullable()();

  DateTimeColumn get markedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get autoDetected => boolean().withDefault(const Constant(false))();

  DateTimeColumn get temporaryUntil => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EpgProgramData')
class EpgPrograms extends Table {
  TextColumn get id => text()();  // channelId_startTime_playlistId
  TextColumn get channelId => text()();
  TextColumn get playlistId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  TextColumn get category => text().nullable()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EpgChannelData')
class EpgChannels extends Table {
  TextColumn get channelId => text()();
  TextColumn get playlistId => text()();
  TextColumn get displayName => text()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {channelId, playlistId};
}

@DataClassName('EpgSourceData')
class EpgSources extends Table {
  TextColumn get playlistId => text()();
  TextColumn get epgUrl => text().nullable()();
  BoolColumn get useDefaultUrl => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastFetched => dateTime().nullable()();
  IntColumn get programCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {playlistId};
}

/// Stores multiple URLs per playlist with health status
@DataClassName('PlaylistUrlData')
class PlaylistUrls extends Table {
  TextColumn get id => text()(); // playlistId_index
  TextColumn get playlistId => text()();
  TextColumn get url => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 0 = primary
  IntColumn get status => integer().withDefault(const Constant(0))(); // UrlStatus enum
  DateTimeColumn get lastChecked => dateTime().nullable()();
  DateTimeColumn get lastSuccessful => dateTime().nullable()();
  IntColumn get failureCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get responseTimeMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached subtitles downloaded from OpenSubtitles
@DataClassName('CachedSubtitleData')
class CachedSubtitles extends Table {
  TextColumn get id => text()(); // Unique ID (hash of contentId + language)
  TextColumn get contentId => text()(); // Stream ID or movie/series ID
  TextColumn get contentType => text()(); // 'vod', 'series', 'live'
  TextColumn get contentName => text()(); // Name of the content for display
  TextColumn get language => text()(); // ISO 639-1 language code
  TextColumn get languageName => text()(); // Human-readable language name
  TextColumn get subtitleFormat => text()(); // 'srt', 'vtt', 'ass', etc.
  TextColumn get filePath => text()(); // Local file path to cached subtitle
  TextColumn get openSubtitlesId => text().nullable()(); // OpenSubtitles file ID
  IntColumn get downloadCount => integer().nullable()(); // OpenSubtitles download count
  RealColumn get matchScore => real().nullable()(); // Match confidence score
  DateTimeColumn get downloadedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached movie/series details from TMDB
@DataClassName('ContentDetailsData')
class ContentDetails extends Table {
  TextColumn get id => text()(); // contentId_playlistId
  TextColumn get contentId => text()(); // Stream ID
  TextColumn get playlistId => text()();
  TextColumn get contentType => text()(); // 'vod', 'series'
  IntColumn get tmdbId => integer().nullable()(); // TMDB ID
  TextColumn get imdbId => text().nullable()(); // IMDB ID
  TextColumn get title => text()();
  TextColumn get originalTitle => text().nullable()();
  TextColumn get overview => text().nullable()(); // Plot/description
  TextColumn get posterPath => text().nullable()(); // TMDB poster URL
  TextColumn get backdropPath => text().nullable()(); // TMDB backdrop URL
  RealColumn get voteAverage => real().nullable()(); // TMDB rating (0-10)
  IntColumn get voteCount => integer().nullable()();
  TextColumn get releaseDate => text().nullable()();
  IntColumn get runtime => integer().nullable()(); // Runtime in minutes
  TextColumn get genres => text().nullable()(); // JSON array of genres
  TextColumn get cast => text().nullable()(); // JSON array of cast members
  TextColumn get director => text().nullable()();
  TextColumn get productionCompanies => text().nullable()(); // JSON array
  TextColumn get similarContent => text().nullable()(); // JSON array of similar TMDB IDs
  TextColumn get keywords => text().nullable()(); // JSON array of keywords
  TextColumn get certifications => text().nullable()(); // Content ratings by region
  IntColumn get budget => integer().nullable()(); // Production budget in USD
  IntColumn get revenue => integer().nullable()(); // Box office revenue in USD
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Playlists,
    Categories,
    UserInfos,
    ServerInfos,
    LiveStreams,
    VodStreams,
    SeriesStreams,
    SeriesInfos,
    Seasons,
    Episodes,
    WatchHistories,
    M3uItems,
    M3uSeries,
    M3uEpisodes,
    Favorites,
    HiddenItems,
    OfflineItems,
    EpgPrograms,
    EpgChannels,
    EpgSources,
    PlaylistUrls,
    CachedSubtitles,
    ContentDetails,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
    : super(
        e ??
            driftDatabase(
              name: 'another-iptv-player',
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
                onResult: (result) {
                  if (result.missingFeatures.isNotEmpty) {
                    debugPrint(
                      'Using ${result.chosenImplementation} due to unsupported '
                      'browser features: ${result.missingFeatures}',
                    );
                  }
                },
              ),
            ),
      );

  @override
  int get schemaVersion => 14;

  // === PLAYLIST İŞLEMLERİ ===

  // Playlist oluştur
  Future<void> insertPlaylist(Playlist playlist) async {
    await into(playlists).insert(
      PlaylistsCompanion(
        id: Value(playlist.id),
        name: Value(playlist.name),
        type: Value(playlist.type.toString()),
        url: Value(playlist.url),
        username: Value(playlist.username),
        password: Value(playlist.password),
        createdAt: Value(playlist.createdAt),
        additionalUrls: Value(_encodeUrlList(playlist.additionalUrls)),
        activeUrlIndex: Value(playlist.activeUrlIndex),
      ),
    );
  }

  /// Encode URL list to JSON string for storage
  String _encodeUrlList(List<String> urls) {
    return urls.join('|||'); // Use separator instead of JSON for simplicity
  }

  /// Decode URL list from stored string
  List<String> _decodeUrlList(String? encoded) {
    if (encoded == null || encoded.isEmpty || encoded == '[]') {
      return [];
    }
    return encoded.split('|||').where((u) => u.isNotEmpty).toList();
  }

  // Tüm playlistleri getir
  Future<List<Playlist>> getAllPlaylists() async {
    final playlistData = await select(playlists).get();
    return playlistData.map((data) => _convertToPlaylist(data)).toList();
  }

  // ID'ye göre playlist getir
  Future<Playlist?> getPlaylistById(String id) async {
    final query = select(playlists)..where((p) => p.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _convertToPlaylist(result) : null;
  }

  // Playlist sil
  Future<void> deletePlaylistById(String id) async {
    // Önce playlist'e ait kategorileri sil
    await deleteAllCategoriesByPlaylist(id);
    // Sonra playlist'i sil
    await (delete(playlists)..where((p) => p.id.equals(id))).go();
  }

  // Playlist güncelle
  Future<void> updatePlaylist(Playlist playlist) async {
    await (update(playlists)..where((p) => p.id.equals(playlist.id))).write(
      PlaylistsCompanion(
        name: Value(playlist.name),
        type: Value(playlist.type.toString()),
        url: Value(playlist.url),
        username: Value(playlist.username),
        password: Value(playlist.password),
        additionalUrls: Value(_encodeUrlList(playlist.additionalUrls)),
        activeUrlIndex: Value(playlist.activeUrlIndex),
      ),
    );
  }

  /// Update only the active URL index for a playlist
  Future<void> updatePlaylistActiveUrlIndex(String playlistId, int? index) async {
    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(activeUrlIndex: Value(index)),
    );
  }

  // Tip filtreleme
  Future<List<Playlist>> getPlaylistsByType(PlaylistType type) async {
    final query = select(playlists)
      ..where((p) => p.type.equals(type.toString()));
    final playlistData = await query.get();
    return playlistData.map((data) => _convertToPlaylist(data)).toList();
  }

  // === KATEGORİ İŞLEMLERİ ===

  // Kategorileri tip ve playlist'e göre getir
  Future<List<Category>> getCategoriesByTypeAndPlaylist(
    String playlistId,
    CategoryType type,
  ) async {
    final categoriesData =
        await (select(categories)..where(
              (tbl) =>
                  tbl.playlistId.equals(playlistId) &
                  tbl.type.equals(type.value),
            ))
            .get();

    return categoriesData.map((cat) => Category.fromDrift(cat)).toList();
  }

  Future<List<Category>> getCategoriesByPlaylist(String playlistId) async {
    final categoriesData = await (select(
      categories,
    )..where((tbl) => tbl.playlistId.equals(playlistId))).get();

    return categoriesData.map((cat) => Category.fromDrift(cat)).toList();
  }

  Future<void> insertCategories(List<Category> categoryList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        categories,
        categoryList.map((cat) => cat.toCompanion()).toList(),
      );
    });
  }

  // Belirli tip ve playlist'teki kategorileri sil
  Future<void> deleteCategoriesByTypeAndPlaylist(
    String playlistId,
    CategoryType type,
  ) async {
    await (delete(categories)..where(
          (tbl) =>
              tbl.playlistId.equals(playlistId) & tbl.type.equals(type.value),
        ))
        .go();
  }

  // Playlist'teki tüm kategorileri sil
  Future<void> deleteAllCategoriesByPlaylist(String playlistId) async {
    await (delete(
      categories,
    )..where((tbl) => tbl.playlistId.equals(playlistId))).go();
  }

  // Parent kategorileri getir
  Future<List<Category>> getParentCategories(
    String playlistId,
    CategoryType type,
  ) async {
    final categoriesData =
        await (select(categories)
              ..where(
                (tbl) =>
                    tbl.playlistId.equals(playlistId) &
                    tbl.type.equals(type.value) &
                    tbl.parentId.equals(0),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.categoryName)]))
            .get();

    return categoriesData.map((cat) => Category.fromDrift(cat)).toList();
  }

  // Alt kategorileri getir
  Future<List<Category>> getSubCategories(
    String playlistId,
    CategoryType type,
    String parentId,
  ) async {
    final categoriesData =
        await (select(categories)
              ..where(
                (tbl) =>
                    tbl.playlistId.equals(playlistId) &
                    tbl.type.equals(type.value) &
                    tbl.parentId.equals(int.parse(parentId)),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.categoryName)]))
            .get();

    return categoriesData.map((cat) => Category.fromDrift(cat)).toList();
  }

  // Kategori ara
  Future<List<Category>> searchCategories(
    String playlistId,
    CategoryType type,
    String query,
  ) async {
    final categoriesData =
        await (select(categories)
              ..where(
                (tbl) =>
                    tbl.playlistId.equals(playlistId) &
                    tbl.type.equals(type.value) &
                    tbl.categoryName.contains(query),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.categoryName)]))
            .get();

    return categoriesData.map((cat) => Category.fromDrift(cat)).toList();
  }

  // Kategori sayısını getir
  Future<int> getCategoryCount(String playlistId, CategoryType type) async {
    final result =
        await (select(categories)..where(
              (tbl) =>
                  tbl.playlistId.equals(playlistId) &
                  tbl.type.equals(type.value),
            ))
            .get();

    return result.length;
  }

  // Tüm kategorileri getir (tüm tipler)
  Future<Map<CategoryType, List<Category>>> getAllCategoriesByPlaylist(
    String playlistId,
  ) async {
    final allCategoriesData =
        await (select(categories)
              ..where((tbl) => tbl.playlistId.equals(playlistId))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.categoryName)]))
            .get();

    final result = <CategoryType, List<Category>>{};

    for (final type in CategoryType.values) {
      result[type] = allCategoriesData
          .where((cat) => cat.type == type.value)
          .map((cat) => Category.fromDrift(cat))
          .toList();
    }

    return result;
  }

  // Playlist'in kategori istatistiklerini getir
  Future<Map<CategoryType, int>> getCategoryStatsByPlaylist(
    String playlistId,
  ) async {
    final result = <CategoryType, int>{};

    for (final type in CategoryType.values) {
      final count = await getCategoryCount(playlistId, type);
      result[type] = count;
    }

    return result;
  }

  // Kategori ID'sine göre tek kategori getir
  Future<Category?> getCategoryById(
    String playlistId,
    String categoryId,
    CategoryType type,
  ) async {
    final query = select(categories)
      ..where(
        (tbl) =>
            tbl.playlistId.equals(playlistId) &
            tbl.categoryId.equals(categoryId) &
            tbl.type.equals(type.value),
      );

    final result = await query.getSingleOrNull();
    return result != null ? Category.fromDrift(result) : null;
  }

  // Kategori var mı kontrol et
  Future<bool> categoryExists(
    String playlistId,
    String categoryId,
    CategoryType type,
  ) async {
    final category = await getCategoryById(playlistId, categoryId, type);
    return category != null;
  }

  // === YARDIMCI METODLAR ===

  // PlaylistData'yı Playlist'e çevir
  Playlist _convertToPlaylist(PlaylistData data) {
    return Playlist(
      id: data.id,
      name: data.name,
      type: PlaylistType.values.firstWhere((e) => e.toString() == data.type),
      url: data.url,
      additionalUrls: _decodeUrlList(data.additionalUrls),
      username: data.username,
      password: data.password,
      createdAt: data.createdAt,
      activeUrlIndex: data.activeUrlIndex,
    );
  }

  // === USER INFO İŞLEMLERİ ===

  // UserInfo ekleme/güncelleme (upsert)
  Future<int> insertOrUpdateUserInfo(UserInfo userInfo) async {
    final existingUser = await getUserInfoByPlaylistId(userInfo.playlistId);

    if (existingUser != null) {
      // Güncelle
      return await (update(
        userInfos,
      )..where((tbl) => tbl.playlistId.equals(userInfo.playlistId))).write(
        UserInfosCompanion(
          username: Value(userInfo.username),
          password: Value(userInfo.password),
          message: Value(userInfo.message),
          auth: Value(userInfo.auth),
          status: Value(userInfo.status),
          expDate: Value(userInfo.expDate),
          isTrial: Value(userInfo.isTrial),
          activeCons: Value(userInfo.activeCons),
          createdAt: Value(userInfo.createdAt),
          maxConnections: Value(userInfo.maxConnections),
          allowedOutputFormats: Value(userInfo.allowedOutputFormats.join(',')),
        ),
      );
    } else {
      // Yeni ekle
      return await into(userInfos).insert(
        UserInfosCompanion.insert(
          playlistId: userInfo.playlistId,
          username: userInfo.username,
          password: userInfo.password,
          message: userInfo.message,
          auth: userInfo.auth,
          status: userInfo.status,
          expDate: userInfo.expDate,
          isTrial: userInfo.isTrial,
          activeCons: userInfo.activeCons,
          createdAt: userInfo.createdAt,
          maxConnections: userInfo.maxConnections,
          allowedOutputFormats: userInfo.allowedOutputFormats.join(','),
        ),
      );
    }
  }

  // PlaylistId'ye göre UserInfo getirme
  Future<UserInfo?> getUserInfoByPlaylistId(String playlistId) async {
    final query = select(userInfos)
      ..where((tbl) => tbl.playlistId.equals(playlistId));

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return UserInfo(
      id: result.id,
      playlistId: result.playlistId,
      username: result.username,
      password: result.password,
      message: result.message,
      auth: result.auth,
      status: result.status,
      expDate: result.expDate,
      isTrial: result.isTrial,
      activeCons: result.activeCons,
      createdAt: result.createdAt,
      maxConnections: result.maxConnections,
      allowedOutputFormats: result.allowedOutputFormats.isNotEmpty
          ? result.allowedOutputFormats.split(',')
          : [],
    );
  }

  // Tüm UserInfo'ları getirme
  Future<List<UserInfo>> getAllUserInfos() async {
    final results = await select(userInfos).get();
    return results
        .map(
          (result) => UserInfo(
            id: result.id,
            playlistId: result.playlistId,
            username: result.username,
            password: result.password,
            message: result.message,
            auth: result.auth,
            status: result.status,
            expDate: result.expDate,
            isTrial: result.isTrial,
            activeCons: result.activeCons,
            createdAt: result.createdAt,
            maxConnections: result.maxConnections,
            allowedOutputFormats: result.allowedOutputFormats.isNotEmpty
                ? result.allowedOutputFormats.split(',')
                : [],
          ),
        )
        .toList();
  }

  // PlaylistId'ye göre UserInfo silme
  Future<int> deleteUserInfoByPlaylistId(String playlistId) async {
    return await (delete(
      userInfos,
    )..where((tbl) => tbl.playlistId.equals(playlistId))).go();
  }

  // === SERVER INFO İŞLEMLERİ ===

  // ServerInfo ekleme/güncelleme (upsert)
  Future<int> insertOrUpdateServerInfo(ServerInfo serverInfo) async {
    final existingServer = await getServerInfoByPlaylistId(
      serverInfo.playlistId,
    );

    if (existingServer != null) {
      // Güncelle
      return await (update(
        serverInfos,
      )..where((tbl) => tbl.playlistId.equals(serverInfo.playlistId))).write(
        ServerInfosCompanion(
          url: Value(serverInfo.url),
          port: Value(serverInfo.port),
          httpsPort: Value(serverInfo.httpsPort),
          serverProtocol: Value(serverInfo.serverProtocol),
          rtmpPort: Value(serverInfo.rtmpPort),
          timezone: Value(serverInfo.timezone),
          timestampNow: Value(serverInfo.timestampNow),
          timeNow: Value(serverInfo.timeNow),
        ),
      );
    } else {
      // Yeni ekle
      return await into(serverInfos).insert(
        ServerInfosCompanion.insert(
          playlistId: serverInfo.playlistId,
          url: serverInfo.url,
          port: serverInfo.port,
          httpsPort: serverInfo.httpsPort,
          serverProtocol: serverInfo.serverProtocol,
          rtmpPort: serverInfo.rtmpPort,
          timezone: serverInfo.timezone,
          timestampNow: serverInfo.timestampNow,
          timeNow: serverInfo.timeNow,
        ),
      );
    }
  }

  // PlaylistId'ye göre ServerInfo getirme
  Future<ServerInfo?> getServerInfoByPlaylistId(String playlistId) async {
    final query = select(serverInfos)
      ..where((tbl) => tbl.playlistId.equals(playlistId));

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return ServerInfo(
      id: result.id,
      playlistId: result.playlistId,
      url: result.url,
      port: result.port,
      httpsPort: result.httpsPort,
      serverProtocol: result.serverProtocol,
      rtmpPort: result.rtmpPort,
      timezone: result.timezone,
      timestampNow: result.timestampNow,
      timeNow: result.timeNow,
    );
  }

  // Tüm ServerInfo'ları getirme
  Future<List<ServerInfo>> getAllServerInfos() async {
    final results = await select(serverInfos).get();
    return results
        .map(
          (result) => ServerInfo(
            id: result.id,
            playlistId: result.playlistId,
            url: result.url,
            port: result.port,
            httpsPort: result.httpsPort,
            serverProtocol: result.serverProtocol,
            rtmpPort: result.rtmpPort,
            timezone: result.timezone,
            timestampNow: result.timestampNow,
            timeNow: result.timeNow,
          ),
        )
        .toList();
  }

  // PlaylistId'ye göre ServerInfo silme
  Future<int> deleteServerInfoByPlaylistId(String playlistId) async {
    return await (delete(
      serverInfos,
    )..where((tbl) => tbl.playlistId.equals(playlistId))).go();
  }

  // Live Streams
  Future<void> insertLiveStreams(List<LiveStream> liveStreams) async {
    final liveStreamsCompanions = liveStreams
        .map(
          (liveStream) => LiveStreamsCompanion(
            streamId: Value(liveStream.streamId),
            name: Value(liveStream.name),
            streamIcon: Value(liveStream.streamIcon),
            categoryId: Value(liveStream.categoryId),
            epgChannelId: Value(liveStream.epgChannelId),
            playlistId: Value(liveStream.playlistId ?? ''),
          ),
        )
        .toList();

    await batch((batch) {
      batch.insertAllOnConflictUpdate(this.liveStreams, liveStreamsCompanions);
    });
  }

  Future<List<LiveStream>> getLiveStreams(String playlistId) async {
    final rows = await (select(
      liveStreams,
    )..where((ls) => ls.playlistId.equals(playlistId))).get();

    return rows.map((row) => LiveStream.fromDriftLiveStream(row)).toList();
  }

  Future<List<LiveStream>> getLiveStreamsByCategoryId(
    String playlistId,
    String categoryId, {
    int? top,
  }) async {
    var query = select(liveStreams)
      ..where(
        (ls) =>
            ls.playlistId.equals(playlistId) & ls.categoryId.equals(categoryId),
      );

    if (top != null) {
      query = query..limit(top);
    }

    final rows = await query.get();

    return rows.map((row) => LiveStream.fromDriftLiveStream(row)).toList();
  }

  Future<void> deleteLiveStreamsByPlaylistId(String playlistId) async {
    await (delete(
      liveStreams,
    )..where((ls) => ls.playlistId.equals(playlistId))).go();
  }

  // Vod Streams
  Future<void> insertVodStreams(List<VodStream> vodStreams) async {
    final vodStreamsCompanions = vodStreams
        .map((vodStream) => vodStream.toDriftCompanion())
        .toList();

    await batch((batch) {
      batch.insertAllOnConflictUpdate(this.vodStreams, vodStreamsCompanions);
    });
  }

  Future<List<VodStream>> getVodStreamsByPlaylistId(String playlistId) async {
    final rows = await (select(
      vodStreams,
    )..where((vs) => vs.playlistId.equals(playlistId))).get();

    return rows.map((row) => VodStream.fromDriftVodStream(row)).toList();
  }

  Future<List<VodStream>> getVodStreamsByCategoryAndPlaylistId({
    required String categoryId,
    required String playlistId,
    int? top,
  }) async {
    var query = select(vodStreams)
      ..where(
        (vs) =>
            vs.categoryId.equals(categoryId) & vs.playlistId.equals(playlistId),
      );

    if (top != null) {
      query = query..limit(top);
    }

    final rows = await query.get();

    return rows.map((row) => VodStream.fromDriftVodStream(row)).toList();
  }

  Future<List<VodStream>> getVodStreamsByCategory(String categoryId) async {
    final rows = await (select(
      vodStreams,
    )..where((vs) => vs.categoryId.equals(categoryId))).get();

    return rows.map((row) => VodStream.fromDriftVodStream(row)).toList();
  }

  Future<List<VodStream>> getVodStreamsFiltered({
    String? categoryId,
    String? playlistId,
    String? searchQuery,
  }) async {
    final query = select(vodStreams);

    if (categoryId != null && playlistId != null) {
      query.where(
        (vs) =>
            vs.categoryId.equals(categoryId) & vs.playlistId.equals(playlistId),
      );
    } else if (categoryId != null) {
      query.where((vs) => vs.categoryId.equals(categoryId));
    } else if (playlistId != null) {
      query.where((vs) => vs.playlistId.equals(playlistId));
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where((vs) => vs.name.like('%$searchQuery%'));
    }

    final rows = await query.get();
    return rows.map((row) => VodStream.fromDriftVodStream(row)).toList();
  }

  Future<void> deleteVodStreamsByPlaylistId(String playlistId) async {
    await (delete(
      vodStreams,
    )..where((vs) => vs.playlistId.equals(playlistId))).go();
  }

  Future<void> deleteVodStreamsByCategoryAndPlaylistId({
    required String categoryId,
    required String playlistId,
  }) async {
    await (delete(vodStreams)..where(
          (vs) =>
              vs.categoryId.equals(categoryId) &
              vs.playlistId.equals(playlistId),
        ))
        .go();
  }

  Future<void> insertSeriesStreams(List<SeriesStream> seriesStreams) async {
    final seriesStreamsCompanions = seriesStreams
        .map((seriesStream) => seriesStream.toDriftCompanion())
        .toList();

    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        this.seriesStreams,
        seriesStreamsCompanions,
      );
    });
  }

  Future<List<SeriesStream>> getSeriesStreamsByPlaylistId(
    String playlistId,
  ) async {
    final rows = await (select(
      seriesStreams,
    )..where((ss) => ss.playlistId.equals(playlistId))).get();

    return rows.map((row) => SeriesStream.fromDriftSeriesStream(row)).toList();
  }

  Future<List<SeriesStream>> getSeriesStreamsByCategoryAndPlaylistId({
    required String categoryId,
    required String playlistId,
    int? top,
  }) async {
    var query = select(seriesStreams)
      ..where(
        (ss) =>
            ss.categoryId.equals(categoryId) & ss.playlistId.equals(playlistId),
      );

    if (top != null) {
      query = query..limit(top);
    }

    final rows = await query.get();

    return rows.map((row) => SeriesStream.fromDriftSeriesStream(row)).toList();
  }

  Future<List<SeriesStream>> getSeriesStreamsByCategory(
    String categoryId,
  ) async {
    final rows = await (select(
      seriesStreams,
    )..where((ss) => ss.categoryId.equals(categoryId))).get();

    return rows.map((row) => SeriesStream.fromDriftSeriesStream(row)).toList();
  }

  Future<List<SeriesStream>> getSeriesStreamsFiltered({
    String? categoryId,
    String? playlistId,
    String? searchQuery,
  }) async {
    final query = select(seriesStreams);

    if (categoryId != null && playlistId != null) {
      query.where(
        (ss) =>
            ss.categoryId.equals(categoryId) & ss.playlistId.equals(playlistId),
      );
    } else if (categoryId != null) {
      query.where((ss) => ss.categoryId.equals(categoryId));
    } else if (playlistId != null) {
      query.where((ss) => ss.playlistId.equals(playlistId));
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where((ss) => ss.name.like('%$searchQuery%'));
    }

    final rows = await query.get();
    return rows.map((row) => SeriesStream.fromDriftSeriesStream(row)).toList();
  }

  Future<void> deleteSeriesStreamsByPlaylistId(String playlistId) async {
    await (delete(
      seriesStreams,
    )..where((ss) => ss.playlistId.equals(playlistId))).go();
  }

  Future<void> deleteSeriesStreamsByCategoryAndPlaylistId({
    required String categoryId,
    required String playlistId,
  }) async {
    await (delete(seriesStreams)..where(
          (ss) =>
              ss.categoryId.equals(categoryId) &
              ss.playlistId.equals(playlistId),
        ))
        .go();
  }

  // Content count methods for playlist stats
  Future<int> getLiveStreamCount(String playlistId) async {
    final result = await (select(liveStreams)
          ..where((tbl) => tbl.playlistId.equals(playlistId)))
        .get();
    return result.length;
  }

  Future<int> getVodStreamCount(String playlistId) async {
    final result = await (select(vodStreams)
          ..where((tbl) => tbl.playlistId.equals(playlistId)))
        .get();
    return result.length;
  }

  Future<int> getSeriesCount(String playlistId) async {
    final result = await (select(seriesStreams)
          ..where((tbl) => tbl.playlistId.equals(playlistId)))
        .get();
    return result.length;
  }

  Future<int> getM3uLiveCount(String playlistId) async {
    final result = await (select(m3uItems)
          ..where((tbl) =>
              tbl.playlistId.equals(playlistId) &
              tbl.contentType.equals(ContentType.liveStream.index)))
        .get();
    return result.length;
  }

  Future<int> getM3uMoviesCount(String playlistId) async {
    final result = await (select(m3uItems)
          ..where((tbl) =>
              tbl.playlistId.equals(playlistId) &
              tbl.contentType.equals(ContentType.vod.index)))
        .get();
    return result.length;
  }

  Future<int> getM3uSeriesCount(String playlistId) async {
    final result = await (select(m3uSeries)
          ..where((tbl) => tbl.playlistId.equals(playlistId)))
        .get();
    return result.length;
  }

  // New Releases queries - get recently added content
  /// Get movies added within the specified number of days
  Future<List<VodStream>> getRecentlyAddedMovies({
    required String playlistId,
    required int daysBack,
    int? limit,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

    var query = select(vodStreams)
      ..where((vs) =>
          vs.playlistId.equals(playlistId) &
          vs.createdAt.isBiggerOrEqualValue(cutoffDate))
      ..orderBy([(vs) => OrderingTerm.desc(vs.createdAt)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    final rows = await query.get();
    return rows.map((row) => VodStream.fromDriftVodStream(row)).toList();
  }

  /// Get series added within the specified number of days
  Future<List<SeriesStream>> getRecentlyAddedSeries({
    required String playlistId,
    required int daysBack,
    int? limit,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

    var query = select(seriesStreams)
      ..where((ss) =>
          ss.playlistId.equals(playlistId) &
          ss.createdAt.isBiggerOrEqualValue(cutoffDate))
      ..orderBy([(ss) => OrderingTerm.desc(ss.createdAt)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    final rows = await query.get();
    return rows.map((row) => SeriesStream.fromDriftSeriesStream(row)).toList();
  }

  /// Get M3U movies added within the specified number of days
  Future<List<M3uItem>> getRecentlyAddedM3uMovies({
    required String playlistId,
    required int daysBack,
    int? limit,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

    var query = select(m3uItems)
      ..where((item) =>
          item.playlistId.equals(playlistId) &
          item.contentType.equals(ContentType.vod.index) &
          item.createdAt.isBiggerOrEqualValue(cutoffDate))
      ..orderBy([(item) => OrderingTerm.desc(item.createdAt)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    final rows = await query.get();
    return rows.map((row) => M3uItem.fromData(row)).toList();
  }

  /// Get M3U series added within the specified number of days
  Future<List<M3uSeriesData>> getRecentlyAddedM3uSeries({
    required String playlistId,
    required int daysBack,
    int? limit,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

    var query = select(m3uSeries)
      ..where((series) =>
          series.playlistId.equals(playlistId) &
          series.createdAt.isBiggerOrEqualValue(cutoffDate))
      ..orderBy([(series) => OrderingTerm.desc(series.createdAt)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    return await query.get();
  }

  // Series Info CRUD Operations
  Future<int> insertSeriesInfo(SeriesInfosCompanion seriesInfo) {
    return into(seriesInfos).insert(seriesInfo);
  }

  Future<SeriesInfosData?> getSeriesInfo(String seriesId, String playlistId) {
    return (select(seriesInfos)..where(
          (tbl) =>
              tbl.seriesId.equals(seriesId) & tbl.playlistId.equals(playlistId),
        ))
        .getSingleOrNull();
  }

  // Seasons CRUD Operations
  Future<int> insertSeason(SeasonsCompanion season) {
    return into(seasons).insert(season);
  }

  Future<List<SeasonsData>> getSeasonsBySeriesId(
    String seriesId,
    String playlistId,
  ) {
    return (select(seasons)..where(
          (tbl) =>
              tbl.seriesId.equals(seriesId) & tbl.playlistId.equals(playlistId),
        ))
        .get();
  }

  // Episodes CRUD Operations
  Future<int> insertEpisode(EpisodesCompanion episode) {
    return into(episodes).insert(episode);
  }

  Future<List<EpisodesData>> getEpisodesBySeriesId(
    String seriesId,
    String playlistId,
  ) {
    return (select(episodes)..where(
          (tbl) =>
              tbl.seriesId.equals(seriesId) & tbl.playlistId.equals(playlistId),
        ))
        .get();
  }

  Future<List<EpisodesData>> getEpisodesBySeason(
    String seriesId,
    int seasonNumber,
    String playlistId,
  ) {
    return (select(episodes)..where(
          (tbl) =>
              tbl.seriesId.equals(seriesId) &
              tbl.season.equals(seasonNumber) &
              tbl.playlistId.equals(playlistId),
        ))
        .get();
  }

  Future<EpisodesData?> findEpisodesById(String episodeId, String playlistId) {
    return (select(episodes)..where(
          (tbl) =>
              tbl.playlistId.equals(playlistId) &
              tbl.episodeId.equals(episodeId),
        ))
        .getSingleOrNull();
  }

  Future<VodStream?> findMovieById(String streamId, String playlistId) async {
    var vodStreamData =
        await (select(vodStreams)..where(
              (tbl) =>
                  tbl.playlistId.equals(playlistId) &
                  tbl.streamId.equals(streamId),
            ))
            .getSingleOrNull();

    return vodStreamData != null
        ? VodStream.fromDriftVodStream(vodStreamData)
        : null;
  }

  Future<LiveStream?> findLiveStreamById(
    String streamId,
    String playlistId,
  ) async {
    var liveStreamData =
        await (select(liveStreams)..where(
              (tbl) =>
                  tbl.playlistId.equals(playlistId) &
                  tbl.streamId.equals(streamId),
            ))
            .getSingleOrNull();

    return liveStreamData != null
        ? LiveStream.fromDriftLiveStream(liveStreamData)
        : null;
  }

  Future<int> clearSeriesData(String seriesId, String playlistId) async {
    await (delete(episodes)..where(
          (tbl) =>
              tbl.seriesId.equals(seriesId) & tbl.playlistId.equals(playlistId),
        ))
        .go();
    await (delete(seasons)..where(
          (tbl) =>
              tbl.seriesId.equals(seriesId) & tbl.playlistId.equals(playlistId),
        ))
        .go();
    return await (delete(seriesInfos)..where(
          (tbl) =>
              tbl.seriesId.equals(seriesId) & tbl.playlistId.equals(playlistId),
        ))
        .go();
  }

  Future<List<LiveStream>> searchLiveStreams(
    String playlistId,
    String query,
  ) async {
    final liveStreamList =
        await (select(liveStreams)
              ..where(
                (tbl) =>
                    tbl.playlistId.equals(playlistId) &
                    tbl.name.contains(query),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
              ..limit(20))
            .get();

    return liveStreamList
        .map((x) => LiveStream.fromDriftLiveStream(x))
        .toList();
  }

  Future<List<VodStream>> searchMovie(String playlistId, String query) async {
    final movieList =
        await (select(vodStreams)
              ..where(
                (tbl) =>
                    tbl.playlistId.equals(playlistId) &
                    tbl.name.contains(query),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
              ..limit(20))
            .get();

    return movieList.map((x) => VodStream.fromDriftVodStream(x)).toList();
  }

  Future<int> insertM3uItem(M3uItem item) {
    return into(m3uItems).insert(item.toCompanion());
  }

  Future<void> insertM3uItems(List<M3uItem> items) {
    return batch((batch) {
      batch.insertAll(m3uItems, items.map((item) => item.toCompanion()));
    });
  }

  Future<bool> updateM3uItem(M3uItem item) {
    return update(m3uItems).replace(item.toCompanion());
  }

  Future<List<M3uItem>> getM3uItemsByCategoryId(
    String playlistId,
    String categoryId, {
    int? top,
    ContentType? contentType,
  }) async {
    var query = select(m3uItems)
      ..where(
        (ls) =>
            ls.playlistId.equals(playlistId) & ls.categoryId.equals(categoryId),
      );

    if (top != null) {
      query = query..limit(top);
    }

    if (contentType != null) {
      query = query..where((x) => x.contentType.equals(contentType.index));
    }

    final rows = await query.get();

    return rows.map((row) => M3uItem.fromData(row)).toList();
  }

  Future<int> deleteM3uItem(String playlistId, String url) {
    return (delete(m3uItems)..where(
          (tbl) => tbl.playlistId.equals(playlistId) & tbl.url.equals(url),
        ))
        .go();
  }

  Future<int> deleteAllM3uItems(String playlistId) {
    return (delete(
      m3uItems,
    )..where((tbl) => tbl.playlistId.equals(playlistId))).go();
  }

  Future<List<M3uItem>> getM3uItemsByPlaylist(String playlistId) async {
    final data = await (select(
      m3uItems,
    )..where((tbl) => tbl.playlistId.equals(playlistId))).get();
    return data.map((item) => M3uItem.fromData(item)).toList();
  }

  Future<M3uItem?> getM3uItemsByIdAndPlaylist(
    String playlistId,
    String id,
  ) async {
    final query = select(m3uItems)
      ..where((tbl) => tbl.id.equals(id) & tbl.playlistId.equals(playlistId));
    final data = await query.getSingleOrNull();

    if (data == null) return null;
    return M3uItem.fromData(data);
  }

  Future<M3uItem?> getM3uItemsByUrlAndPlaylist(
    String playlistId,
    String url,
  ) async {
    final query = select(m3uItems)
      ..where((tbl) => tbl.url.equals(url) & tbl.playlistId.equals(playlistId));
    final data = await query.getSingleOrNull();

    if (data == null) return null;
    return M3uItem.fromData(data);
  }

  Future<List<M3uItem>> getM3uItemsByCategory(String categoryId) async {
    final data = await (select(
      m3uItems,
    )..where((tbl) => tbl.categoryId.equals(categoryId))).get();
    return data.map((item) => M3uItem.fromData(item)).toList();
  }

  Future<List<M3uItem>> searchM3uItems(String playlistId, String query) async {
    final data = await (select(m3uItems)
          ..where(
            (tbl) =>
                tbl.playlistId.equals(playlistId) &
                (tbl.name.contains(query) | tbl.tvgName.contains(query)),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
          ..limit(50))
        .get();
    return data.map((item) => M3uItem.fromData(item)).toList();
  }

  Future<List<SeriesStream>> searchSeries(
    String playlistId,
    String query,
  ) async {
    final seriesList =
        await (select(seriesStreams)
              ..where(
                (tbl) =>
                    tbl.playlistId.equals(playlistId) &
                    tbl.name.contains(query),
              )
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
              ..limit(20))
            .get();

    return seriesList
        .map((x) => SeriesStream.fromDriftSeriesStream(x))
        .toList();
  }

  Future<void> insertM3uSeries(List<M3uSeriesCompanion> seriesList) async {
    await batch((batch) {
      batch.insertAll(m3uSeries, seriesList, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> insertM3uEpisodes(
    List<M3uEpisodesCompanion> episodesList,
  ) async {
    await batch((batch) {
      batch.insertAll(
        m3uEpisodes,
        episodesList,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<M3uSerie>> getM3uSeriesByCategoryId(
    String playlistId,
    String categoryId, {
    int? top,
  }) async {
    var query = select(m3uSeries)
      ..where(
        (ls) =>
            ls.playlistId.equals(playlistId) & ls.categoryId.equals(categoryId),
      );

    if (top != null) {
      query = query..limit(top);
    }

    final rows = await query.get();

    return rows.map((row) => M3uSerie.fromData(row)).toList();
  }

  Future<List<M3uEpisode>> getM3uEpisodesBySeriesId(
    String playlistId,
    String seriesId,
  ) async {
    var query = select(m3uEpisodes)
      ..where(
        (ls) => ls.playlistId.equals(playlistId) & ls.seriesId.equals(seriesId),
      );

    final rows = await query.get();

    return rows.map((row) => M3uEpisode.fromData(row)).toList();
  }

  Future<void> insertFavorite(Favorite favorite) async {
    await into(favorites).insert(favorite.toCompanion());
  }

  Future<void> updateFavorite(Favorite favorite) async {
    await (update(
      favorites,
    )..where((f) => f.id.equals(favorite.id))).write(favorite.toCompanion());
  }

  Future<void> deleteFavorite(String id) async {
    await (delete(favorites)..where((f) => f.id.equals(id))).go();
  }

  Future<List<Favorite>> getAllFavorites() async {
    final favoritesData = await select(favorites).get();
    return favoritesData.map((data) => Favorite.fromDrift(data)).toList();
  }

  Future<List<Favorite>> getFavoritesByPlaylist(String playlistId) async {
    final query = select(favorites)
      ..where((f) => f.playlistId.equals(playlistId))
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]);
    final favoritesData = await query.get();
    return favoritesData.map((data) => Favorite.fromDrift(data)).toList();
  }

  Future<List<Favorite>> getFavoritesByContentType(
    String playlistId,
    ContentType contentType,
  ) async {
    final query = select(favorites)
      ..where(
        (f) =>
            f.playlistId.equals(playlistId) &
            f.contentType.equals(contentType.index),
      )
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]);
    final favoritesData = await query.get();
    return favoritesData.map((data) => Favorite.fromDrift(data)).toList();
  }

  Future<bool> isFavorite(
    String playlistId,
    String streamId,
    ContentType contentType,
    String? episodeId,
  ) async {
    final query = select(favorites)
      ..where(
        (f) =>
            f.playlistId.equals(playlistId) &
            f.streamId.equals(streamId) &
            f.contentType.equals(contentType.index) &
            (episodeId == null
                ? f.episodeId.isNull()
                : f.episodeId.equals(episodeId)),
      );
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // Favori sayısını getir
  Future<int> getFavoriteCount(String playlistId) async {
    final query = select(favorites)
      ..where((f) => f.playlistId.equals(playlistId));
    final result = await query.get();
    return result.length;
  }

  // İçerik tipine göre favori sayısını getir
  Future<int> getFavoriteCountByContentType(
    String playlistId,
    ContentType contentType,
  ) async {
    final query = select(favorites)
      ..where(
        (f) =>
            f.playlistId.equals(playlistId) &
            f.contentType.equals(contentType.index),
      );
    final result = await query.get();
    return result.length;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from <= 2) {
        await m.createTable(categories);
        await m.createTable(userInfos);
        await m.createTable(serverInfos);
        await m.createTable(liveStreams);
        await m.createTable(vodStreams);
        await m.createTable(seriesStreams);
        // await m.addColumn(seriesStreams, seriesStreams.lastModified);
        // await m.addColumn(seriesStreams, seriesStreams.backdropPath);
        await customStatement('''
          UPDATE series_streams 
          SET last_modified = '0', backdrop_path = '[]' 
          WHERE last_modified IS NULL OR backdrop_path IS NULL
        ''');
        await m.createTable(seriesInfos);
        await m.createTable(seasons);
        await m.createTable(episodes);
        await m.createTable(watchHistories);
      }

      if (from <= 3) {
        await customStatement('''
            UPDATE playlists 
            SET type = 'PlaylistType.xtream' 
            WHERE type = 'PlaylistType.xstream'
          ''');
      }

      if (from <= 4) {
        await m.createTable(m3uItems);
      }

      if (from <= 5) {
        await m.createTable(m3uSeries);
        await m.createTable(m3uEpisodes);
      }

      if (from <= 6) {
        await m.deleteTable('m3u_items');
        await m.createTable(m3uItems);
      }

      if (from <= 7) {
        await m.createTable(favorites);
      }

      if (from < 8) {
        await m.addColumn(vodStreams, vodStreams.genre);
        await m.addColumn(vodStreams, vodStreams.youtubeTrailer);
      }

      if (from < 9) {
        try {
          await m.createTable(hiddenItems);
        } catch (e) {
          // Table might already exist, ignore error
          print('HiddenItems table creation skipped: $e');
        }
      }

      if (from < 10) {
        try {
          await m.addColumn(watchHistories, watchHistories.seasonNumber);
          await m.addColumn(watchHistories, watchHistories.episodeNumber);
          await m.addColumn(watchHistories, watchHistories.totalEpisodes);
        } catch (e) {
          print('WatchHistories columns migration skipped: $e');
        }
      }

      if (from < 11) {
        try {
          await m.createTable(epgPrograms);
          await m.createTable(epgChannels);
          await m.createTable(epgSources);
        } catch (e) {
          print('EPG tables migration skipped: $e');
        }
      }

      if (from < 12) {
        try {
          await m.createTable(cachedSubtitles);
          await m.createTable(contentDetails);
        } catch (e) {
          print('Subtitle/ContentDetails tables migration skipped: $e');
        }
      }

      if (from < 13) {
        try {
          await m.createTable(offlineItems);
        } catch (e) {
          print('OfflineItems table migration skipped: $e');
        }
      }

      if (from < 14) {
        try {
          // Add multi-URL support columns to playlists
          await m.addColumn(playlists, playlists.additionalUrls);
          await m.addColumn(playlists, playlists.activeUrlIndex);
          // Create PlaylistUrls table for URL health tracking
          await m.createTable(playlistUrls);
        } catch (e) {
          print('Playlist URLs migration skipped: $e');
        }
      }
    },
  );

  // === HIDDEN ITEMS CRUD ===

  Future<void> insertHiddenItem(HiddenItemsCompanion item) async {
    await into(hiddenItems).insert(item);
  }

  Future<void> deleteHiddenItem(String id) async {
    await (delete(hiddenItems)..where((h) => h.id.equals(id))).go();
  }

  Future<void> deleteHiddenItemByStreamId(
    String playlistId,
    String streamId,
    ContentType contentType,
  ) async {
    await (delete(hiddenItems)..where(
          (h) =>
              h.playlistId.equals(playlistId) &
              h.streamId.equals(streamId) &
              h.contentType.equals(contentType.index),
        ))
        .go();
  }

  Future<List<HiddenItemsData>> getAllHiddenItems() async {
    return await select(hiddenItems).get();
  }

  Future<List<HiddenItemsData>> getHiddenItemsByPlaylist(
    String playlistId,
  ) async {
    final query = select(hiddenItems)
      ..where((h) => h.playlistId.equals(playlistId))
      ..orderBy([(h) => OrderingTerm.desc(h.createdAt)]);
    return await query.get();
  }

  Future<Set<String>> getHiddenStreamIds(String playlistId) async {
    final items = await getHiddenItemsByPlaylist(playlistId);
    return items.map((item) => item.streamId).toSet();
  }

  Future<bool> isHidden(
    String playlistId,
    String streamId,
    ContentType contentType,
  ) async {
    final query = select(hiddenItems)
      ..where(
        (h) =>
            h.playlistId.equals(playlistId) &
            h.streamId.equals(streamId) &
            h.contentType.equals(contentType.index),
      );
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // === OFFLINE ITEMS CRUD ===

  Future<void> insertOfflineItem(OfflineItemsCompanion item) async {
    await into(offlineItems).insertOnConflictUpdate(item);
  }

  Future<void> deleteOfflineItem(String id) async {
    await (delete(offlineItems)..where((o) => o.id.equals(id))).go();
  }

  Future<void> deleteOfflineItemByStreamId(
    String playlistId,
    String streamId,
  ) async {
    await (delete(offlineItems)..where(
          (o) =>
              o.playlistId.equals(playlistId) &
              o.streamId.equals(streamId),
        ))
        .go();
  }

  Future<List<OfflineItemsData>> getAllOfflineItems() async {
    return await select(offlineItems).get();
  }

  Future<List<OfflineItemsData>> getOfflineItemsByPlaylist(
    String playlistId,
  ) async {
    final query = select(offlineItems)
      ..where((o) => o.playlistId.equals(playlistId))
      ..orderBy([(o) => OrderingTerm.desc(o.markedAt)]);
    return await query.get();
  }

  Future<Set<String>> getOfflineStreamIds(String playlistId) async {
    final items = await getOfflineItemsByPlaylist(playlistId);
    // Filter out expired temporary items
    final now = DateTime.now();
    return items
        .where((item) =>
            item.temporaryUntil == null || item.temporaryUntil!.isAfter(now))
        .map((item) => item.streamId)
        .toSet();
  }

  Future<bool> isOffline(
    String playlistId,
    String streamId,
  ) async {
    final query = select(offlineItems)
      ..where(
        (o) =>
            o.playlistId.equals(playlistId) &
            o.streamId.equals(streamId),
      );
    final result = await query.getSingleOrNull();
    if (result == null) return false;
    // Check if not expired
    if (result.temporaryUntil != null &&
        DateTime.now().isAfter(result.temporaryUntil!)) {
      return false;
    }
    return true;
  }

  Future<OfflineItemsData?> getOfflineItem(
    String playlistId,
    String streamId,
  ) async {
    final query = select(offlineItems)
      ..where(
        (o) =>
            o.playlistId.equals(playlistId) &
            o.streamId.equals(streamId),
      );
    return await query.getSingleOrNull();
  }

  /// Delete expired temporary offline items
  Future<int> cleanupExpiredOfflineItems() async {
    final now = DateTime.now();
    return await (delete(offlineItems)..where(
          (o) =>
              o.temporaryUntil.isNotNull() &
              o.temporaryUntil.isSmallerThanValue(now),
        ))
        .go();
  }

  /// Get count of offline items for a playlist
  Future<int> getOfflineItemCount(String playlistId) async {
    final items = await getOfflineStreamIds(playlistId);
    return items.length;
  }

  // === EPG CRUD OPERATIONS ===

  // EPG Sources
  Future<void> insertOrUpdateEpgSource(EpgSourcesCompanion source) async {
    await into(epgSources).insertOnConflictUpdate(source);
  }

  Future<EpgSourceData?> getEpgSource(String playlistId) async {
    final query = select(epgSources)
      ..where((e) => e.playlistId.equals(playlistId));
    return await query.getSingleOrNull();
  }

  Future<void> deleteEpgSource(String playlistId) async {
    await (delete(epgSources)..where((e) => e.playlistId.equals(playlistId))).go();
  }

  // EPG Channels
  Future<void> insertEpgChannels(List<EpgChannelsCompanion> channels) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(epgChannels, channels);
    });
  }

  Future<List<EpgChannelData>> getEpgChannels(String playlistId) async {
    final query = select(epgChannels)
      ..where((e) => e.playlistId.equals(playlistId));
    return await query.get();
  }

  Future<EpgChannelData?> getEpgChannel(String channelId, String playlistId) async {
    final query = select(epgChannels)
      ..where((e) => e.channelId.equals(channelId) & e.playlistId.equals(playlistId));
    return await query.getSingleOrNull();
  }

  Future<void> deleteEpgChannels(String playlistId) async {
    await (delete(epgChannels)..where((e) => e.playlistId.equals(playlistId))).go();
  }

  // EPG Programs
  Future<void> insertEpgPrograms(List<EpgProgramsCompanion> programs) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(epgPrograms, programs);
    });
  }

  Future<List<EpgProgramData>> getEpgPrograms(String playlistId) async {
    final query = select(epgPrograms)
      ..where((e) => e.playlistId.equals(playlistId))
      ..orderBy([(e) => OrderingTerm.asc(e.startTime)]);
    return await query.get();
  }

  Future<List<EpgProgramData>> getEpgProgramsForChannel(
    String channelId,
    String playlistId,
    DateTime from,
    DateTime to,
  ) async {
    final query = select(epgPrograms)
      ..where((e) =>
          e.channelId.equals(channelId) &
          e.playlistId.equals(playlistId) &
          e.endTime.isBiggerThanValue(from) &
          e.startTime.isSmallerThanValue(to))
      ..orderBy([(e) => OrderingTerm.asc(e.startTime)]);
    return await query.get();
  }

  Future<EpgProgramData?> getCurrentEpgProgram(String channelId, String playlistId) async {
    final now = DateTime.now();
    final query = select(epgPrograms)
      ..where((e) =>
          e.channelId.equals(channelId) &
          e.playlistId.equals(playlistId) &
          e.startTime.isSmallerOrEqualValue(now) &
          e.endTime.isBiggerThanValue(now))
      ..limit(1);
    return await query.getSingleOrNull();
  }

  Future<void> deleteEpgPrograms(String playlistId) async {
    await (delete(epgPrograms)..where((e) => e.playlistId.equals(playlistId))).go();
  }

  Future<void> deleteExpiredEpgPrograms(DateTime before) async {
    await (delete(epgPrograms)..where((e) => e.endTime.isSmallerThanValue(before))).go();
  }

  Future<int> getEpgProgramCount(String playlistId) async {
    final result = await (select(epgPrograms)
      ..where((e) => e.playlistId.equals(playlistId))).get();
    return result.length;
  }

  /// Get count of EPG programs within a specific date range
  Future<int> getEpgProgramCountInRange(
    String playlistId,
    DateTime start,
    DateTime end,
  ) async {
    final result = await (select(epgPrograms)
      ..where((e) =>
          e.playlistId.equals(playlistId) &
          e.startTime.isBiggerOrEqualValue(start) &
          e.endTime.isSmallerOrEqualValue(end)))
        .get();
    return result.length;
  }

  /// Check if there are any EPG programs for today
  Future<bool> hasEpgProgramsForToday(String playlistId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final query = select(epgPrograms)
      ..where((e) =>
          e.playlistId.equals(playlistId) &
          e.endTime.isBiggerThanValue(todayStart) &
          e.startTime.isSmallerThanValue(todayEnd))
      ..limit(1);

    final result = await query.get();
    return result.isNotEmpty;
  }

  // Clear all EPG data for a playlist
  Future<void> clearEpgData(String playlistId) async {
    await deleteEpgPrograms(playlistId);
    await deleteEpgChannels(playlistId);
  }

  Future<void> deleteDatabase() async {
    await close();
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'playlists.sqlite'));

    if (await file.exists()) {
      await file.delete();
    }
  }

  // === TV GUIDE OPTIMIZED QUERIES ===

  /// Get all EPG channel IDs that have programs in the given time range
  Future<Set<String>> getEpgChannelIdsWithPrograms(
    String playlistId,
    DateTime from,
    DateTime to,
  ) async {
    final query = selectOnly(epgPrograms, distinct: true)
      ..addColumns([epgPrograms.channelId])
      ..where(epgPrograms.playlistId.equals(playlistId) &
              epgPrograms.endTime.isBiggerThanValue(from) &
              epgPrograms.startTime.isSmallerThanValue(to));

    final results = await query.get();
    return results.map((row) => row.read(epgPrograms.channelId)!).toSet();
  }

  /// Get all EPG channel IDs for a playlist (regardless of time)
  Future<Set<String>> getAllEpgChannelIds(String playlistId) async {
    final query = selectOnly(epgChannels, distinct: true)
      ..addColumns([epgChannels.channelId])
      ..where(epgChannels.playlistId.equals(playlistId));

    final results = await query.get();
    return results.map((row) => row.read(epgChannels.channelId)!).toSet();
  }

  /// Count live streams excluding hidden categories (for pagination)
  /// If requireEpgChannelIds is provided, only count streams that have matching EPG channel IDs
  Future<int> countLiveStreamsFiltered(
    String playlistId, {
    Set<String>? excludedCategoryIds,
    Set<String>? excludedStreamIds,
    String? searchQuery,
    Set<String>? requireEpgChannelIds,
  }) async {
    var query = select(liveStreams)..where((ls) => ls.playlistId.equals(playlistId));

    final rows = await query.get();
    var filtered = rows.where((row) {
      if (excludedCategoryIds != null && excludedCategoryIds.contains(row.categoryId)) {
        return false;
      }
      if (excludedStreamIds != null && excludedStreamIds.contains(row.streamId)) {
        return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        if (!row.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
      }
      // Filter by EPG availability - check if stream's epgChannelId is in the set
      if (requireEpgChannelIds != null) {
        final epgId = row.epgChannelId;
        if (epgId.isEmpty || !requireEpgChannelIds.contains(epgId)) {
          // Also try case-insensitive match
          final hasMatch = requireEpgChannelIds.any((id) =>
            id.toLowerCase() == epgId.toLowerCase());
          if (!hasMatch) {
            return false;
          }
        }
      }
      return true;
    });

    return filtered.length;
  }

  /// Get paginated live streams excluding hidden categories
  /// If requireEpgChannelIds is provided, only return streams that have matching EPG channel IDs
  Future<List<LiveStream>> getLiveStreamsPaginated(
    String playlistId, {
    required int offset,
    required int limit,
    Set<String>? excludedCategoryIds,
    Set<String>? excludedStreamIds,
    String? searchQuery,
    Set<String>? requireEpgChannelIds,
  }) async {
    var query = select(liveStreams)..where((ls) => ls.playlistId.equals(playlistId));

    final rows = await query.get();
    var filtered = rows.where((row) {
      if (excludedCategoryIds != null && excludedCategoryIds.contains(row.categoryId)) {
        return false;
      }
      if (excludedStreamIds != null && excludedStreamIds.contains(row.streamId)) {
        return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        if (!row.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
      }
      // Filter by EPG availability - check if stream's epgChannelId is in the set
      if (requireEpgChannelIds != null) {
        final epgId = row.epgChannelId;
        if (epgId.isEmpty || !requireEpgChannelIds.contains(epgId)) {
          // Also try case-insensitive match
          final hasMatch = requireEpgChannelIds.any((id) =>
            id.toLowerCase() == epgId.toLowerCase());
          if (!hasMatch) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    // Apply pagination
    final start = offset.clamp(0, filtered.length);
    final end = (offset + limit).clamp(0, filtered.length);

    return filtered.sublist(start, end)
        .map((row) => LiveStream.fromDriftLiveStream(row))
        .toList();
  }

  /// Count M3U live items excluding hidden categories (for pagination)
  Future<int> countM3uLiveItemsFiltered(
    String playlistId, {
    Set<String>? excludedCategoryIds,
    Set<String>? excludedStreamIds,
    String? searchQuery,
  }) async {
    var query = select(m3uItems)
      ..where((item) => item.playlistId.equals(playlistId) &
                        item.contentType.equals(ContentType.liveStream.index));

    final rows = await query.get();
    var filtered = rows.where((row) {
      if (excludedCategoryIds != null && row.categoryId != null &&
          excludedCategoryIds.contains(row.categoryId)) {
        return false;
      }
      if (excludedStreamIds != null && excludedStreamIds.contains(row.id)) {
        return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final name = row.name ?? row.tvgName ?? '';
        if (!name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
      }
      return true;
    });

    return filtered.length;
  }

  /// Get paginated M3U live items excluding hidden categories
  Future<List<M3uItem>> getM3uLiveItemsPaginated(
    String playlistId, {
    required int offset,
    required int limit,
    Set<String>? excludedCategoryIds,
    Set<String>? excludedStreamIds,
    String? searchQuery,
  }) async {
    var query = select(m3uItems)
      ..where((item) => item.playlistId.equals(playlistId) &
                        item.contentType.equals(ContentType.liveStream.index));

    final rows = await query.get();
    var filtered = rows.where((row) {
      if (excludedCategoryIds != null && row.categoryId != null &&
          excludedCategoryIds.contains(row.categoryId)) {
        return false;
      }
      if (excludedStreamIds != null && excludedStreamIds.contains(row.id)) {
        return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final name = row.name ?? row.tvgName ?? '';
        if (!name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();

    // Apply pagination
    final start = offset.clamp(0, filtered.length);
    final end = (offset + limit).clamp(0, filtered.length);

    return filtered.sublist(start, end)
        .map((row) => M3uItem.fromData(row))
        .toList();
  }

  /// Get EPG programs for multiple channels in a single query (batch)
  Future<Map<String, List<EpgProgramData>>> getEpgProgramsForChannelsBatch(
    List<String> channelIds,
    String playlistId,
    DateTime from,
    DateTime to,
  ) async {
    if (channelIds.isEmpty) return {};

    final query = select(epgPrograms)
      ..where((e) =>
          e.channelId.isIn(channelIds) &
          e.playlistId.equals(playlistId) &
          e.endTime.isBiggerThanValue(from) &
          e.startTime.isSmallerThanValue(to))
      ..orderBy([(e) => OrderingTerm.asc(e.startTime)]);

    final results = await query.get();

    // Group by channelId
    final Map<String, List<EpgProgramData>> grouped = {};
    for (final program in results) {
      grouped.putIfAbsent(program.channelId, () => []).add(program);
    }

    return grouped;
  }

  // === PLAYLIST URLS ===

  /// Insert a playlist URL
  Future<void> insertPlaylistUrl(PlaylistUrl url) async {
    await into(playlistUrls).insert(PlaylistUrlsCompanion(
      id: Value(url.id),
      playlistId: Value(url.playlistId),
      url: Value(url.url),
      priority: Value(url.priority),
      status: Value(url.status.index),
      lastChecked: Value(url.lastChecked),
      lastSuccessful: Value(url.lastSuccessful),
      failureCount: Value(url.failureCount),
      lastError: Value(url.lastError),
      responseTimeMs: Value(url.responseTimeMs),
    ));
  }

  /// Insert multiple playlist URLs
  Future<void> insertPlaylistUrls(List<PlaylistUrl> urls) async {
    await batch((batch) {
      batch.insertAll(
        playlistUrls,
        urls.map((url) => PlaylistUrlsCompanion(
          id: Value(url.id),
          playlistId: Value(url.playlistId),
          url: Value(url.url),
          priority: Value(url.priority),
          status: Value(url.status.index),
          lastChecked: Value(url.lastChecked),
          lastSuccessful: Value(url.lastSuccessful),
          failureCount: Value(url.failureCount),
          lastError: Value(url.lastError),
          responseTimeMs: Value(url.responseTimeMs),
        )).toList(),
      );
    });
  }

  /// Get all URLs for a playlist
  Future<List<PlaylistUrl>> getPlaylistUrls(String playlistId) async {
    final results = await (select(playlistUrls)
          ..where((u) => u.playlistId.equals(playlistId))
          ..orderBy([(u) => OrderingTerm.asc(u.priority)]))
        .get();

    return results.map((data) => PlaylistUrl(
      id: data.id,
      playlistId: data.playlistId,
      url: data.url,
      priority: data.priority,
      status: UrlStatus.values[data.status],
      lastChecked: data.lastChecked,
      lastSuccessful: data.lastSuccessful,
      failureCount: data.failureCount,
      lastError: data.lastError,
      responseTimeMs: data.responseTimeMs,
    )).toList();
  }

  /// Get a single playlist URL by ID
  Future<PlaylistUrl?> getPlaylistUrl(String id) async {
    final result = await (select(playlistUrls)
          ..where((u) => u.id.equals(id)))
        .getSingleOrNull();

    if (result == null) return null;

    return PlaylistUrl(
      id: result.id,
      playlistId: result.playlistId,
      url: result.url,
      priority: result.priority,
      status: UrlStatus.values[result.status],
      lastChecked: result.lastChecked,
      lastSuccessful: result.lastSuccessful,
      failureCount: result.failureCount,
      lastError: result.lastError,
      responseTimeMs: result.responseTimeMs,
    );
  }

  /// Update a playlist URL
  Future<void> updatePlaylistUrl(PlaylistUrl url) async {
    await (update(playlistUrls)..where((u) => u.id.equals(url.id))).write(
      PlaylistUrlsCompanion(
        url: Value(url.url),
        priority: Value(url.priority),
        status: Value(url.status.index),
        lastChecked: Value(url.lastChecked),
        lastSuccessful: Value(url.lastSuccessful),
        failureCount: Value(url.failureCount),
        lastError: Value(url.lastError),
        responseTimeMs: Value(url.responseTimeMs),
      ),
    );
  }

  /// Update URL health status
  Future<void> updatePlaylistUrlStatus(
    String id, {
    required UrlStatus status,
    int? responseTimeMs,
    String? lastError,
  }) async {
    await (update(playlistUrls)..where((u) => u.id.equals(id))).write(
      PlaylistUrlsCompanion(
        status: Value(status.index),
        lastChecked: Value(DateTime.now()),
        lastSuccessful: status == UrlStatus.online ? Value(DateTime.now()) : const Value.absent(),
        failureCount: status != UrlStatus.online && status != UrlStatus.unknown
            ? const Value.absent() // Will be incremented separately if needed
            : Value(0),
        responseTimeMs: responseTimeMs != null ? Value(responseTimeMs) : const Value.absent(),
        lastError: Value(lastError),
      ),
    );
  }

  /// Increment failure count for a URL
  Future<void> incrementPlaylistUrlFailureCount(String id) async {
    final current = await getPlaylistUrl(id);
    if (current != null) {
      await (update(playlistUrls)..where((u) => u.id.equals(id))).write(
        PlaylistUrlsCompanion(
          failureCount: Value(current.failureCount + 1),
          lastChecked: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Delete a playlist URL
  Future<int> deletePlaylistUrl(String id) async {
    return (delete(playlistUrls)..where((u) => u.id.equals(id))).go();
  }

  /// Delete all URLs for a playlist
  Future<int> deletePlaylistUrlsByPlaylist(String playlistId) async {
    return (delete(playlistUrls)..where((u) => u.playlistId.equals(playlistId))).go();
  }

  /// Upsert a playlist URL (insert or update)
  Future<void> upsertPlaylistUrl(PlaylistUrl url) async {
    await into(playlistUrls).insertOnConflictUpdate(PlaylistUrlsCompanion(
      id: Value(url.id),
      playlistId: Value(url.playlistId),
      url: Value(url.url),
      priority: Value(url.priority),
      status: Value(url.status.index),
      lastChecked: Value(url.lastChecked),
      lastSuccessful: Value(url.lastSuccessful),
      failureCount: Value(url.failureCount),
      lastError: Value(url.lastError),
      responseTimeMs: Value(url.responseTimeMs),
    ));
  }

  // === CACHED SUBTITLES ===

  /// Insert or update a cached subtitle
  Future<void> upsertCachedSubtitle(CachedSubtitlesCompanion subtitle) async {
    await into(cachedSubtitles).insertOnConflictUpdate(subtitle);
  }

  /// Get cached subtitles for a content item
  Future<List<CachedSubtitleData>> getCachedSubtitles(String contentId) async {
    return (select(cachedSubtitles)
          ..where((s) => s.contentId.equals(contentId))
          ..orderBy([(s) => OrderingTerm.desc(s.downloadedAt)]))
        .get();
  }

  /// Get cached subtitle by content and language
  Future<CachedSubtitleData?> getCachedSubtitle(
    String contentId,
    String language,
  ) async {
    return (select(cachedSubtitles)
          ..where((s) =>
              s.contentId.equals(contentId) & s.language.equals(language)))
        .getSingleOrNull();
  }

  /// Delete cached subtitle
  Future<int> deleteCachedSubtitle(String id) async {
    return (delete(cachedSubtitles)..where((s) => s.id.equals(id))).go();
  }

  /// Delete all cached subtitles for a content item
  Future<int> deleteCachedSubtitlesForContent(String contentId) async {
    return (delete(cachedSubtitles)..where((s) => s.contentId.equals(contentId)))
        .go();
  }

  /// Update last used time for a subtitle
  Future<void> updateSubtitleLastUsed(String id) async {
    await (update(cachedSubtitles)..where((s) => s.id.equals(id))).write(
      CachedSubtitlesCompanion(lastUsedAt: Value(DateTime.now())),
    );
  }

  /// Get all cached subtitles (for management UI)
  Future<List<CachedSubtitleData>> getAllCachedSubtitles() async {
    return (select(cachedSubtitles)
          ..orderBy([(s) => OrderingTerm.desc(s.downloadedAt)]))
        .get();
  }

  // === CONTENT DETAILS (TMDB) ===

  /// Insert or update content details
  Future<void> upsertContentDetails(ContentDetailsCompanion details) async {
    await into(contentDetails).insertOnConflictUpdate(details);
  }

  /// Get content details by content ID and playlist ID
  Future<ContentDetailsData?> getContentDetails(
    String contentId,
    String playlistId,
  ) async {
    final id = '${contentId}_$playlistId';
    return (select(contentDetails)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get content details by TMDB ID
  Future<ContentDetailsData?> getContentDetailsByTmdbId(int tmdbId) async {
    return (select(contentDetails)..where((d) => d.tmdbId.equals(tmdbId)))
        .getSingleOrNull();
  }

  /// Get content details by IMDB ID
  Future<ContentDetailsData?> getContentDetailsByImdbId(String imdbId) async {
    return (select(contentDetails)..where((d) => d.imdbId.equals(imdbId)))
        .getSingleOrNull();
  }

  /// Delete content details
  Future<int> deleteContentDetails(String contentId, String playlistId) async {
    final id = '${contentId}_$playlistId';
    return (delete(contentDetails)..where((d) => d.id.equals(id))).go();
  }

  /// Check if content details exist and are fresh (within maxAge)
  Future<bool> hasValidContentDetails(
    String contentId,
    String playlistId, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final details = await getContentDetails(contentId, playlistId);
    if (details == null) return false;
    return DateTime.now().difference(details.fetchedAt) < maxAge;
  }

  /// Get content details that need updating (older than maxAge)
  Future<List<ContentDetailsData>> getStaleContentDetails({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    return (select(contentDetails)
          ..where((d) => d.fetchedAt.isSmallerThanValue(cutoff)))
        .get();
  }

  /// Clear all cached content details
  Future<int> clearAllContentDetails() async {
    return delete(contentDetails).go();
  }

  /// Get all content details
  Future<List<ContentDetailsData>> getAllContentDetails() async {
    return select(contentDetails).get();
  }

  /// Search content details by cast (for finding movies by actor)
  Future<List<ContentDetailsData>> searchContentDetailsByCast(
    String actorName,
  ) async {
    final query = '%${actorName.toLowerCase()}%';
    return (select(contentDetails)
          ..where((d) => d.cast.lower().like(query)))
        .get();
  }
}