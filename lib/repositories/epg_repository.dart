import 'package:drift/drift.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/epg_channel.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/epg_source.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/services/xmltv_parser.dart';

class EpgRepository {
  final _database = getIt<AppDatabase>();

  EpgRepository();

  // === EPG Source Management ===

  Future<EpgSource?> getEpgSource(String playlistId) async {
    final data = await _database.getEpgSource(playlistId);
    return data != null ? EpgSource.fromData(data) : null;
  }

  Future<void> setEpgSource(EpgSource source) async {
    await _database.insertOrUpdateEpgSource(source.toCompanion());
  }

  Future<void> deleteEpgSource(String playlistId) async {
    await _database.deleteEpgSource(playlistId);
  }

  /// Generate default EPG URL for Xtream sources
  String getDefaultEpgUrl(Playlist playlist) {
    if (playlist.type != PlaylistType.xtream) {
      return '';
    }

    if (playlist.url == null ||
        playlist.username == null ||
        playlist.password == null) {
      return '';
    }

    // Format: {url}/xmltv.php?username={user}&password={pass}
    final baseUrl = playlist.url!.replaceAll(RegExp(r'/+$'), '');
    return '$baseUrl/xmltv.php?username=${playlist.username}&password=${playlist.password}';
  }

  /// Get the effective EPG URL for a playlist
  Future<String?> getEffectiveEpgUrl(Playlist playlist) async {
    final source = await getEpgSource(playlist.id);

    if (source != null && !source.useDefaultUrl && source.epgUrl != null) {
      return source.epgUrl;
    }

    if (playlist.type == PlaylistType.xtream) {
      return getDefaultEpgUrl(playlist);
    }

    // For M3U, check if custom URL is set
    return source?.epgUrl;
  }

  // === EPG Data Operations ===

  /// Fetch and store EPG data for a playlist
  Future<EpgFetchResult> fetchAndStoreEpg(
    Playlist playlist, {
    bool force = false,
    void Function(String)? onProgress,
  }) async {
    try {
      // Check if we need to refresh
      final existingSource = await getEpgSource(playlist.id);
      if (!force && existingSource != null && !existingSource.needsRefresh) {
        return EpgFetchResult(
          success: true,
          message: 'EPG data is up to date',
          channelCount: 0,
          programCount: existingSource.programCount,
          skipped: true,
        );
      }

      onProgress?.call('Getting EPG URL...');

      // Get EPG URL
      final epgUrl = await getEffectiveEpgUrl(playlist);
      if (epgUrl == null || epgUrl.isEmpty) {
        return EpgFetchResult(
          success: false,
          message: 'No EPG URL configured',
        );
      }

      onProgress?.call('Fetching EPG data...');

      // Fetch and parse EPG
      final result = await XmltvParser.parseFromUrl(epgUrl, playlist.id);

      if (result.errorMessage != null) {
        return EpgFetchResult(
          success: false,
          message: result.errorMessage!,
        );
      }

      if (!result.hasData) {
        return EpgFetchResult(
          success: false,
          message: 'No EPG data found',
        );
      }

      onProgress?.call('Storing ${result.channels.length} channels...');

      // Clear old data
      await _database.clearEpgData(playlist.id);

      // Store channels
      if (result.channels.isNotEmpty) {
        final channelCompanions = result.channels
            .map((c) => c.toCompanion())
            .toList();
        await _database.insertEpgChannels(channelCompanions);
      }

      onProgress?.call('Storing ${result.programs.length} programs...');

      // Store programs in batches for better performance
      if (result.programs.isNotEmpty) {
        const batchSize = 1000;
        for (var i = 0; i < result.programs.length; i += batchSize) {
          final end = (i + batchSize < result.programs.length)
              ? i + batchSize
              : result.programs.length;
          final batch = result.programs.sublist(i, end);
          final programCompanions = batch.map((p) => p.toCompanion()).toList();
          await _database.insertEpgPrograms(programCompanions);

          onProgress?.call('Storing programs (${end}/${result.programs.length})...');
        }
      }

      // Update source info
      await setEpgSource(EpgSource(
        playlistId: playlist.id,
        epgUrl: existingSource?.epgUrl,
        useDefaultUrl: existingSource?.useDefaultUrl ?? true,
        lastFetched: DateTime.now(),
        programCount: result.programs.length,
      ));

      return EpgFetchResult(
        success: true,
        message: 'EPG data updated successfully',
        channelCount: result.channels.length,
        programCount: result.programs.length,
        parseErrors: result.parseErrors,
      );
    } catch (e) {
      return EpgFetchResult(
        success: false,
        message: 'Failed to fetch EPG: $e',
      );
    }
  }

  /// Clear all EPG data for a playlist
  Future<void> clearEpgData(String playlistId) async {
    await _database.clearEpgData(playlistId);

    // Update source info
    final source = await getEpgSource(playlistId);
    if (source != null) {
      await setEpgSource(source.copyWith(
        lastFetched: null,
        programCount: 0,
      ));
    }
  }

  /// Clear expired programs (older than 24 hours)
  Future<void> clearExpiredPrograms() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await _database.deleteExpiredEpgPrograms(cutoff);
  }

  // === Program Queries ===

  /// Get programs for a specific channel in a time range
  Future<List<EpgProgram>> getProgramsForChannel(
    String channelId,
    String playlistId,
    DateTime from,
    DateTime to,
  ) async {
    final data = await _database.getEpgProgramsForChannel(
      channelId,
      playlistId,
      from,
      to,
    );
    return data.map((d) => EpgProgram.fromData(d)).toList();
  }

  /// Get current program for a channel
  Future<EpgProgram?> getCurrentProgram(
    String channelId,
    String playlistId,
  ) async {
    final data = await _database.getCurrentEpgProgram(channelId, playlistId);
    return data != null ? EpgProgram.fromData(data) : null;
  }

  /// Get programs for multiple channels in a time range
  Future<Map<String, List<EpgProgram>>> getProgramsForChannels(
    List<String> channelIds,
    String playlistId,
    DateTime from,
    DateTime to,
  ) async {
    final result = <String, List<EpgProgram>>{};

    for (final channelId in channelIds) {
      final programs = await getProgramsForChannel(
        channelId,
        playlistId,
        from,
        to,
      );
      result[channelId] = programs;
    }

    return result;
  }

  // === Channel Queries ===

  /// Get all EPG channels for a playlist
  Future<List<EpgChannel>> getEpgChannels(String playlistId) async {
    final data = await _database.getEpgChannels(playlistId);
    return data.map((d) => EpgChannel.fromData(d)).toList();
  }

  /// Get a specific EPG channel
  Future<EpgChannel?> getEpgChannel(
    String channelId,
    String playlistId,
  ) async {
    final data = await _database.getEpgChannel(channelId, playlistId);
    return data != null ? EpgChannel.fromData(data) : null;
  }

  /// Get program count for a playlist
  Future<int> getProgramCount(String playlistId) async {
    return await _database.getEpgProgramCount(playlistId);
  }
}

/// Result of an EPG fetch operation
class EpgFetchResult {
  final bool success;
  final String message;
  final int channelCount;
  final int programCount;
  final int parseErrors;
  final bool skipped;

  EpgFetchResult({
    required this.success,
    required this.message,
    this.channelCount = 0,
    this.programCount = 0,
    this.parseErrors = 0,
    this.skipped = false,
  });

  @override
  String toString() {
    return 'EpgFetchResult(success: $success, message: $message, channels: $channelCount, programs: $programCount)';
  }
}
