import 'dart:async';
import 'dart:io' show Platform;
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart' show PlaylistType;
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/source_health_service.dart';
import 'package:another_iptv_player/services/vpn_detection_service.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/utils/subtitle_configuration.dart';
import 'package:another_iptv_player/widgets/video_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    PlayerState.title = widget.contentItem.name;
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
          setState(() {
            _isVpnBlocked = shouldBlock;
          });
          if (shouldBlock && _player.state.playing) {
            _player.pause();
          }
        }
      }
    });

    // Check initial VPN state
    _isVpnBlocked = _vpnService.shouldBlockNetwork;

    _initializePlayer();
  }

  @override
  void dispose() {
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
          title: contentItem.name,
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
      // Access the native player platform and set the MPV option
      final platform = _player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('load-unsafe-playlists', 'yes');
      }
    } catch (e) {
      // Silently ignore errors - this is a best-effort optimization
      print('Could not set load-unsafe-playlists option: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

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

        mediaItems.add(
          MediaItem(
            id: item.id.toString(),
            title: item.name,
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

          if (contentItem.contentType == ContentType.liveStream) {
            currentItemIndex = 0;
            _currentItemIndex = 0;
            contentItem = item;

            mediaItems.add(
              MediaItem(
                id: item.id.toString(),
                title: item.name,
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

      if (contentItem.contentType != ContentType.liveStream) {
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
      }
    } else {
      final mediaItem = MediaItem(
        id: contentItem.id.toString(),
        title: contentItem.name,
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

            // TODO: Implement watch history duration for vod and series
            await _player.open(Media(contentItem.url));
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

        // Clear any error message when playback starts
        if (_currentStreamError != null) {
          setState(() {
            _currentStreamError = null;
          });
          _errorDisplayTimer?.cancel();
        }
      }
    });

    _player.stream.position.listen((position) {
      _player.state.playlist.medias[currentItemIndex] = Media(
        contentItem.url,
        start: position,
      );

      // Debounce: Save watch history every 5 seconds instead of on every position update
      _pendingWatchDuration = position;
      _pendingTotalDuration = _player.state.duration;

      _watchHistoryTimer?.cancel();
      _watchHistoryTimer = Timer(const Duration(seconds: 5), () {
        _saveWatchHistory();
      });
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

      if (contentItem.contentType == ContentType.liveStream) {
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

      PlayerState.title = contentItem.name;
      EventBus().emit('player_content_item', contentItem);
      EventBus().emit('player_content_item_index', playlist.index);

      // Kanal listesi açıksa güncelle
      if (_showChannelList && mounted) {
        setState(() {});
      }
    });

    _player.stream.completed.listen((playlist) async {
      if (contentItem.contentType == ContentType.liveStream) {
        await _player.open(Media(contentItem.url));
      }
    });

    contentItemIndexChangedSubscription = EventBus()
        .on<int>('player_content_item_index_changed')
        .listen((int index) async {
          if (contentItem.contentType == ContentType.liveStream) {
            // Queue'yu PlayerState'ten al (kategori değiştiğinde güncellenmiş olabilir)
            final updatedQueue = PlayerState.queue ?? _queue;
            if (updatedQueue == null || index >= updatedQueue.length) return;

            final item = updatedQueue[index];
            contentItem = item;
            _queue = updatedQueue; // Queue'yu güncelle

            // --- INSERTION 3: EXTERNAL CHANGE SETTER ---
            PlayerState.currentContent = contentItem;
            PlayerState.currentIndex = index;
            PlayerState.title = item.name;
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

    // Kanal listesi göster/gizle event'i
    EventBus().on<bool>('toggle_channel_list').listen((bool show) {
      if (mounted) {
        setState(() {
          _showChannelList = show;
          PlayerState.showChannelList = show;
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

    final newIndex = _currentItemIndex + direction;
    if (newIndex < 0 || newIndex >= _queue!.length) return;

    EventBus().emit('player_content_item_index_changed', newIndex);
  }

  Widget _buildChannelListOverlay(BuildContext context) {
    final items = _queue!;
    final currentContent = PlayerState.currentContent;
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth / 3).clamp(200.0, 400.0);

    // Mevcut index'i bul
    int selectedIndex = _currentItemIndex;
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
        EventBus().emit('player_content_item_index_changed', index);
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
                    item.name,
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
  Uri? _parseArtUri(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }
    // Check if it looks like a valid URL (has a scheme/host)
    if (!imagePath.startsWith('http://') && !imagePath.startsWith('https://')) {
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
    final isFullScreen = isSeries || isLiveStream || isVod;

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

    return GestureDetector(
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
