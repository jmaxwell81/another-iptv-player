import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:another_iptv_player/controllers/epg_controller.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/live_recording_service.dart';
import 'package:another_iptv_player/services/player_state.dart';
import 'package:another_iptv_player/widgets/recording_dialog.dart';
import 'package:another_iptv_player/widgets/recording_status_widget.dart';

/// EPG info overlay for live streams that shows at the bottom of the player.
/// Shows current program info, prev/next channel navigation, and subtitle toggle.
class EPGInfoOverlay extends StatefulWidget {
  final Player player;
  final ContentItem contentItem;
  final List<ContentItem>? queue;
  final int currentIndex;
  final VoidCallback? onChannelChange;

  const EPGInfoOverlay({
    super.key,
    required this.player,
    required this.contentItem,
    this.queue,
    this.currentIndex = 0,
    this.onChannelChange,
  });

  @override
  State<EPGInfoOverlay> createState() => _EPGInfoOverlayState();
}

class _EPGInfoOverlayState extends State<EPGInfoOverlay> {
  bool _showOverlay = false;
  Timer? _hideTimer;
  Timer? _progressTimer;

  // EPG data
  final EpgController _epgController = EpgController();
  EpgProgram? _currentProgram;
  EpgProgram? _nextProgram;
  bool _isLoadingEpg = true;

  // Prev/next channel EPG
  EpgProgram? _prevChannelProgram;
  EpgProgram? _nextChannelProgram;
  ContentItem? _prevChannel;
  ContentItem? _nextChannel;

  // Subtitle state
  bool _subtitlesEnabled = false;
  List<SubtitleTrack> _subtitleTracks = [];
  StreamSubscription? _subtitleTrackSubscription;

  // Recording state
  final LiveRecordingService _recordingService = LiveRecordingService();

  @override
  void initState() {
    super.initState();
    _recordingService.addListener(_onRecordingStateChanged);
    _recordingService.initialize();
    _loadEpgData();
    _loadChannelNeighbors();
    _setupSubtitleListener();
    _startProgressTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _subtitleTrackSubscription?.cancel();
    _recordingService.removeListener(_onRecordingStateChanged);
    super.dispose();
  }

  void _onRecordingStateChanged() {
    if (mounted) setState(() {});
  }

  bool get _isRecording => _recordingService.isRecording(widget.contentItem.id);

  @override
  void didUpdateWidget(EPGInfoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentItem.id != widget.contentItem.id) {
      _loadEpgData();
      _loadChannelNeighbors();
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      _loadChannelNeighbors();
    }
  }

  void _setupSubtitleListener() {
    _subtitleTracks = PlayerState.subtitles;
    _subtitlesEnabled = PlayerState.selectedSubtitle.id != 'no';

    _subtitleTrackSubscription =
        EventBus().on<dynamic>('player_track_changed').listen((_) {
      if (mounted) {
        setState(() {
          _subtitleTracks = PlayerState.subtitles;
          _subtitlesEnabled = PlayerState.selectedSubtitle.id != 'no';
        });
      }
    });

    EventBus().on<Tracks>('player_tracks').listen((tracks) {
      if (mounted) {
        setState(() {
          _subtitleTracks = tracks.subtitle;
        });
      }
    });
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadEpgData();
      }
    });
  }

  Future<void> _loadEpgData() async {
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) {
      if (mounted) {
        setState(() => _isLoadingEpg = false);
      }
      return;
    }

    final channelId = widget.contentItem.liveStream?.epgChannelId ??
        widget.contentItem.liveStream?.streamId ??
        widget.contentItem.m3uItem?.tvgId ??
        widget.contentItem.id;

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

  Future<void> _loadChannelNeighbors() async {
    final queue = widget.queue;
    if (queue == null || queue.length <= 1) {
      setState(() {
        _prevChannel = null;
        _nextChannel = null;
        _prevChannelProgram = null;
        _nextChannelProgram = null;
      });
      return;
    }

    final currentIdx = widget.currentIndex;

    // Get prev/next channels
    _prevChannel = currentIdx > 0 ? queue[currentIdx - 1] : null;
    _nextChannel = currentIdx < queue.length - 1 ? queue[currentIdx + 1] : null;

    // Load EPG for neighbors
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId != null) {
      if (_prevChannel != null) {
        _prevChannelProgram = await _loadChannelCurrentProgram(_prevChannel!, playlistId);
      }
      if (_nextChannel != null) {
        _nextChannelProgram = await _loadChannelCurrentProgram(_nextChannel!, playlistId);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<EpgProgram?> _loadChannelCurrentProgram(ContentItem channel, String playlistId) async {
    final channelId = channel.liveStream?.epgChannelId ??
        channel.liveStream?.streamId ??
        channel.m3uItem?.tvgId ??
        channel.id;

    final now = DateTime.now();
    final programs = await _epgController.getPrograms(
      channelId,
      playlistId,
      now.subtract(const Duration(hours: 1)),
      now.add(const Duration(hours: 2)),
    );

    for (final program in programs) {
      if (program.isLive) {
        return program;
      }
    }
    return null;
  }

  void _showOverlayTemporarily() {
    setState(() => _showOverlay = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _goToPrevChannel() {
    if (_prevChannel == null || widget.queue == null) return;
    final newIndex = widget.currentIndex - 1;
    if (newIndex >= 0) {
      EventBus().emit('player_content_item_index_changed', newIndex);
      widget.onChannelChange?.call();
    }
  }

  void _goToNextChannel() {
    if (_nextChannel == null || widget.queue == null) return;
    final newIndex = widget.currentIndex + 1;
    if (newIndex < widget.queue!.length) {
      EventBus().emit('player_content_item_index_changed', newIndex);
      widget.onChannelChange?.call();
    }
  }

  void _toggleSubtitles() {
    if (_subtitleTracks.isEmpty) return;

    if (_subtitlesEnabled) {
      // Disable subtitles
      EventBus().emit('subtitle_track_changed', SubtitleTrack.no());
      setState(() => _subtitlesEnabled = false);
    } else {
      // Enable first available subtitle track
      final firstTrack = _subtitleTracks.firstWhere(
        (t) => t.id != 'no' && t.id != 'auto',
        orElse: () => _subtitleTracks.first,
      );
      EventBus().emit('subtitle_track_changed', firstTrack);
      setState(() => _subtitlesEnabled = true);
    }
    _showOverlayTemporarily();
  }

  void _startRecording(BuildContext context) {
    final playlistId = AppState.currentPlaylist?.id ?? 'unknown';
    RecordingDialog.show(
      context,
      content: widget.contentItem,
      playlistId: playlistId,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use deferToChild so we don't block the LiveStreamControls underneath
    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _showOverlayTemporarily();
            _goToPrevChannel();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _showOverlayTemporarily();
            _goToNextChannel();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
            _toggleSubtitles();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyI) {
            // Toggle EPG info overlay with 'I' key
            if (_showOverlay) {
              setState(() => _showOverlay = false);
            } else {
              _showOverlayTemporarily();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedOpacity(
        opacity: _showOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_showOverlay,
          child: _buildOverlay(),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Stack(
      children: [
        // Bottom EPG info bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 80, // Above the existing LiveStreamControls bar
          child: _buildEpgInfoBar(),
        ),

        // Left channel navigation (previous channel)
        if (_prevChannel != null)
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(child: _buildChannelNavButton(
              isNext: false,
              channel: _prevChannel!,
              program: _prevChannelProgram,
            )),
          ),

        // Right channel navigation (next channel)
        if (_nextChannel != null)
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(child: _buildChannelNavButton(
              isNext: true,
              channel: _nextChannel!,
              program: _nextChannelProgram,
            )),
          ),
      ],
    );
  }

  Widget _buildEpgInfoBar() {
    final timeFormat = DateFormat.Hm();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel name row with subtitle toggle
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.contentItem.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Record button
              if (_isRecording)
                RecordingIndicator(contentId: widget.contentItem.id)
              else
                IconButton(
                  onPressed: () => _startRecording(context),
                  icon: const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.white54,
                    size: 22,
                  ),
                  tooltip: 'Record this stream',
                ),
              // Subtitle toggle button
              if (_subtitleTracks.isNotEmpty)
                IconButton(
                  onPressed: _toggleSubtitles,
                  icon: Icon(
                    _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
                    color: _subtitlesEnabled ? Colors.blue : Colors.white54,
                    size: 22,
                  ),
                  tooltip: _subtitlesEnabled ? 'Disable subtitles' : 'Enable subtitles',
                ),
            ],
          ),

          if (_currentProgram != null) ...[
            const SizedBox(height: 12),
            // Current program
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentProgram!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${timeFormat.format(_currentProgram!.startTime)} - ${timeFormat.format(_currentProgram!.endTime)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _currentProgram!.progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_currentProgram!.remainingTime.inMinutes}m left',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (_currentProgram!.description != null &&
                          _currentProgram!.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _currentProgram!.description!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Next program
            if (_nextProgram != null) ...[
              const SizedBox(height: 10),
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
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeFormat.format(_nextProgram!.startTime),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ] else if (!_isLoadingEpg) ...[
            const SizedBox(height: 8),
            Text(
              'No program information available',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading program info...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelNavButton({
    required bool isNext,
    required ContentItem channel,
    EpgProgram? program,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isNext ? _goToNextChannel : _goToPrevChannel,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
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
                    isNext ? 'Next Channel' : 'Prev Channel',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 140,
                    child: Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isNext ? TextAlign.end : TextAlign.start,
                    ),
                  ),
                  if (program != null) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 140,
                      child: Text(
                        program.title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isNext ? TextAlign.end : TextAlign.start,
                      ),
                    ),
                  ],
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
