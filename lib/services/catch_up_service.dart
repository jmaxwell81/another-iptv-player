import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/catch_up.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/epg_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';

/// Service for managing Catch Up TV functionality
/// Catch Up allows watching previously aired content on live channels
class CatchUpService extends ChangeNotifier {
  static final CatchUpService _instance = CatchUpService._internal();
  factory CatchUpService() => _instance;
  CatchUpService._internal();

  final EpgRepository _epgRepository = EpgRepository();

  bool _isLoading = false;
  String? _errorMessage;
  List<CatchUpProgram> _programs = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CatchUpProgram> get programs => _programs;

  /// Build Catch Up URL for Xtream Codes API
  /// Format: {server}/streaming/timeshift.php?username={user}&password={pass}&stream={streamId}&start={start}&duration={duration}
  String buildCatchUpUrl({
    required Playlist playlist,
    required String streamId,
    required DateTime startTime,
    required Duration duration,
  }) {
    if (playlist.url == null || playlist.username == null || playlist.password == null) {
      return '';
    }

    final baseUrl = playlist.url!.replaceAll(RegExp(r'/+$'), '');

    // Format start time for Xtream API: YYYY-MM-DD:HH-MM
    final startStr = '${startTime.year}-'
        '${startTime.month.toString().padLeft(2, '0')}-'
        '${startTime.day.toString().padLeft(2, '0')}:'
        '${startTime.hour.toString().padLeft(2, '0')}-'
        '${startTime.minute.toString().padLeft(2, '0')}';

    // Duration in minutes
    final durationMinutes = duration.inMinutes;

    return '$baseUrl/streaming/timeshift.php'
        '?username=${playlist.username}'
        '&password=${playlist.password}'
        '&stream=$streamId'
        '&start=$startStr'
        '&duration=$durationMinutes';
  }

  /// Alternative Catch Up URL format used by some providers
  /// Format: {server}/timeshift/{username}/{password}/{duration}/{start}/{streamId}.ts
  String buildAlternativeCatchUpUrl({
    required Playlist playlist,
    required String streamId,
    required DateTime startTime,
    required Duration duration,
  }) {
    if (playlist.url == null || playlist.username == null || playlist.password == null) {
      return '';
    }

    final baseUrl = playlist.url!.replaceAll(RegExp(r'/+$'), '');

    // Format start time: YYYY-MM-DD-HH-MM
    final startStr = '${startTime.year}-'
        '${startTime.month.toString().padLeft(2, '0')}-'
        '${startTime.day.toString().padLeft(2, '0')}-'
        '${startTime.hour.toString().padLeft(2, '0')}-'
        '${startTime.minute.toString().padLeft(2, '0')}';

    final durationMinutes = duration.inMinutes;

    return '$baseUrl/timeshift/${playlist.username}/${playlist.password}'
        '/$durationMinutes/$startStr/$streamId.ts';
  }

  /// Get Catch Up programs for a channel from EPG data
  Future<List<CatchUpProgram>> getCatchUpPrograms({
    required String channelId,
    required String playlistId,
    int daysBack = 7,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final playlist = AppState.getPlaylist(playlistId);
      if (playlist == null) {
        _errorMessage = 'Playlist not found';
        return [];
      }

      // Get EPG programs from the past N days
      final now = DateTime.now();
      final fromDate = now.subtract(Duration(days: daysBack));

      final epgPrograms = await _epgRepository.getProgramsForChannel(
        channelId,
        playlistId,
        fromDate,
        now,
      );

      // Convert EPG programs to Catch Up programs
      _programs = epgPrograms
          .where((p) => p.endTime.isBefore(now)) // Only past programs
          .map((p) => _epgToCatchUp(p, playlist))
          .toList();

      // Sort by start time, most recent first
      _programs.sort((a, b) => b.startTime.compareTo(a.startTime));

      notifyListeners();
      return _programs;
    } catch (e) {
      _errorMessage = 'Failed to load catch up: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  CatchUpProgram _epgToCatchUp(EpgProgram epg, Playlist playlist) {
    final duration = epg.endTime.difference(epg.startTime);

    return CatchUpProgram(
      id: '${epg.channelId}_${epg.startTime.millisecondsSinceEpoch}',
      channelId: epg.channelId,
      channelName: '', // Will be filled by caller
      playlistId: epg.playlistId,
      title: epg.title,
      description: epg.description,
      startTime: epg.startTime,
      endTime: epg.endTime,
      icon: epg.icon,
      catchUpUrl: buildCatchUpUrl(
        playlist: playlist,
        streamId: epg.channelId,
        startTime: epg.startTime,
        duration: duration,
      ),
    );
  }

  /// Get catch up programs grouped by date
  Map<String, List<CatchUpProgram>> getProgramsByDate() {
    final grouped = <String, List<CatchUpProgram>>{};

    for (final program in _programs) {
      final dateKey = program.dateText;
      grouped.putIfAbsent(dateKey, () => []).add(program);
    }

    return grouped;
  }

  /// Check if a channel supports catch up
  /// Based on whether we have EPG data for past programs
  Future<bool> channelSupportsCatchUp(String channelId, String playlistId) async {
    final programs = await getCatchUpPrograms(
      channelId: channelId,
      playlistId: playlistId,
      daysBack: 1, // Just check last day
    );
    return programs.isNotEmpty;
  }

  /// Get custom catch up URL pattern for a playlist (if configured)
  Future<String?> getCustomCatchUpUrl(String playlistId) async {
    return await UserPreferences.getCatchUpUrl(playlistId);
  }

  /// Set custom catch up URL pattern for a playlist
  Future<void> setCustomCatchUpUrl(String playlistId, String url) async {
    await UserPreferences.setCatchUpUrl(playlistId, url);
    notifyListeners();
  }

  /// Build catch up URL using custom pattern if available
  Future<String> buildCustomCatchUpUrl({
    required String playlistId,
    required String streamId,
    required DateTime startTime,
    required Duration duration,
    String? channelName,
  }) async {
    final customUrl = await getCustomCatchUpUrl(playlistId);
    final playlist = AppState.getPlaylist(playlistId);

    if (customUrl == null || customUrl.isEmpty || playlist == null) {
      // Fall back to standard Xtream URL
      if (playlist != null) {
        return buildCatchUpUrl(
          playlist: playlist,
          streamId: streamId,
          startTime: startTime,
          duration: duration,
        );
      }
      return '';
    }

    // Replace placeholders in custom URL
    // Supported placeholders:
    // {url} - base URL
    // {username} - username
    // {password} - password
    // {stream_id} - stream ID
    // {channel_name} - channel name (URL encoded)
    // {start_timestamp} - Unix timestamp
    // {start_utc} - Start time in UTC format
    // {start_date} - YYYY-MM-DD
    // {start_time} - HH:MM:SS
    // {duration_minutes} - duration in minutes
    // {duration_seconds} - duration in seconds

    var url = customUrl;
    url = url.replaceAll('{url}', playlist.url ?? '');
    url = url.replaceAll('{username}', playlist.username ?? '');
    url = url.replaceAll('{password}', playlist.password ?? '');
    url = url.replaceAll('{stream_id}', streamId);
    url = url.replaceAll('{channel_name}', Uri.encodeComponent(channelName ?? ''));
    url = url.replaceAll('{start_timestamp}', (startTime.millisecondsSinceEpoch ~/ 1000).toString());
    url = url.replaceAll('{start_utc}', startTime.toUtc().toIso8601String());
    url = url.replaceAll('{start_date}', '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}');
    url = url.replaceAll('{start_time}', '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}');
    url = url.replaceAll('{duration_minutes}', duration.inMinutes.toString());
    url = url.replaceAll('{duration_seconds}', duration.inSeconds.toString());

    return url;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
