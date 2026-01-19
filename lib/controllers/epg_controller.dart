import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/models/epg_channel.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/epg_source.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/epg_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/epg_matching_service.dart';

class EpgController extends ChangeNotifier {
  final EpgRepository _repository = EpgRepository();
  final EpgMatchingService _matchingService = EpgMatchingService();

  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;
  String? _progressMessage;
  bool _isDisposed = false;

  // EPG data cache
  Map<String, List<EpgProgram>> _programsByChannel = {};
  Map<String, EpgSource> _sourcesByPlaylist = {};
  Map<String, List<EpgChannel>> _channelsByPlaylist = {};

  // Channel to EPG ID mapping
  Map<String, String> _channelEpgMapping = {};

  bool get isLoading => _isLoading;
  bool get isFetching => _isFetching;
  String? get errorMessage => _errorMessage;
  String? get progressMessage => _progressMessage;
  Map<String, List<EpgProgram>> get programsByChannel => _programsByChannel;
  Map<String, String> get channelEpgMapping => _channelEpgMapping;

  /// Get EPG source for a playlist
  EpgSource? getSourceForPlaylist(String playlistId) => _sourcesByPlaylist[playlistId];

  /// Check if a playlist has EPG data
  bool hasEpgData(String playlistId) {
    final source = _sourcesByPlaylist[playlistId];
    return source != null && source.programCount > 0;
  }

  /// Fetch EPG data for a single playlist
  Future<EpgFetchResult> fetchEpgData(
    Playlist playlist, {
    bool force = false,
  }) async {
    try {
      _setFetching(true);
      _setError(null);

      final result = await _repository.fetchAndStoreEpg(
        playlist,
        force: force,
        onProgress: (message) {
          _setProgress(message);
        },
      );

      if (result.success) {
        // Reload source info
        final source = await _repository.getEpgSource(playlist.id);
        if (source != null) {
          _sourcesByPlaylist[playlist.id] = source;
        }

        // Reload channels
        final channels = await _repository.getEpgChannels(playlist.id);
        _channelsByPlaylist[playlist.id] = channels;
      } else {
        _setError(result.message);
      }

      _notifyIfNotDisposed();
      return result;
    } catch (e) {
      _setError('Failed to fetch EPG: $e');
      return EpgFetchResult(
        success: false,
        message: 'Failed to fetch EPG: $e',
      );
    } finally {
      _setFetching(false);
      _setProgress(null);
    }
  }

  /// Fetch EPG data for all active playlists
  Future<void> fetchAllEpgData(List<Playlist> playlists, {bool force = false}) async {
    try {
      _setLoading(true);
      _setError(null);

      for (final playlist in playlists) {
        if (_isDisposed) break;

        _setProgress('Fetching EPG for ${playlist.name}...');
        await fetchEpgData(playlist, force: force);
      }
    } catch (e) {
      _setError('Failed to fetch EPG data: $e');
    } finally {
      _setLoading(false);
      _setProgress(null);
    }
  }

  /// Refresh EPG data
  Future<void> refresh(List<Playlist> playlists) async {
    await fetchAllEpgData(playlists, force: true);
  }

  /// Load EPG sources for playlists
  Future<void> loadEpgSources(List<Playlist> playlists) async {
    try {
      _setLoading(true);

      for (final playlist in playlists) {
        final source = await _repository.getEpgSource(playlist.id);
        if (source != null) {
          _sourcesByPlaylist[playlist.id] = source;
        }

        final channels = await _repository.getEpgChannels(playlist.id);
        _channelsByPlaylist[playlist.id] = channels;
      }

      _notifyIfNotDisposed();
    } finally {
      _setLoading(false);
    }
  }

  /// Build channel to EPG mapping
  void buildChannelMapping(List<dynamic> channels, String playlistId) {
    final epgChannels = _channelsByPlaylist[playlistId] ?? [];
    _channelEpgMapping = _matchingService.buildChannelEpgMapping(
      channels,
      epgChannels,
    );
    _notifyIfNotDisposed();
  }

  /// Get current program for a channel
  EpgProgram? getCurrentProgram(String channelId, String playlistId) {
    final key = '${playlistId}_$channelId';
    final programs = _programsByChannel[key];
    if (programs == null || programs.isEmpty) return null;

    try {
      return programs.firstWhere((p) => p.isLive);
    } catch (_) {
      return null;
    }
  }

  /// Get programs for a channel in a time range
  Future<List<EpgProgram>> getPrograms(
    String channelId,
    String playlistId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final programs = await _repository.getProgramsForChannel(
        channelId,
        playlistId,
        from,
        to,
      );

      // Cache the programs
      final key = '${playlistId}_$channelId';
      _programsByChannel[key] = programs;

      return programs;
    } catch (e) {
      debugPrint('Error getting programs: $e');
      return [];
    }
  }

  /// Get programs for multiple channels in a time range
  Future<Map<String, List<EpgProgram>>> getProgramsForChannels(
    List<String> channelIds,
    String playlistId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final result = await _repository.getProgramsForChannels(
        channelIds,
        playlistId,
        from,
        to,
      );

      // Cache the programs
      for (final entry in result.entries) {
        final key = '${playlistId}_${entry.key}';
        _programsByChannel[key] = entry.value;
      }

      return result;
    } catch (e) {
      debugPrint('Error getting programs: $e');
      return {};
    }
  }

  /// Get the effective EPG channel ID for a stream channel
  String? getEpgChannelId(String streamId) {
    return _channelEpgMapping[streamId];
  }

  /// Get default EPG URL for a playlist
  String getDefaultEpgUrl(Playlist playlist) {
    return _repository.getDefaultEpgUrl(playlist);
  }

  /// Set custom EPG URL for a playlist
  Future<void> setCustomEpgUrl(String playlistId, String? url) async {
    final existingSource = _sourcesByPlaylist[playlistId];
    final source = EpgSource(
      playlistId: playlistId,
      epgUrl: url,
      useDefaultUrl: url == null || url.isEmpty,
      lastFetched: existingSource?.lastFetched,
      programCount: existingSource?.programCount ?? 0,
    );
    await _repository.setEpgSource(source);
    _sourcesByPlaylist[playlistId] = source;
    _notifyIfNotDisposed();
  }

  /// Clear EPG data for a playlist
  Future<void> clearEpgData(String playlistId) async {
    await _repository.clearEpgData(playlistId);
    _sourcesByPlaylist.remove(playlistId);
    _channelsByPlaylist.remove(playlistId);
    _programsByChannel.removeWhere((key, _) => key.startsWith('${playlistId}_'));
    _notifyIfNotDisposed();
  }

  /// Clear expired programs
  Future<void> clearExpiredPrograms() async {
    await _repository.clearExpiredPrograms();
  }

  /// Get EPG channels for a playlist
  List<EpgChannel> getEpgChannels(String playlistId) {
    return _channelsByPlaylist[playlistId] ?? [];
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return;
    _isLoading = loading;
    _notifyIfNotDisposed();
  }

  void _setFetching(bool fetching) {
    if (_isDisposed) return;
    _isFetching = fetching;
    _notifyIfNotDisposed();
  }

  void _setError(String? error) {
    if (_isDisposed) return;
    _errorMessage = error;
    _notifyIfNotDisposed();
  }

  void _setProgress(String? message) {
    if (_isDisposed) return;
    _progressMessage = message;
    _notifyIfNotDisposed();
  }

  void _notifyIfNotDisposed() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void clearError() {
    _setError(null);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
