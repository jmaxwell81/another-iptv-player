import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:another_iptv_player/controllers/epg_controller.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/pip_manager.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/widgets/player_widget.dart';

/// Widget that displays a live stream preview with EPG information
class LiveStreamPreviewWidget extends StatefulWidget {
  /// Height of the preview panel
  final double height;

  /// Callback when preview starts playing (for PiP state management)
  final VoidCallback? onPreviewStarted;

  /// Callback when preview is closed
  final VoidCallback? onPreviewClosed;

  const LiveStreamPreviewWidget({
    super.key,
    this.height = 220,
    this.onPreviewStarted,
    this.onPreviewClosed,
  });

  @override
  State<LiveStreamPreviewWidget> createState() => _LiveStreamPreviewWidgetState();
}

class _LiveStreamPreviewWidgetState extends State<LiveStreamPreviewWidget> with RouteAware {
  ContentItem? _previewItem;
  EpgProgram? _currentProgram;
  EpgProgram? _nextProgram;
  Key? _playerKey;
  StreamSubscription? _hoverSubscription;
  StreamSubscription? _navigationSubscription;
  final EpgController _epgController = EpgController();
  final PipManager _pipManager = PipManager();
  Timer? _progressTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupHoverListener();
    _setupNavigationListener();
    _startProgressTimer();
  }

  @override
  void dispose() {
    _hoverSubscription?.cancel();
    _navigationSubscription?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _setupNavigationListener() {
    // Listen for navigation events to transfer to PiP
    _navigationSubscription = EventBus().on<String>('navigation_change').listen((screen) {
      if (!mounted) return;
      if (_previewItem != null && screen != 'live_streams') {
        // Transfer current preview to PiP
        _pipManager.transferToPip(_previewItem!, 'live_streams');
        setState(() {
          _previewItem = null;
          _currentProgram = null;
          _nextProgram = null;
          _playerKey = null;
        });
      }
    });
  }

  void _setupHoverListener() {
    _hoverSubscription = EventBus().on<ContentItem>('live_stream_hover').listen((item) {
      if (!mounted) return;
      _onItemHovered(item);
    });
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _previewItem != null) {
        _refreshEpgData();
      }
    });
  }

  Future<void> _onItemHovered(ContentItem item) async {
    if (item.contentType != ContentType.liveStream) return;
    if (_previewItem?.id == item.id) return;

    setState(() {
      _isLoading = true;
      _previewItem = item;
      _playerKey = ValueKey('preview_${item.id}_${DateTime.now().millisecondsSinceEpoch}');
    });

    widget.onPreviewStarted?.call();
    await _loadEpgData(item);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEpgData(ContentItem item) async {
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) return;

    final channelId = item.liveStream?.epgChannelId ??
                      item.liveStream?.streamId ??
                      item.m3uItem?.tvgId ??
                      item.id;

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
    });
  }

  Future<void> _refreshEpgData() async {
    if (_previewItem == null) return;
    await _loadEpgData(_previewItem!);
  }

  void _closePreview() {
    setState(() {
      _previewItem = null;
      _currentProgram = null;
      _nextProgram = null;
      _playerKey = null;
    });
    widget.onPreviewClosed?.call();
  }

  void _watchFullScreen(BuildContext context) {
    if (_previewItem == null) return;

    // Store the item before closing preview
    final item = _previewItem!;
    _closePreview();

    navigateByContentType(context, item);
  }

  @override
  Widget build(BuildContext context) {
    if (_previewItem == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Video preview player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  if (_playerKey != null)
                    PlayerWidget(
                      key: _playerKey,
                      contentItem: _previewItem!,
                      showControls: false,
                      showInfo: false,
                    ),
                  // Loading overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  // Live indicator
                  if (_currentProgram?.isLive == true)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
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
                    ),
                ],
              ),
            ),
          ),
          // EPG info panel
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel name
                  Text(
                    _previewItem!.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Current program
                  if (_currentProgram != null) ...[
                    _buildProgramInfo(
                      context,
                      'Now',
                      _currentProgram!,
                      isLive: true,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Next program
                  if (_nextProgram != null) ...[
                    _buildProgramInfo(
                      context,
                      'Next',
                      _nextProgram!,
                      isLive: false,
                    ),
                  ],
                  if (_currentProgram == null && _nextProgram == null)
                    Text(
                      'No program information available',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  const Spacer(),
                  // Action buttons
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _watchFullScreen(context),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Watch'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _closePreview,
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramInfo(
    BuildContext context,
    String label,
    EpgProgram program, {
    required bool isLive,
  }) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.Hm();
    final startTime = timeFormat.format(program.startTime);
    final endTime = timeFormat.format(program.endTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isLive ? Colors.red : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isLive ? Colors.white : theme.colorScheme.onPrimaryContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                program.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isLive ? theme.colorScheme.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Time range and progress
        Row(
          children: [
            Text(
              '$startTime - $endTime',
              style: theme.textTheme.bodySmall,
            ),
            if (isLive) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: program.progress.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${program.remainingTime.inMinutes}m left',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        // Description (only for current program)
        if (isLive && program.description != null && program.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            program.description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
