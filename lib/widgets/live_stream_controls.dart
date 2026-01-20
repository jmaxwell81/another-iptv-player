import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/services/timeshift_service.dart';
import 'package:another_iptv_player/models/timeshift.dart';

/// Controls overlay for live streams
/// Shows LIVE indicator, record button, and timeshift controls when available
class LiveStreamControls extends StatefulWidget {
  final VoidCallback? onRecord;
  final VoidCallback? onGoLive;
  final Function(Duration)? onSeek;
  final VoidCallback? onPlayPause;
  final bool isRecording;
  final bool isPlaying;

  const LiveStreamControls({
    super.key,
    this.onRecord,
    this.onGoLive,
    this.onSeek,
    this.onPlayPause,
    this.isRecording = false,
    this.isPlaying = true,
  });

  @override
  State<LiveStreamControls> createState() => _LiveStreamControlsState();
}

class _LiveStreamControlsState extends State<LiveStreamControls> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: TimeshiftService(),
      child: Consumer<TimeshiftService>(
        builder: (context, service, child) {
          final state = service.state;
          final isBuffering = state.isBuffering;
          final isBehindLive = state.isBehindLive;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timeshift progress bar (only when buffering is active)
                if (isBuffering) ...[
                  _buildTimeshiftBar(context, state, service),
                  const SizedBox(height: 8),
                ],
                // Playback controls row (always visible for live streams)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rewind 30 seconds (only when buffering)
                    if (isBuffering)
                      IconButton(
                        onPressed: () {
                          final newPos = state.currentPosition - const Duration(seconds: 30);
                          if (widget.onSeek != null) {
                            widget.onSeek!(newPos);
                          } else {
                            service.seekTo(newPos);
                          }
                        },
                        icon: const Icon(Icons.replay_30, color: Colors.white),
                        iconSize: 32,
                        tooltip: 'Rewind 30s',
                      ),
                    // Rewind 10 seconds (only when buffering)
                    if (isBuffering)
                      IconButton(
                        onPressed: () {
                          final newPos = state.currentPosition - const Duration(seconds: 10);
                          if (widget.onSeek != null) {
                            widget.onSeek!(newPos);
                          } else {
                            service.seekTo(newPos);
                          }
                        },
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        iconSize: 32,
                        tooltip: 'Rewind 10s',
                      ),
                    if (isBuffering) const SizedBox(width: 16),
                    // Play/Pause button (always visible)
                    IconButton(
                      onPressed: widget.onPlayPause,
                      icon: Icon(
                        widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      iconSize: 48,
                      tooltip: widget.isPlaying ? 'Pause' : 'Play',
                    ),
                    if (isBuffering) const SizedBox(width: 16),
                    // Forward 10 seconds (only when buffering)
                    if (isBuffering)
                      IconButton(
                        onPressed: () {
                          final newPos = state.currentPosition + const Duration(seconds: 10);
                          if (widget.onSeek != null) {
                            widget.onSeek!(newPos);
                          } else {
                            service.seekTo(newPos);
                          }
                        },
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                        iconSize: 32,
                        tooltip: 'Forward 10s',
                      ),
                    // Forward 30 seconds (only when buffering)
                    if (isBuffering)
                      IconButton(
                        onPressed: () {
                          final newPos = state.currentPosition + const Duration(seconds: 30);
                          if (widget.onSeek != null) {
                            widget.onSeek!(newPos);
                          } else {
                            service.seekTo(newPos);
                          }
                        },
                        icon: const Icon(Icons.forward_30, color: Colors.white),
                        iconSize: 32,
                        tooltip: 'Forward 30s',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Bottom controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Live/Behind live indicator
                    _buildLiveIndicator(context, state),

                    const Spacer(),

                    // Buffer info (when buffering)
                    if (isBuffering)
                      Text(
                        'Buffer: ${state.bufferDurationText}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),

                    const SizedBox(width: 12),

                    // Go to live button (when behind live)
                    if (isBehindLive)
                      TextButton.icon(
                        onPressed: widget.onGoLive ?? service.goLive,
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Go Live'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 0),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),

                    // Record button
                    _buildRecordButton(context, service),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveIndicator(BuildContext context, TimeshiftState state) {
    if (state.isBuffering && state.isBehindLive) {
      // Behind live indicator
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              state.behindLiveText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      // Live indicator
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
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
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRecordButton(BuildContext context, TimeshiftService service) {
    final isRecording = widget.isRecording || service.isTimeshiftActive;

    return IconButton(
      onPressed: () {
        if (widget.onRecord != null) {
          widget.onRecord!();
        } else {
          // Show recording options dialog
          _showRecordingOptionsDialog(context, service);
        }
      },
      icon: Icon(
        isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
        color: isRecording ? Colors.red : Colors.white,
        size: 28,
      ),
      tooltip: isRecording ? 'Stop Recording' : 'Start Recording',
      style: IconButton.styleFrom(
        backgroundColor: Colors.black45,
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  void _showRecordingOptionsDialog(BuildContext context, TimeshiftService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recording Options'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (service.isTimeshiftActive) ...[
                Text(
                  'Currently buffering: ${service.state.bufferDurationText}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.save),
                  title: const Text('Save Buffer'),
                  subtitle: const Text('Save current buffer to recordings'),
                  onTap: () async {
                    Navigator.pop(context);
                    final recording = await service.saveBuffer();
                    if (recording != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved: ${recording.contentName}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.stop),
                  title: const Text('Stop Buffering'),
                  subtitle: const Text('Stop timeshift and discard buffer'),
                  onTap: () async {
                    Navigator.pop(context);
                    await service.stopTimeshift();
                  },
                ),
              ] else ...[
                // Show FFmpeg status
                _buildFfmpegStatusWidget(context, service),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFfmpegStatusWidget(BuildContext context, TimeshiftService service) {
    final status = service.ffmpegStatus;
    final isAvailable = service.isFfmpegAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isAvailable ? Icons.check_circle : Icons.error_outline,
              color: isAvailable ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              isAvailable ? 'FFmpeg Available' : _getFfmpegStatusTitle(status),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!isAvailable) ...[
          Text(
            service.ffmpegError ?? 'FFmpeg is required for timeshift recording.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              TimeshiftService.getInstallInstructions(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          if (status == FfmpegStatus.sandboxRestricted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This app is running in a sandbox which restricts FFmpeg execution. '
                      'Try running a non-sandboxed version.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          Text(
            'Timeshift is ready. To start recording, the player needs to be configured to enable timeshift.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await service.checkFfmpegAvailability();
            if (context.mounted) {
              Navigator.pop(context);
              _showRecordingOptionsDialog(context, service);
            }
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Re-check FFmpeg'),
        ),
      ],
    );
  }

  String _getFfmpegStatusTitle(FfmpegStatus status) {
    switch (status) {
      case FfmpegStatus.available:
        return 'FFmpeg Available';
      case FfmpegStatus.notFound:
        return 'FFmpeg Not Found';
      case FfmpegStatus.sandboxRestricted:
        return 'Sandbox Restricted';
      case FfmpegStatus.permissionDenied:
        return 'Permission Denied';
      case FfmpegStatus.error:
        return 'FFmpeg Error';
      case FfmpegStatus.unknown:
        return 'Checking...';
    }
  }

  Widget _buildTimeshiftBar(BuildContext context, TimeshiftState state, TimeshiftService service) {
    final totalWidth = MediaQuery.of(context).size.width - 32;
    final bufferSeconds = state.bufferDuration.inSeconds;
    final maxBufferSeconds = TimeshiftState.maxBufferDuration.inSeconds;

    // Calculate positions
    final bufferWidth = (bufferSeconds / maxBufferSeconds) * totalWidth;
    final positionPercent = bufferSeconds > 0
        ? state.currentPosition.inSeconds / bufferSeconds
        : 1.0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final localPosition = details.localPosition.dx;
        final percent = (localPosition / bufferWidth).clamp(0.0, 1.0);
        final newPosition = Duration(seconds: (bufferSeconds * percent).round());
        if (widget.onSeek != null) {
          widget.onSeek!(newPosition);
        } else {
          service.seekTo(newPosition);
        }
      },
      onTapDown: (details) {
        final localPosition = details.localPosition.dx;
        final percent = (localPosition / bufferWidth).clamp(0.0, 1.0);
        final newPosition = Duration(seconds: (bufferSeconds * percent).round());
        if (widget.onSeek != null) {
          widget.onSeek!(newPosition);
        } else {
          service.seekTo(newPosition);
        }
      },
      child: Container(
        height: 24,
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Max buffer capacity track (dark)
            Container(
              width: totalWidth,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Buffered content (shows how much is recorded)
            Container(
              width: bufferWidth.clamp(0.0, totalWidth),
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Current position indicator
            Positioned(
              left: (bufferWidth * positionPercent).clamp(0.0, totalWidth - 12),
              top: -4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: state.isLive ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            // Live edge indicator
            Positioned(
              left: bufferWidth.clamp(0.0, totalWidth - 8),
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
