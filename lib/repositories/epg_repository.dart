import 'package:drift/drift.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/epg_channel.dart';
import 'package:another_iptv_player/models/epg_fetch_status.dart';
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

  /// Check if we have fresh EPG data covering today
  ///
  /// Returns true if:
  /// - EPG was fetched within the last 12 hours
  /// - There are programs for today in the database
  Future<bool> hasFreshDataForToday(String playlistId) async {
    final source = await getEpgSource(playlistId);
    if (source == null || source.programCount == 0) return false;

    // Check if lastFetched is within last 12 hours
    if (source.lastFetched == null) return false;
    final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));
    if (source.lastFetched!.isBefore(twelveHoursAgo)) return false;

    // Check if we have programs for today
    return await _database.hasEpgProgramsForToday(playlistId);
  }

  /// Fetch and store EPG data for a playlist
  Future<EpgFetchResult> fetchAndStoreEpg(
    Playlist playlist, {
    bool force = false,
    void Function(String)? onProgress,
  }) async {
    // Use the enhanced version with null callbacks for backward compatibility
    return fetchAndStoreEpgWithStatus(
      playlist,
      force: force,
      onProgress: onProgress,
    );
  }

  /// Fetch and store EPG data with detailed status reporting
  ///
  /// [force] - If true, fetch even if data is fresh
  /// [onProgress] - Legacy simple progress callback
  /// [onStatusUpdate] - Detailed status callback with EpgSourceStatus
  /// [isCancelled] - Function that returns true if operation should be cancelled
  Future<EpgFetchResult> fetchAndStoreEpgWithStatus(
    Playlist playlist, {
    bool force = false,
    void Function(String)? onProgress,
    void Function(EpgSourceStatus)? onStatusUpdate,
    bool Function()? isCancelled,
  }) async {
    var status = EpgSourceStatus(
      playlistId: playlist.id,
      playlistName: playlist.name,
      state: EpgFetchState.checking,
      startTime: DateTime.now(),
    );
    onStatusUpdate?.call(status);

    try {
      // Check if fresh data exists for today (skip if so, unless forced)
      if (!force && await hasFreshDataForToday(playlist.id)) {
        status = status.copyWith(state: EpgFetchState.skipped);
        onStatusUpdate?.call(status);
        return EpgFetchResult(
          success: true,
          message: 'Fresh EPG data exists for today',
          skipped: true,
        );
      }

      // Check if we need to refresh (legacy check)
      final existingSource = await getEpgSource(playlist.id);
      if (!force && existingSource != null && !existingSource.needsRefresh) {
        status = status.copyWith(state: EpgFetchState.skipped);
        onStatusUpdate?.call(status);
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
        status = status.copyWith(
          state: EpgFetchState.failed,
          errorMessage: 'No EPG URL configured',
        );
        onStatusUpdate?.call(status);
        return EpgFetchResult(
          success: false,
          message: 'No EPG URL configured',
        );
      }

      // Check for cancellation
      if (isCancelled?.call() == true) {
        status = status.copyWith(state: EpgFetchState.cancelled);
        onStatusUpdate?.call(status);
        return EpgFetchResult(success: false, message: 'Cancelled');
      }

      status = status.copyWith(state: EpgFetchState.downloading);
      onStatusUpdate?.call(status);
      onProgress?.call('Fetching EPG data...');

      // Fetch and parse EPG with progress
      final result = await XmltvParser.parseFromUrl(
        epgUrl,
        playlist.id,
        connectionTimeout: const Duration(seconds: 15),
        onProgress: (downloaded, total) {
          // Calculate progress, clamping to 0.0-1.0 range
          // Note: downloaded can exceed total when server sends gzip with Content-Length
          // for compressed size but http client decompresses automatically
          double progress = 0.0;
          if (total != null && total > 0) {
            progress = (downloaded / total).clamp(0.0, 1.0);
          }
          status = status.copyWith(
            bytesDownloaded: downloaded,
            totalBytes: total,
            progress: progress,
          );
          onStatusUpdate?.call(status);
        },
        isCancelled: isCancelled,
      );

      // Check for cancellation
      if (isCancelled?.call() == true || result.errorMessage == 'Cancelled') {
        status = status.copyWith(state: EpgFetchState.cancelled);
        onStatusUpdate?.call(status);
        return EpgFetchResult(success: false, message: 'Cancelled');
      }

      if (result.errorMessage != null) {
        // Check if this was an offline/connection error
        final isOffline = result.errorMessage!.toLowerCase().contains('timeout') ||
            result.errorMessage!.toLowerCase().contains('connection') ||
            result.errorMessage!.toLowerCase().contains('socket') ||
            result.errorMessage!.toLowerCase().contains('offline');

        status = status.copyWith(
          state: EpgFetchState.failed,
          errorMessage: result.errorMessage,
          wasOffline: isOffline,
        );
        onStatusUpdate?.call(status);
        return EpgFetchResult(
          success: false,
          message: result.errorMessage!,
        );
      }

      if (!result.hasData) {
        status = status.copyWith(
          state: EpgFetchState.failed,
          errorMessage: 'No EPG data found',
        );
        onStatusUpdate?.call(status);
        return EpgFetchResult(
          success: false,
          message: 'No EPG data found',
        );
      }

      // Parsing phase
      status = status.copyWith(state: EpgFetchState.parsing, progress: 0.0);
      onStatusUpdate?.call(status);
      onProgress?.call('Storing ${result.channels.length} channels...');

      // Storing phase
      status = status.copyWith(state: EpgFetchState.storing);
      onStatusUpdate?.call(status);

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
          // Check for cancellation during storage
          if (isCancelled?.call() == true) {
            status = status.copyWith(state: EpgFetchState.cancelled);
            onStatusUpdate?.call(status);
            return EpgFetchResult(success: false, message: 'Cancelled');
          }

          final end = (i + batchSize < result.programs.length)
              ? i + batchSize
              : result.programs.length;
          final batch = result.programs.sublist(i, end);
          final programCompanions = batch.map((p) => p.toCompanion()).toList();
          await _database.insertEpgPrograms(programCompanions);

          // Update storing progress
          final storeProgress = end / result.programs.length;
          status = status.copyWith(progress: storeProgress);
          onStatusUpdate?.call(status);
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

      status = status.copyWith(state: EpgFetchState.completed, progress: 1.0);
      onStatusUpdate?.call(status);

      return EpgFetchResult(
        success: true,
        message: 'EPG data updated successfully',
        channelCount: result.channels.length,
        programCount: result.programs.length,
        parseErrors: result.parseErrors,
      );
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      final isOffline = errorMessage.contains('socket') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('network');

      status = status.copyWith(
        state: EpgFetchState.failed,
        errorMessage: 'Failed to fetch EPG: $e',
        wasOffline: isOffline,
      );
      onStatusUpdate?.call(status);

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
