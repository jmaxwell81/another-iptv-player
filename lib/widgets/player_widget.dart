import 'dart:async';
import 'dart:io' show Platform;
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart' show PlaylistType;
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/repositories/hidden_items_repository.dart';
import 'package:another_iptv_player/repositories/offline_items_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';
import 'package:another_iptv_player/services/source_health_service.dart';
import 'package:another_iptv_player/services/source_offline_service.dart';
import 'package:another_iptv_player/services/timeshift_service.dart';
import 'package:another_iptv_player/services/vpn_detection_service.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/utils/subtitle_configuration.dart';
import 'package:another_iptv_player/services/failed_domain_cache.dart';
import 'package:another_iptv_player/widgets/epg_info_overlay.dart';
import 'package:another_iptv_player/widgets/live_stream_controls.dart';
import 'package:another_iptv_player/widgets/timeshift_controls.dart';
import 'package:another_iptv_player/widgets/video_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/utils/tv_key_handler.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/content_type.dart';
import '../../services/player_state.dart';
import '../../services/service_locator.dart';
import '../../utils/audio_handler.dart';
import '../utils/player_error_handler.dart';

class PlayerWidget extends StatefulWidget {
  final ContentItem contentItem;
  final double? aspectRatio;
  final bool showControls;
  final bool showInfo;
  final VoidCallback? onFullscreen;
  final List<ContentItem>? queue;

  const PlayerWidget({
    super.key,
    required this.contentItem,
    this.aspectRatio,
    this.showControls = true,
    this.showInfo = false,
    this.onFullscreen,
    this.queue,
  });

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget>
    with WidgetsBindingObserver {
  late StreamSubscription videoTrackSubscription;
  late StreamSubscription audioTrackSubscription;
  late StreamSubscription subtitleTrackSubscription;
  late StreamSubscription contentItemIndexChangedSubscription;
  late StreamSubscription _connectivitySubscription;

  late Player _player;
  VideoController? _videoController;
  late WatchHistoryService watchHistoryService;
  final MyAudioHandler _audioHandler = getIt<MyAudioHandler>();
  List<ContentItem>? _queue;
  late ContentItem contentItem;
  final PlayerErrorHandler _errorHandler = PlayerErrorHandler();

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool _wasDisconnected = false;
  bool _isFirstCheck = true;
  int _currentItemIndex = 0;
  bool _showChannelList = false;
  Timer? _watchHistoryTimer;
  Duration? _pendingWatchDuration;
  Duration? _pendingTotalDuration;

  // Source health tracking
  final SourceHealthService _healthService = SourceHealthService();
  String? _currentStreamError;
  Timer? _errorDisplayTimer;

  // VPN kill switch
  final VpnDetectionService _vpnService = VpnDetectionService();
  StreamSubscription? _vpnStatusSubscription;
  bool _isVpnBlocked = false;

  // Timeshift support for live streams
  final TimeshiftService _timeshiftService = TimeshiftService();
  bool _timeshiftEnabled = false;

  // Hidden items
  final HiddenItemsRepository _hiddenItemsRepository = HiddenItemsRepository();
  Set<String> _hiddenStreamIds = {};

  // Auto-offline detection
  final OfflineItemsRepository _offlineItemsRepository = OfflineItemsRepository();
  Set<String> _offlineStreamIds = {};
  bool _autoOfflineEnabled = false;
  int _autoOfflineTimeoutSeconds = 10;
  Timer? _autoOfflineTimer;
  bool _hasReceivedBytes = false;

  // Source-level offline tracking
  final SourceOfflineService _sourceOfflineService = SourceOfflineService();

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    contentItem = widget.contentItem;
    _queue = widget.queue;

    // --- INSERTION 1: INITIAL CONTENT SET ---
    PlayerState.currentContent = widget.contentItem;
    PlayerState.queue = _queue;
    PlayerState.currentIndex = 0;
    // Store original URL for network streaming before any mutations
    if (!widget.contentItem.url.startsWith('error://')) {
      PlayerState.originalStreamUrl = widget.contentItem.url;
    }
    // ----------------------------------------

    PlayerState.title = widget.contentItem.name.applyRenamingRules(
      contentType: widget.contentItem.contentType,
      itemId: widget.contentItem.id,
      playlistId: widget.contentItem.sourcePlaylistId,
    );
    _player = Player(
      configuration: const PlayerConfiguration(
        // Allow loading URLs from HLS/M3U playlists (required for IPTV streams)
        libassAndroidFont: 'sans-serif',
        title: 'IPTV Player',
      ),
    );

    // Try to set MPV option to allow loading URLs from HLS playlists
    _setMpvUnsafePlaylistOption();

    watchHistoryService = WatchHistoryService();

    super.initState();
    videoTrackSubscription = EventBus()
        .on<VideoTrack>('video_track_changed')
        .listen((VideoTrack data) async {
          _player.setVideoTrack(data);
          await UserPreferences.setVideoTrack(data.id);
        });

    audioTrackSubscription = EventBus()
        .on<AudioTrack>('audio_track_changed')
        .listen((AudioTrack data) async {
          _player.setAudioTrack(data);
          await UserPreferences.setAudioTrack(data.language ?? 'null');
        });

    subtitleTrackSubscription = EventBus()
        .on<SubtitleTrack>('subtitle_track_changed')
        .listen((SubtitleTrack data) async {
          _player.setSubtitleTrack(data);
          await UserPreferences.setSubtitleTrack(data.language ?? 'null');
        });

    // VPN kill switch subscription
    _vpnStatusSubscription = _vpnService.statusStream.listen((status) {
      if (mounted) {
        final shouldBlock = _vpnService.shouldBlockNetwork;
        if (shouldBlock != _isVpnBlocked) {
          final wasBlocked = _isVpnBlocked;
          setState(() {
            _isVpnBlocked = shouldBlock;
          });
          if (shouldBlock) {
            // Stop playback completely when VPN disconnects (kill switch)
            _player.stop();
          }
          // Re-initialize player if VPN reconnected and was previously blocked
          if (wasBlocked && !shouldBlock) {
            _initializePlayer();
          }
        }
      }
    });

    // Check initial VPN state
    _isVpnBlocked = _vpnService.shouldBlockNetwork;

    // Load timeshift preference
    _loadTimeshiftPreference();

    // Load hidden items
    _loadHiddenItems();

    // Load offline items for navigation skip
    _loadOfflineItems();

    // Load auto-offline detection settings
    _loadAutoOfflineSettings();

    _initializePlayer();
  }

  Future<void> _loadHiddenItems() async {
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId != null) {
      final hiddenIds = await _hiddenItemsRepository.getHiddenStreamIds(playlistId);
      if (mounted) {
        setState(() {
          _hiddenStreamIds = hiddenIds;
        });
      }
    }
  }

  Future<void> _loadOfflineItems() async {
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId != null) {
      final offlineIds = await _offlineItemsRepository.getOfflineStreamIds(playlistId);
      if (mounted) {
        setState(() {
          _offlineStreamIds = offlineIds;
        });
      }
    }
  }

  Future<void> _loadTimeshiftPreference() async {
    final enabled = await UserPreferences.getTimeshiftEnabled();
    if (mounted) {
      setState(() {
        _timeshiftEnabled = enabled;
      });
    }
  }

  Future<void> _loadAutoOfflineSettings() async {
    _autoOfflineEnabled = await UserPreferences.getAutoOfflineEnabled();
    _autoOfflineTimeoutSeconds = await UserPreferences.getAutoOfflineTimeoutSeconds();
  }

  /// Start auto-offline detection timer for live streams
  void _startAutoOfflineTimer() {
    if (!_autoOfflineEnabled) return;
    if (contentItem.contentType != ContentType.liveStream) return;
    if (contentItem.isCatchUp) return; // Don't auto-offline catch-up content

    _autoOfflineTimer?.cancel();
    _hasReceivedBytes = false;

    _autoOfflineTimer = Timer(Duration(seconds: _autoOfflineTimeoutSeconds), () {
      if (!_hasReceivedBytes && mounted) {
        _markStreamAsAutoOffline();
      }
    });
  }

  /// Cancel auto-offline timer (called when bytes are received)
  void _cancelAutoOfflineTimer() {
    _hasReceivedBytes = true;
    _autoOfflineTimer?.cancel();
  }

  /// Mark the current stream as auto-offline due to no data received
  Future<void> _markStreamAsAutoOffline() async {
    if (!mounted) return;
    if (contentItem.contentType != ContentType.liveStream) return;

    try {
      final tempHideHours = await UserPreferences.getOfflineStreamTempHideHours();

      await _offlineItemsRepository.markOffline(
        contentItem,
        temporary: true,
        autoDetected: true,
        tempHours: tempHideHours,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${contentItem.name} auto-detected as offline (no data after $_autoOfflineTimeoutSeconds seconds)',
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                await _offlineItemsRepository.markOnline(contentItem);
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error auto-marking stream offline: $e');
    }
  }

  Future<bool> _startTimeshift() async {
    if (contentItem.contentType != ContentType.liveStream) return false;
    if (contentItem.isCatchUp) return false; // Don't timeshift catch-up content

    final playlistId = contentItem.sourcePlaylistId ??
        AppState.currentPlaylist?.id ??
        'unknown';

    return await _timeshiftService.startTimeshift(
      streamUrl: contentItem.url,
      contentId: contentItem.id,
      contentName: contentItem.name.applyRenamingRules(
        contentType: contentItem.contentType,
        itemId: contentItem.id,
        playlistId: contentItem.sourcePlaylistId,
      ),
      playlistId: playlistId,
    );
  }

  Future<void> _stopTimeshift() async {
    if (_timeshiftService.isTimeshiftActive) {
      await _timeshiftService.stopTimeshift();
    }
  }

  @override
  void dispose() {
    // Stop timeshift when player is disposed
    _stopTimeshift();

    // Cancel timer and save watch history one last time before disposing
    _watchHistoryTimer?.cancel();
    if (_pendingWatchDuration != null) {
      // Use unawaited to save without blocking dispose
      _saveWatchHistory().catchError((e) {
        // Ignore errors during dispose
      });
    }

    _player.dispose();
    _audioHandler.setPlayer(null);
    _audioHandler.stop();
    videoTrackSubscription.cancel();
    audioTrackSubscription.cancel();
    subtitleTrackSubscription.cancel();
    contentItemIndexChangedSubscription.cancel();
    _connectivitySubscription.cancel();
    _errorHandler.reset();
    _errorDisplayTimer?.cancel();
    _vpnStatusSubscription?.cancel();
    _autoOfflineTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveWatchHistory() async {
    if (_pendingWatchDuration == null || !mounted) return;

    try {
      // Get playlist ID from content or fallback to current playlist
      final playlistId = contentItem.sourcePlaylistId ??
          AppState.currentPlaylist?.id ??
          'unknown';

      // Determine if this is Xtream content
      final contentIsXtream = contentItem.sourceType == PlaylistType.xtream ||
          (contentItem.sourceType == null && contentItem.m3uItem == null);

      await watchHistoryService.saveWatchHistory(
        WatchHistory(
          playlistId: playlistId,
          contentType: contentItem.contentType,
          streamId: contentIsXtream
              ? contentItem.id
              : contentItem.m3uItem?.id ?? contentItem.id,
          lastWatched: DateTime.now(),
          title: contentItem.name.applyRenamingRules(
            contentType: contentItem.contentType,
            itemId: contentItem.id,
            playlistId: contentItem.sourcePlaylistId,
          ),
          imagePath: contentItem.imagePath,
          totalDuration: _pendingTotalDuration,
          watchDuration: _pendingWatchDuration,
          seriesId: contentItem.seriesStream?.seriesId,
          seasonNumber: contentItem.season,
          episodeNumber: contentItem.episodeNumber,
          totalEpisodes: contentItem.totalEpisodes,
        ),
      );
      _pendingWatchDuration = null;
      _pendingTotalDuration = null;
    } catch (e) {
      // Silently handle database errors to prevent crashes
      // The next save attempt will retry
      print('Error saving watch history: $e');
    }
  }

  /// Sets the MPV option to allow loading URLs from HLS/M3U playlists.
  /// This is required for IPTV streams that use playlist-based URLs.
  Future<void> _setMpvUnsafePlaylistOption() async {
    // Only available on desktop platforms (macOS, Windows, Linux)
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return;
    }

    try {
      // Access the native player platform and set MPV options
      final platform = _player.platform;
      if (platform is NativePlayer) {
        // Allow loading URLs from HLS playlists
        await platform.setProperty('load-unsafe-playlists', 'yes');

        // Enable seeking in live streams (for timeshift/pause functionality)
        await platform.setProperty('force-seekable', 'yes');

        // Increase demuxer cache for better timeshift support
        // 150MB forward cache, 150MB back cache (allows ~2-5 min of seeking depending on bitrate)
        await platform.setProperty('demuxer-max-bytes', '150MiB');
        await platform.setProperty('demuxer-max-back-bytes', '150MiB');

        // Keep the stream open even when paused
        await platform.setProperty('demuxer-readahead-secs', '120');

        // Audio settings to prevent crackling/popping
        // Increase audio buffer to prevent underruns
        await platform.setProperty('audio-buffer', '0.5'); // 500ms audio buffer

        // Use a larger cache for network streams
        await platform.setProperty('cache', 'yes');
        await platform.setProperty('cache-secs', '10'); // 10 seconds of cache

        // Reduce audio latency issues
        await platform.setProperty('audio-pitch-correction', 'no');

        // On macOS, use coreaudio with larger buffer
        if (Platform.isMacOS) {
          await platform.setProperty('ao', 'coreaudio');
          await platform.setProperty('coreaudio-buffer', '0.1'); // 100ms buffer
        }

        // Audio decoding error handling
        // Try to continue playback even with audio errors
        await platform.setProperty('audio-fallback-to-null', 'yes');
        // Use software audio decoding for better compatibility
        await platform.setProperty('ad', 'lavc');
        // Allow audio format changes during playback
        await platform.setProperty('audio-stream-silence', 'yes');
        // More lenient audio sync
        await platform.setProperty('autosync', '30');
        await platform.setProperty('mc', '0.5');
      }
    } catch (e) {
      // Silently ignore errors - this is a best-effort optimization
      print('Could not set MPV options: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    // Check VPN status - don't start playback if VPN should be blocked
    final shouldBlockPlayback = _vpnService.shouldBlockNetwork;
    if (shouldBlockPlayback) {
      setState(() {
        _isVpnBlocked = true;
        isLoading = false;
      });
      return;
    }

    // Check for invalid error:// URLs before trying to play
    if (contentItem.url.startsWith('error://')) {
      final errorType = contentItem.url.replaceFirst('error://', '').split('/').first;
      setState(() {
        hasError = true;
        errorMessage = _getErrorMessage(errorType);
        isLoading = false;
      });
      return;
    }

    PlayerState.subtitleConfiguration = await getSubtitleConfiguration();

    PlayerState.backgroundPlay = await UserPreferences.getBackgroundPlay();
    _audioHandler.setPlayer(_player);
    _videoController = VideoController(_player);

    // Get playlist ID from content's sourcePlaylistId or fallback to current playlist
    final playlistId = contentItem.sourcePlaylistId ??
        AppState.currentPlaylist?.id ??
        'unknown';

    // Determine if this is Xtream content based on sourceType or m3uItem presence
    final contentIsXtream = contentItem.sourceType == PlaylistType.xtream ||
        (contentItem.sourceType == null && contentItem.m3uItem == null);

    var watchHistory = await watchHistoryService.getWatchHistory(
      playlistId,
      contentIsXtream ? contentItem.id : contentItem.m3uItem?.id ?? contentItem.id,
    );

    List<MediaItem> mediaItems = [];
    var currentItemIndex = 0;

    if (_queue != null) {
      for (int i = 0; i < _queue!.length; i++) {
        final item = _queue![i];
        final itemPlaylistId = item.sourcePlaylistId ?? playlistId;
        final itemIsXtream = item.sourceType == PlaylistType.xtream ||
            (item.sourceType == null && item.m3uItem == null);
        final itemWatchHistory = await watchHistoryService.getWatchHistory(
          itemPlaylistId,
          itemIsXtream ? item.id : item.m3uItem?.id ?? item.id,
        );

        final renamedTitle = item.name.applyRenamingRules(
          contentType: item.contentType,
          itemId: item.id,
          playlistId: item.sourcePlaylistId,
        );

        mediaItems.add(
          MediaItem(
            id: item.id.toString(),
            title: renamedTitle,
            artist: _getContentTypeDisplayName(),
            album: AppState.currentPlaylist?.name ?? '',
            artUri: _parseArtUri(item.imagePath),
            playable: true,
            extras: {
              'url': item.url,
              'startPosition':
                  itemWatchHistory?.watchDuration?.inMilliseconds ?? 0,
            },
          ),
        );

        if (item.id == contentItem.id) {
          currentItemIndex = i;
          _currentItemIndex = i;

          // For live streams (except catch up), reset index and add extra media item
          if (contentItem.contentType == ContentType.liveStream && !contentItem.isCatchUp) {
            currentItemIndex = 0;
            _currentItemIndex = 0;
            contentItem = item;

            mediaItems.add(
              MediaItem(
                id: item.id.toString(),
                title: renamedTitle,
                artist: _getContentTypeDisplayName(),
                album: AppState.currentPlaylist?.name ?? '',
                artUri: _parseArtUri(item.imagePath),
                playable: true,
                extras: {'url': item.url, 'startPosition': 0},
              ),
            );

            EventBus().emit('player_content_item', item);
            EventBus().emit('player_content_item_index', i);
          }
        }
      }

      await _audioHandler.setQueue(mediaItems, initialIndex: currentItemIndex);

      // Catch up content should be treated as seekable (like VOD), not live stream
      final isSeekableContent = contentItem.contentType != ContentType.liveStream ||
                                contentItem.isCatchUp;

      if (isSeekableContent) {
        var playlist = mediaItems.map((mediaItem) {
          final url = mediaItem.extras!['url'] as String;
          final startMs = mediaItem.extras!['startPosition'] as int;
          return Media(url, start: Duration(milliseconds: startMs));
        }).toList();

        await _player.open(
          Playlist(playlist, index: currentItemIndex),
          play: true,
        );
      } else {
        await _player.open(Media(contentItem.url));
        // Start auto-offline detection for live streams
        _startAutoOfflineTimer();
      }
    } else {
      final mediaItem = MediaItem(
        id: contentItem.id.toString(),
        title: contentItem.name.applyRenamingRules(
          contentType: contentItem.contentType,
          itemId: contentItem.id,
          playlistId: contentItem.sourcePlaylistId,
        ),
        artist: _getContentTypeDisplayName(),
        artUri: _parseArtUri(contentItem.imagePath),
        extras: {
          'url': contentItem.url,
          'startPosition': watchHistory?.watchDuration?.inMilliseconds ?? 0,
        },
      );

      // if (contentItem.contentType == ContentType.liveStream) {
      //   liveStreamContentItem = contentItem;
      // }

      await _audioHandler.setQueue([mediaItem]);

      await _player.open(
        Playlist([
          Media(
            contentItem.url,
            start: watchHistory?.watchDuration ?? Duration(),
          ),
        ]),
        play: true,
      );

      // Start auto-offline detection for live streams (non-queue scenario)
      _startAutoOfflineTimer();
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      bool hasConnection = results.any(
        (connectivity) =>
            connectivity == ConnectivityResult.mobile ||
            connectivity == ConnectivityResult.wifi ||
            connectivity == ConnectivityResult.ethernet,
      );

      if (_isFirstCheck) {
        final currentConnectivity = await Connectivity().checkConnectivity();
        hasConnection = currentConnectivity.any(
          (connectivity) =>
              connectivity == ConnectivityResult.mobile ||
              connectivity == ConnectivityResult.wifi ||
              connectivity == ConnectivityResult.ethernet,
        );
        _isFirstCheck = false;
      }

      if (hasConnection) {
        // Reconnect only for live streams (including catch up since they may resume)
        if (_wasDisconnected &&
            contentItem.contentType == ContentType.liveStream &&
            contentItem.url.isNotEmpty) {
          try {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Online", style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
              ),
            );

            // For catch up content, preserve playback position when reconnecting
            if (contentItem.isCatchUp) {
              final currentPosition = _player.state.position;
              await _player.open(Media(contentItem.url, start: currentPosition));
            } else {
              await _player.open(Media(contentItem.url));
            }
          } catch (e) {
            print('Error opening media: $e');
          }
        }
        _wasDisconnected = false;
      } else {
        _wasDisconnected = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No Connection",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    _player.stream.tracks.listen((event) async {
      if (!mounted) return;

      PlayerState.videos = event.video;
      PlayerState.audios = event.audio;
      PlayerState.subtitles = event.subtitle;

      EventBus().emit('player_tracks', event);

      await _player.setVideoTrack(
        VideoTrack(await UserPreferences.getVideoTrack(), null, null),
      );

      var selectedAudioLanguage = await UserPreferences.getAudioTrack();
      var possibleAudioTrack = event.audio.firstWhere(
        (x) => x.language == selectedAudioLanguage,
        orElse: AudioTrack.auto,
      );

      await _player.setAudioTrack(possibleAudioTrack);

      var selectedSubtitleLanguage = await UserPreferences.getSubtitleTrack();
      var possibleSubtitleLanguage = event.subtitle.firstWhere(
        (x) => x.language == selectedSubtitleLanguage,
        orElse: SubtitleTrack.auto,
      );

      await _player.setSubtitleTrack(possibleSubtitleLanguage);
    });

    _player.stream.track.listen((event) async {
      if (!mounted) return;

      PlayerState.selectedVideo = _player.state.track.video;
      PlayerState.selectedAudio = _player.state.track.audio;
      PlayerState.selectedSubtitle = _player.state.track.subtitle;

      // Track değişikliğini bildir
      EventBus().emit('player_track_changed', null);

      var volume = await UserPreferences.getVolume();
      await _player.setVolume(volume);
    });

    _player.stream.volume.listen((event) async {
      await UserPreferences.setVolume(event);
    });

    // Report successful playback to health service
    _player.stream.playing.listen((playing) {
      if (playing && mounted) {
        final sourceId = contentItem.sourcePlaylistId ??
            AppState.currentPlaylist?.id ??
            'unknown';
        _healthService.reportSuccess(sourceId);

        // Cancel auto-offline timer - stream is playing successfully
        _cancelAutoOfflineTimer();

        // Clear any error message when playback starts
        if (_currentStreamError != null) {
          setState(() {
            _currentStreamError = null;
          });
          _errorDisplayTimer?.cancel();
        }

      } else if (!playing && mounted) {
        // When paused on live stream, mark as behind live in timeshift
        if (_timeshiftService.isTimeshiftActive) {
          _timeshiftService.pause();
        }
      }
    });

    _player.stream.position.listen((position) {
      // Note: We previously tried to update _player.state.playlist.medias[currentItemIndex]
      // but that list is immutable, so we just track the position via watch history instead

      // Debounce: Save watch history every 5 seconds instead of on every position update
      _pendingWatchDuration = position;
      _pendingTotalDuration = _player.state.duration;

      _watchHistoryTimer?.cancel();
      _watchHistoryTimer = Timer(const Duration(seconds: 5), () {
        _saveWatchHistory();
      });
    });

    // Auto-offline detection: cancel timer when buffer increases (data received)
    _player.stream.buffer.listen((buffer) {
      if (buffer > Duration.zero) {
        _cancelAutoOfflineTimer();
      }
    });

    _player.stream.error.listen((error) async {
      print('PLAYER ERROR -> $error');

      // Report error to health service
      final sourceId = contentItem.sourcePlaylistId ??
          AppState.currentPlaylist?.id ??
          'unknown';
      final errorType = SourceHealthService.categorizeError(error);
      final friendlyMessage = SourceHealthService.getFriendlyErrorMessage(errorType, error);

      _healthService.reportError(StreamError(
        sourceId: sourceId,
        streamId: contentItem.id.toString(),
        type: errorType,
        message: error,
      ));

      // Show error message at bottom of player
      if (mounted) {
        setState(() {
          _currentStreamError = friendlyMessage;
        });

        // Auto-hide error after 8 seconds
        _errorDisplayTimer?.cancel();
        _errorDisplayTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) {
            setState(() {
              _currentStreamError = null;
            });
          }
        });
      }

      if (error.contains('Failed to open')) {
        _errorHandler.handleError(
          error,
          () async {
            if (contentItem.contentType == ContentType.liveStream) {
              await _player.open(Media(contentItem.url));
            }
          },
          (errorMessage) {
            // Error is now shown at bottom of player, no snackbar needed
          },
        );
      }
    });

    _player.stream.playlist.listen((playlist) {
      if (!mounted) return;

      // For live streams (except catch up), don't handle playlist changes
      if (contentItem.contentType == ContentType.liveStream && !contentItem.isCatchUp) {
        return;
      }

      _currentItemIndex = playlist.index;
      currentItemIndex = _currentItemIndex;
      contentItem = _queue?[playlist.index] ?? widget.contentItem;

      // --- INSERTION 2: QUEUE CHANGE SETTER ---
      PlayerState.currentContent = contentItem;
      PlayerState.currentIndex = _currentItemIndex;
      if (!contentItem.url.startsWith('error://')) {
        PlayerState.originalStreamUrl = contentItem.url;
      }
      // ----------------------------------------

      PlayerState.title = contentItem.name.applyRenamingRules(
        contentType: contentItem.contentType,
        itemId: contentItem.id,
        playlistId: contentItem.sourcePlaylistId,
      );
      EventBus().emit('player_content_item', contentItem);
      EventBus().emit('player_content_item_index', playlist.index);

      // Kanal listesi açıksa güncelle
      if (_showChannelList && mounted) {
        setState(() {});
      }
    });

    _player.stream.completed.listen((playlist) async {
      // Only auto-restart for live streams (not catch up content)
      if (contentItem.contentType == ContentType.liveStream && !contentItem.isCatchUp) {
        await _player.open(Media(contentItem.url));
      }
    });

    contentItemIndexChangedSubscription = EventBus()
        .on<int>('player_content_item_index_changed')
        .listen((int index) async {
          // Channel switching only for live streams (not catch up)
          if (contentItem.contentType == ContentType.liveStream && !contentItem.isCatchUp) {
            // Queue'yu PlayerState'ten al (kategori değiştiğinde güncellenmiş olabilir)
            final updatedQueue = PlayerState.queue ?? _queue;
            if (updatedQueue == null || index >= updatedQueue.length) return;

            final item = updatedQueue[index];
            contentItem = item;
            _queue = updatedQueue; // Queue'yu güncelle

            // --- INSERTION 3: EXTERNAL CHANGE SETTER ---
            PlayerState.currentContent = contentItem;
            PlayerState.currentIndex = index;
            PlayerState.title = item.name.applyRenamingRules(
              contentType: item.contentType,
              itemId: item.id,
              playlistId: item.sourcePlaylistId,
            );
            _currentItemIndex = index;
            if (!item.url.startsWith('error://')) {
              PlayerState.originalStreamUrl = item.url;
            }
            // -------------------------------------------

            await _player.open(Playlist([Media(item.url)]), play: true);
            EventBus().emit('player_content_item', item);
            EventBus().emit('player_content_item_index', index);
            _errorHandler.reset();

            // Kanal listesi açıksa güncelle
            if (_showChannelList && mounted) {
              setState(() {});
            }
          } else {
            _player.jump(index);
          }
        });

    // Kanal listesi göster/gizle event'i (null = toggle, true = show, false = hide)
    EventBus().on<bool?>('toggle_channel_list').listen((bool? show) {
      if (mounted) {
        setState(() {
          if (show == null) {
            // Toggle
            _showChannelList = !_showChannelList;
          } else {
            _showChannelList = show;
          }
          PlayerState.showChannelList = _showChannelList;
        });
      }
    });

    // Video bilgisi göster/gizle event'i
    EventBus().on<bool>('toggle_video_info').listen((bool show) {
      if (mounted) {
        setState(() {
          PlayerState.showVideoInfo = show;
        });
      }
    });

    // Video ayarları göster/gizle event'i
    EventBus().on<bool>('toggle_video_settings').listen((bool show) {
      if (mounted) {
        setState(() {
          PlayerState.showVideoSettings = show;
        });
      }
    });

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        await _player.dispose();
        _audioHandler.setPlayer(null);
        await _audioHandler.stop();
        break;
      default:
        break;
    }
  }

  void _changeChannel(int direction) {
    if (_queue == null || _queue!.length <= 1) return;

    // Find the next/previous non-offline channel
    // Skip items that are: individually offline OR from an offline source
    int newIndex = _currentItemIndex + direction;
    while (newIndex >= 0 && newIndex < _queue!.length &&
           _isItemUnavailable(_queue![newIndex])) {
      newIndex += direction;
    }

    if (newIndex < 0 || newIndex >= _queue!.length) return;

    EventBus().emit('player_content_item_index_changed', newIndex);
  }

  /// Check if an item is unavailable (individually offline or from offline source)
  bool _isItemUnavailable(ContentItem item) {
    // Check if individually marked as offline
    if (_offlineStreamIds.contains(item.id)) return true;

    // Check if the source is offline
    final sourceId = item.sourcePlaylistId;
    if (sourceId != null && _sourceOfflineService.isSourceOffline(sourceId)) {
      return true;
    }

    return false;
  }

  Widget _buildChannelListOverlay(BuildContext context) {
    // Filter out hidden items and items from offline sources from the channel list
    final items = _queue!.where((item) {
      // Filter hidden items
      if (_hiddenStreamIds.contains(item.id)) return false;
      // Filter items from offline sources
      if (_isItemUnavailable(item)) return false;
      return true;
    }).toList();
    final currentContent = PlayerState.currentContent;
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth / 3).clamp(200.0, 400.0);

    // Mevcut index'i bul
    int selectedIndex = 0;
    if (currentContent != null) {
      final foundIndex = items.indexWhere(
        (item) => item.id == currentContent.id,
      );
      if (foundIndex != -1) {
        selectedIndex = foundIndex;
      }
    }

    String overlayTitle = 'Kanal Seç';
    if (currentContent?.contentType == ContentType.vod) {
      overlayTitle = 'Filmler';
    } else if (currentContent?.contentType == ContentType.series) {
      overlayTitle = 'Bölümler';
    }

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showChannelList = false;
          });
        },
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {}, // Panel içine tıklanınca kapanmasın
              child: Container(
                width: panelWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[800]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              overlayTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '${selectedIndex + 1} / ${items.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _showChannelList = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Channel list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = index == selectedIndex;

                          return _buildChannelListItem(
                            context,
                            item,
                            index,
                            isSelected,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelListItem(
    BuildContext context,
    ContentItem item,
    int index,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        // Find the actual index in the original queue (not the filtered list)
        final originalIndex = _queue?.indexWhere((q) => q.id == item.id) ?? index;
        EventBus().emit('player_content_item_index_changed', originalIndex);
        // Panel kapanmasın, sadece kanal değişsin
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Row(
          children: [
            // Thumbnail
            if (item.imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  item.imagePath,
                  width: 50,
                  height: 35,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 35,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: 20,
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 50,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.video_library,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            const SizedBox(width: 10),
            // Title and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name.applyRenamingRules(
                      contentType: item.contentType,
                      itemId: item.id,
                      playlistId: item.sourcePlaylistId,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getContentTypeIcon(item.contentType),
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _getContentTypeDisplayNameForItem(item.contentType),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getContentTypeIcon(ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return Icons.live_tv;
      case ContentType.vod:
        return Icons.movie;
      case ContentType.series:
        return Icons.tv;
    }
  }

  String _getContentTypeDisplayNameForItem(ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return 'Canlı Yayın';
      case ContentType.vod:
        return 'Film';
      case ContentType.series:
        return 'Dizi';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    } else {
      return '${minutes}dk';
    }
  }

  String _getContentTypeDisplayName() {
    switch (widget.contentItem.contentType) {
      case ContentType.liveStream:
        return 'Canlı Yayın';
      case ContentType.vod:
        return 'Film';
      case ContentType.series:
        return 'Dizi';
    }
  }

  /// Parse artUri safely, returning null for empty or invalid URLs
  /// Also checks domain cache to avoid loading from known-failed domains
  Uri? _parseArtUri(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }
    // Check if it looks like a valid URL (has a scheme/host)
    if (!imagePath.startsWith('http://') && !imagePath.startsWith('https://')) {
      return null;
    }
    // Check if domain is known to be down
    if (FailedDomainCache().isDomainBlocked(imagePath)) {
      return null;
    }
    try {
      return Uri.parse(imagePath);
    } catch (e) {
      return null;
    }
  }

  /// Get user-friendly error message for error:// URL types
  String _getErrorMessage(String errorType) {
    switch (errorType) {
      case 'no-playlist-found':
        return 'Unable to play: No playlist configuration found. Please select a playlist and try again.';
      case 'missing-credentials':
        return 'Unable to play: Playlist credentials are missing. Please check your playlist settings.';
      default:
        return 'Unable to play this content. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isLandscape = screenSize.width > screenSize.height;

    // Series ve LiveStream için tam ekran modu
    final isSeries = widget.contentItem.contentType == ContentType.series;
    final isLiveStream =
        widget.contentItem.contentType == ContentType.liveStream;
    final isVod = widget.contentItem.contentType == ContentType.vod;
    final isCatchUp = widget.contentItem.isCatchUp;
    final isFullScreen = isSeries || isLiveStream || isVod || isCatchUp;

    double calculateAspectRatio() {
      if (widget.aspectRatio != null) return widget.aspectRatio!;

      if (isTablet) {
        return isLandscape ? 21 / 9 : 16 / 9;
      }
      return 16 / 9;
    }

    double? calculateMaxHeight() {
      if (isTablet) {
        if (isLandscape) {
          return screenSize.height * 0.6;
        } else {
          return screenSize.height * 0.4;
        }
      }
      return null;
    }

    Widget playerWidget;

    if (isFullScreen) {
      // Series ve LiveStream için tam ekran
      playerWidget = SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: isLoading
            ? Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            : _buildPlayerContent(),
      );
    } else {
      // Diğer içerikler için aspect ratio kullan
      playerWidget = AspectRatio(
        aspectRatio: calculateAspectRatio(),
        child: isLoading
            ? Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            : _buildPlayerContent(),
      );

      if (isTablet) {
        final maxHeight = calculateMaxHeight();
        if (maxHeight != null) {
          playerWidget = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: playerWidget,
          );
        }
      }
    }

    return Container(
      color: Colors.black,
      child: isFullScreen ? playerWidget : Column(children: [playerWidget]),
    );
  }

  Widget _buildPlayerContent() {
    // VPN kill switch - block playback if VPN not connected
    if (_isVpnBlocked) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.vpn_lock, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'VPN Not Connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Please connect to a VPN before playing content.\nKill switch is enabled for your protection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await _vpnService.forceCheck();
                  // Explicitly update state after check completes
                  if (mounted) {
                    final shouldBlock = _vpnService.shouldBlockNetwork;
                    final wasBlocked = _isVpnBlocked;
                    setState(() {
                      _isVpnBlocked = shouldBlock;
                    });
                    // Re-initialize player if VPN is now connected
                    if (wasBlocked && !shouldBlock) {
                      setState(() {
                        isLoading = true;
                      });
                      _initializePlayer();
                    }
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    final isLiveStreamContent = contentItem.contentType == ContentType.liveStream &&
        !contentItem.isCatchUp;

    // For VOD content (movies/series), wrap with Focus for D-pad/remote control support
    Widget playerContent = Focus(
      autofocus: !isLiveStreamContent, // Autofocus for VOD, live stream has its own focus
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Play/Pause (Space, Select, or media keys)
          if (TvKeyHandler.isPlayPauseKey(event) ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.select) {
            _player.playOrPause();
            return KeyEventResult.handled;
          }
          // Seek backward (Left arrow or media rewind)
          else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              TvKeyHandler.isRewindKey(event)) {
            final currentPos = _player.state.position;
            final newPos = currentPos - const Duration(seconds: 10);
            _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
            return KeyEventResult.handled;
          }
          // Seek forward (Right arrow or media fast forward)
          else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              TvKeyHandler.isFastForwardKey(event)) {
            final currentPos = _player.state.position;
            final duration = _player.state.duration;
            final newPos = currentPos + const Duration(seconds: 10);
            _player.seek(newPos > duration ? duration : newPos);
            return KeyEventResult.handled;
          }
          // Previous episode/movie (Up arrow, or Amazon Fire TV wheel backward/previous track)
          else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              TvKeyHandler.isPreviousTrackKey(event)) {
            if (_queue != null && _currentItemIndex > 0) {
              _changeChannel(-1);
              return KeyEventResult.handled;
            }
          }
          // Next episode/movie (Down arrow, or Amazon Fire TV wheel forward/next track)
          else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              TvKeyHandler.isNextTrackKey(event)) {
            if (_queue != null && _currentItemIndex < _queue!.length - 1) {
              _changeChannel(1);
              return KeyEventResult.handled;
            }
          }
          // Back key (Escape or TV back button)
          else if (TvKeyHandler.isBackKey(event) ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).maybePop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
      onVerticalDragEnd: (details) {
        if (_queue == null || _queue!.length <= 1) return;

        // Yukarı swipe - sonraki kanal
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -500) {
          _changeChannel(1);
        }
        // Aşağı swipe - önceki kanal
        else if (details.primaryVelocity != null &&
            details.primaryVelocity! > 500) {
          _changeChannel(-1);
        }
      },
      child: Stack(
        children: [
          getVideo(
            context,
            _videoController!,
            PlayerState.subtitleConfiguration,
          ),

          if (widget.onFullscreen != null &&
              (Theme.of(context).platform == TargetPlatform.macOS ||
                  Theme.of(context).platform == TargetPlatform.windows ||
                  Theme.of(context).platform == TargetPlatform.linux))
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: widget.onFullscreen,
                icon: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),

          // Kanal listesi overlay - normal mod için
          if (_showChannelList && _queue != null && _queue!.length > 1)
            _buildChannelListOverlay(context),

          // Stream error message overlay at bottom
          if (_currentStreamError != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60, // Above the video controls
              child: _buildErrorOverlay(),
            ),

          // Live stream controls overlay (shows on hover/tap for live streams)
          if (isLiveStreamContent)
            Positioned.fill(
              child: LiveStreamControls(
                player: _player,
                queue: _queue,
                currentIndex: _currentItemIndex,
                onGoLive: () {
                  _timeshiftService.goLive();
                },
                onBack: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),

          // EPG info overlay with channel navigation and subtitle toggle
          if (isLiveStreamContent)
            Positioned.fill(
              child: EPGInfoOverlay(
                player: _player,
                contentItem: contentItem,
                queue: _queue,
                currentIndex: _currentItemIndex,
                onChannelChange: () {
                  // Refresh EPG data when channel changes
                },
              ),
            ),
        ],
      ),
      ),
    );

    return playerContent;
  }

  void _showSaveBufferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SaveTimeshiftDialog(
        state: _timeshiftService.state,
        onSave: (additionalDuration) async {
          final recording = await _timeshiftService.saveBuffer(
            additionalDuration: additionalDuration,
          );
          if (recording != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Recording saved: ${recording.contentName}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showRecordingDialog(BuildContext context) {
    final isRecording = _timeshiftService.isTimeshiftActive;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isRecording ? 'Recording Active' : 'Start Recording'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRecording) ...[
              Text(
                'Currently buffering: ${_timeshiftService.state.bufferDurationText}',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'You can save the current buffer or stop recording.',
              ),
            ] else ...[
              const Text(
                'Start recording this live stream?\n\n'
                'The stream will be buffered for up to 30 minutes, '
                'allowing you to pause, rewind, and save the recording.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Requires FFmpeg to be installed.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (isRecording) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _timeshiftService.stopTimeshift();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recording stopped'),
                    ),
                  );
                }
              },
              child: const Text('Stop'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showSaveBufferDialog(context);
              },
              child: const Text('Save Buffer'),
            ),
          ] else ...[
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await _startTimeshift();
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recording started'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to start recording. Make sure FFmpeg is installed.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Start Recording'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentStreamError ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _currentStreamError = null;
              });
              _errorDisplayTimer?.cancel();
            },
          ),
        ],
      ),
    );
  }
}
