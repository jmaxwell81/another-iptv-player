import 'dart:async';
import 'package:another_iptv_player/controllers/epg_controller.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/live_recording_service.dart';
import 'package:another_iptv_player/services/player_state.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
import 'package:another_iptv_player/widgets/player-buttons/video_favorite_widget.dart';
import 'package:another_iptv_player/widgets/recording_dialog.dart';
import 'package:another_iptv_player/widgets/recording_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

/// Controls overlay for live streams with hover-to-show behavior
/// Shows pause/play, rewind/forward when paused, and time behind live indicator
class LiveStreamControls extends StatefulWidget {
  final Player player;
  final VoidCallback? onGoLive;
  final VoidCallback? onBack;
  final List<ContentItem>? queue;
  final int currentIndex;

  const LiveStreamControls({
    super.key,
    required this.player,
    this.onGoLive,
    this.onBack,
    this.queue,
    this.currentIndex = 0,
  });

  @override
  State<LiveStreamControls> createState() => _LiveStreamControlsState();
}

class _LiveStreamControlsState extends State<LiveStreamControls> {
  bool _showControls = true; // Start visible
  Timer? _hideTimer;

  // Track pause state and time behind live
  bool _isPaused = false;
  Duration _accumulatedTimeBehind = Duration.zero; // Time accumulated from previous pauses
  DateTime? _currentPauseStart; // When current pause started (null if playing)
  Timer? _behindLiveTimer;
  bool _isLive = true; // Track if we're currently at live edge

  // Computed total time behind live
  Duration get _totalTimeBehindLive {
    if (_currentPauseStart != null) {
      return _accumulatedTimeBehind + DateTime.now().difference(_currentPauseStart!);
    }
    return _accumulatedTimeBehind;
  }

  // Player subscriptions
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _bufferSubscription;

  // Track positions for seeking
  Duration _currentPosition = Duration.zero;
  Duration _bufferEnd = Duration.zero;

  // Recording service
  final LiveRecordingService _recordingService = LiveRecordingService();

  // EPG data
  final EpgController _epgController = EpgController();
  EpgProgram? _currentProgram;
  EpgProgram? _nextProgram;
  bool _isLoadingEpg = true;
  Timer? _epgRefreshTimer;

  @override
  void initState() {
    super.initState();
    _recordingService.addListener(_onRecordingStateChanged);
    _recordingService.initialize();
    _setupSubscriptions();
    _startHideTimer();

    // Load EPG data
    _loadEpgData();
    _epgRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadEpgData();
    });
  }

  Future<void> _loadEpgData() async {
    final content = PlayerState.currentContent;
    if (content == null) {
      if (mounted) setState(() => _isLoadingEpg = false);
      return;
    }

    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) {
      if (mounted) setState(() => _isLoadingEpg = false);
      return;
    }

    final channelId = content.liveStream?.epgChannelId ??
        content.liveStream?.streamId ??
        content.m3uItem?.tvgId ??
        content.id;

    final now = DateTime.now();
    final programs = await _epgController.getPrograms(
      channelId,
      playlistId,
      now.subtract(const Duration(hours: 1)),
      now.add(const Duration(hours: 6)),
    );

    if (!mounted) return;

    EpgProgram? current;
    EpgProgram? next;

    for (int i = 0; i < programs.length; i++) {
      if (programs[i].isLive) {
        current = programs[i];
        if (i + 1 < programs.length) {
          next = programs[i + 1];
        }
        break;
      }
    }

    setState(() {
      _currentProgram = current;
      _nextProgram = next;
      _isLoadingEpg = false;
    });
  }

  void _onRecordingStateChanged() {
    if (mounted) setState(() {});
  }

  bool get _isRecording {
    final content = PlayerState.currentContent;
    if (content == null) return false;
    return _recordingService.isRecording(content.id);
  }

  void _setupSubscriptions() {
    _playingSubscription = widget.player.stream.playing.listen((playing) {
      if (mounted) {
        final wasPaused = _isPaused;
        setState(() {
          _isPaused = !playing;
        });

        if (!playing && !wasPaused) {
          // Just paused - record when this pause started
          _currentPauseStart = DateTime.now();
          _startBehindLiveTimer();
          _showControlsTemporarily(keepVisible: true);
          setState(() {
            _isLive = false;
          });
        } else if (playing && wasPaused) {
          // Just resumed - save accumulated time and clear pause start
          _accumulatedTimeBehind = _totalTimeBehindLive;
          _currentPauseStart = null;
          _stopBehindLiveTimer();
          _startHideTimer();
        }
      }
    });

    _positionSubscription = widget.player.stream.position.listen((position) {
      if (mounted) {
        _currentPosition = position;
      }
    });

    _bufferSubscription = widget.player.stream.buffer.listen((buffer) {
      if (mounted) {
        _bufferEnd = buffer;
      }
    });

    // Initialize state
    _isPaused = !widget.player.state.playing;
    _currentPosition = widget.player.state.position;
    _bufferEnd = widget.player.state.buffer;

    if (_isPaused) {
      _currentPauseStart = DateTime.now();
      _startBehindLiveTimer();
      _isLive = false;
    }
  }

  void _startBehindLiveTimer() {
    _behindLiveTimer?.cancel();
    _behindLiveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _currentPauseStart != null) {
        // Just trigger rebuild - _totalTimeBehindLive getter computes the value
        setState(() {});
      }
    });
  }

  void _stopBehindLiveTimer() {
    _behindLiveTimer?.cancel();
    _behindLiveTimer = null;
  }

  void _resetToLive() {
    _stopBehindLiveTimer();
    if (mounted) {
      setState(() {
        _accumulatedTimeBehind = Duration.zero;
        _currentPauseStart = null;
        _isLive = true;
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _behindLiveTimer?.cancel();
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _bufferSubscription?.cancel();
    _epgRefreshTimer?.cancel();
    _recordingService.removeListener(_onRecordingStateChanged);
    super.dispose();
  }

  void _startRecording(BuildContext context) {
    final content = PlayerState.currentContent;
    if (content == null) return;
    final playlistId = AppState.currentPlaylist?.id ?? 'unknown';
    RecordingDialog.show(
      context,
      content: content,
      playlistId: playlistId,
    );
  }

  void _showControlsTemporarily({bool keepVisible = false}) {
    setState(() {
      _showControls = true;
    });
    if (!keepVisible && !_isPaused) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    // Don't auto-hide if paused
    if (!_isPaused) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isPaused) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _onTap() {
    if (_showControls && !_isPaused) {
      setState(() {
        _showControls = false;
      });
    } else {
      _showControlsTemporarily();
    }
  }

  void _onHover(bool hovering) {
    if (hovering) {
      _showControlsTemporarily();
    } else if (!_isPaused) {
      _startHideTimer();
    }
  }

  void _togglePlayPause() {
    widget.player.playOrPause();
    _showControlsTemporarily();
  }

  void _seekRelative(int seconds) {
    // Calculate new position
    final currentPos = widget.player.state.position;
    final newPosition = currentPos + Duration(seconds: seconds);

    // Clamp to valid range (0 to buffer end)
    final clampedPosition = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(0, _bufferEnd.inMilliseconds > 0 ? _bufferEnd.inMilliseconds : currentPos.inMilliseconds + 60000),
    );

    // Seek the player
    widget.player.seek(clampedPosition);

    // Update time behind live display
    final currentBehind = _totalTimeBehindLive;
    if (seconds > 0) {
      // Moving towards live
      final newBehind = currentBehind - Duration(seconds: seconds);
      if (newBehind.inSeconds <= 0) {
        // Reached live edge - don't auto-resume, let user decide
        _goLive(autoResume: false);
      } else {
        setState(() {
          // Set accumulated to new value and reset pause start if paused
          _accumulatedTimeBehind = newBehind;
          if (_isPaused) {
            _currentPauseStart = DateTime.now();
          }
        });
      }
    } else if (seconds < 0) {
      // Moving away from live
      final newBehind = currentBehind + Duration(seconds: seconds.abs());
      setState(() {
        _accumulatedTimeBehind = newBehind;
        _isLive = false;
        if (_isPaused) {
          _currentPauseStart = DateTime.now();
        }
      });
    }

    _showControlsTemporarily(keepVisible: _isPaused);
  }

  void _goLive({bool autoResume = true}) {
    // Seek to the end of buffer (live edge)
    if (_bufferEnd.inMilliseconds > 0) {
      widget.player.seek(_bufferEnd);
    }

    // Resume playback only if requested
    if (autoResume && _isPaused) {
      widget.player.play();
    }

    // Call the onGoLive callback if provided
    widget.onGoLive?.call();
    _resetToLive();
    _showControlsTemporarily();
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      // Default: pop the navigator
      Navigator.of(context).maybePop();
    }
  }

  void _goToPrevChannel() {
    final queue = widget.queue ?? PlayerState.queue;
    if (queue == null || queue.length <= 1) return;
    final currentIdx = widget.currentIndex > 0 ? widget.currentIndex : PlayerState.currentIndex;
    final newIndex = currentIdx - 1;
    if (newIndex >= 0) {
      EventBus().emit('player_content_item_index_changed', newIndex);
    }
  }

  void _goToNextChannel() {
    final queue = widget.queue ?? PlayerState.queue;
    if (queue == null || queue.length <= 1) return;
    final currentIdx = widget.currentIndex > 0 ? widget.currentIndex : PlayerState.currentIndex;
    final newIndex = currentIdx + 1;
    if (newIndex < queue.length) {
      EventBus().emit('player_content_item_index_changed', newIndex);
    }
  }

  bool get _hasPrevChannel {
    final queue = widget.queue ?? PlayerState.queue;
    if (queue == null || queue.length <= 1) return false;
    final currentIdx = widget.currentIndex > 0 ? widget.currentIndex : PlayerState.currentIndex;
    return currentIdx > 0;
  }

  bool get _hasNextChannel {
    final queue = widget.queue ?? PlayerState.queue;
    if (queue == null || queue.length <= 1) return false;
    final currentIdx = widget.currentIndex > 0 ? widget.currentIndex : PlayerState.currentIndex;
    return currentIdx < queue.length - 1;
  }

  ContentItem? get _prevChannel {
    final queue = widget.queue ?? PlayerState.queue;
    if (queue == null || queue.length <= 1) return null;
    final currentIdx = widget.currentIndex > 0 ? widget.currentIndex : PlayerState.currentIndex;
    if (currentIdx > 0) return queue[currentIdx - 1];
    return null;
  }

  ContentItem? get _nextChannel {
    final queue = widget.queue ?? PlayerState.queue;
    if (queue == null || queue.length <= 1) return null;
    final currentIdx = widget.currentIndex > 0 ? widget.currentIndex : PlayerState.currentIndex;
    if (currentIdx < queue.length - 1) return queue[currentIdx + 1];
    return null;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '-${minutes}m ${seconds}s';
    }
    return '-${seconds}s';
  }

  bool get _isBehindLive => !_isLive && _totalTimeBehindLive.inSeconds > 0;

  @override
  Widget build(BuildContext context) {
    // Use PlayerState directly to check if channel list is open
    final channelListOpen = PlayerState.showChannelList;

    // When channel list is open, ignore pointer events so clicks pass through
    return IgnorePointer(
      ignoring: channelListOpen,
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onTap,
            child: Focus(
            autofocus: false, // Don't steal focus
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.space ||
                    event.logicalKey == LogicalKeyboardKey.select) {
                  _togglePlayPause();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _seekRelative(-10);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _seekRelative(10);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  _goBack();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: AnimatedOpacity(
              opacity: _showControls || _isPaused ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls && !_isPaused,
                child: Stack(
                  children: [
                    // Subtle gradient overlay (macOS style - very subtle)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                            stops: const [0.0, 0.15, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Top bar with back button and favorite (subtle, no colored background)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              _buildBackButton(),
                              const Spacer(),
                              // Channel list toggle button
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A3A3C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.list,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Channel List',
                                  onPressed: () {
                                    // Toggle - emit null to toggle, true to open, false to close
                                    EventBus().emit('toggle_channel_list', null);
                                  },
                                ),
                              ),
                              // Record button
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A3A3C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _isRecording
                                    ? RecordingIndicator(
                                        contentId: PlayerState.currentContent?.id,
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.fiber_manual_record,
                                          color: Colors.white,
                                        ),
                                        tooltip: 'Record',
                                        onPressed: () => _startRecording(context),
                                      ),
                              ),
                              // Favorite button
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A3A3C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const VideoFavoriteWidget(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Center controls (pause/play and seek buttons)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rewind 30s - show when paused OR when behind live and hovering
                          if (_isPaused || _isBehindLive) ...[
                            _buildControlButton(
                              icon: Icons.replay_30,
                              onPressed: () => _seekRelative(-30),
                              tooltip: 'Rewind 30s',
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                          ],

                          // Rewind 10s - show when paused OR when behind live and hovering
                          if (_isPaused || _isBehindLive) ...[
                            _buildControlButton(
                              icon: Icons.replay_10,
                              onPressed: () => _seekRelative(-10),
                              tooltip: 'Rewind 10s',
                              size: 32,
                            ),
                            const SizedBox(width: 20),
                          ],

                          // Play/Pause button
                          _buildControlButton(
                            icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            onPressed: _togglePlayPause,
                            tooltip: _isPaused ? 'Play' : 'Pause',
                            size: 52,
                            isPrimary: true,
                          ),

                          // Forward 10s - show when paused OR when behind live and hovering
                          if (_isPaused || _isBehindLive) ...[
                            const SizedBox(width: 20),
                            _buildControlButton(
                              icon: Icons.forward_10,
                              onPressed: () => _seekRelative(10),
                              tooltip: 'Forward 10s',
                              size: 32,
                            ),
                          ],

                          // Forward 30s - show when paused OR when behind live and hovering
                          if (_isPaused || _isBehindLive) ...[
                            const SizedBox(width: 12),
                            _buildControlButton(
                              icon: Icons.forward_30,
                              onPressed: () => _seekRelative(30),
                              tooltip: 'Forward 30s',
                              size: 32,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // EPG info bar (above bottom controls)
                    if (_currentProgram != null && !channelListOpen)
                      Positioned(
                        left: 80,
                        right: 80,
                        bottom: 70,
                        child: _buildEpgInfoBar(),
                      ),

                    // Bottom bar with live indicator and time behind
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        child: _buildBottomBar(),
                      ),
                    ),

                    // Left side - Previous channel button (hide when channel list is open)
                    if (_hasPrevChannel && !channelListOpen)
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(child: _buildChannelNavButton(isNext: false)),
                      ),

                    // Right side - Next channel button (hide when channel list is open)
                    if (_hasNextChannel && !channelListOpen)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(child: _buildChannelNavButton(isNext: true)),
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

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _goBack,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C), // macOS light grey
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double size = 48,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: isPrimary ? size + 16 : size + 8,
            height: isPrimary ? size + 16 : size + 8,
            decoration: BoxDecoration(
              color: isPrimary
                  ? Colors.white.withOpacity(0.95)
                  : const Color(0xFF3A3A3C).withOpacity(0.8), // macOS grey
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.black : Colors.white,
              size: size,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Live indicator or time behind live
          if (_isBehindLive)
            _buildTimeBehindIndicator()
          else
            _buildLiveIndicator(),

          const SizedBox(width: 16),

          // Buffer bar showing time behind live (when behind)
          if (_isBehindLive)
            Expanded(
              child: _buildBufferBar(),
            )
          else
            const Spacer(),

          const SizedBox(width: 16),

          // Go Live button (only when behind live)
          if (_isBehindLive)
            _buildGoLiveButton(),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppThemes.accentRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBehindIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500), // macOS orange
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPaused ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            _formatDuration(_totalTimeBehindLive),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBufferBar() {
    // Show a simple progress bar indicating time behind live
    // Max display is 2 minutes
    const maxBuffer = Duration(minutes: 2);
    final progress = 1.0 - (_totalTimeBehindLive.inSeconds / maxBuffer.inSeconds).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white24,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Progress towards live
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9500), AppThemes.accentRed],
                        ),
                      ),
                    ),
                  ),
                  // Current position indicator
                  Positioned(
                    left: (constraints.maxWidth * progress) - 6,
                    top: -4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  // Live edge indicator
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppThemes.accentRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_totalTimeBehindLive),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const Text(
              'LIVE',
              style: TextStyle(color: AppThemes.accentRed, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoLiveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _goLive,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppThemes.accentRed,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next, size: 18, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'GO LIVE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpgInfoBar() {
    final timeFormat = DateFormat.Hm();
    final program = _currentProgram!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NOW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  program.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Time and progress row
          Row(
            children: [
              Text(
                '${timeFormat.format(program.startTime)} - ${timeFormat.format(program.endTime)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: program.progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${program.remainingTime.inMinutes}m left',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          // Next program (if available)
          if (_nextProgram != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEXT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _nextProgram!.title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  timeFormat.format(_nextProgram!.startTime),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelNavButton({required bool isNext}) {
    final channel = isNext ? _nextChannel : _prevChannel;
    if (channel == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isNext ? _goToNextChannel : _goToPrevChannel,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isNext)
                const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isNext ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    isNext ? 'Next' : 'Prev',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 100,
                    child: Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isNext ? TextAlign.end : TextAlign.start,
                    ),
                  ),
                ],
              ),
              if (isNext)
                const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
