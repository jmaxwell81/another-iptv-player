import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/services/timeshift_service.dart';
import 'package:another_iptv_player/models/timeshift.dart';

/// Widget showing timeshift buffer status and controls
/// Displays a timeline showing how far behind live the user is
/// and allows seeking within the buffer
class TimeshiftControls extends StatelessWidget {
  final VoidCallback? onGoLive;
  final VoidCallback? onSaveBuffer;
  final Function(Duration)? onSeek;

  const TimeshiftControls({
    super.key,
    this.onGoLive,
    this.onSaveBuffer,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: TimeshiftService(),
      child: Consumer<TimeshiftService>(
        builder: (context, service, child) {
          final state = service.state;

          if (!state.isBuffering) {
            return const SizedBox.shrink();
          }

          return _TimeshiftControlsContent(
            state: state,
            onGoLive: onGoLive ?? service.goLive,
            onSaveBuffer: onSaveBuffer,
            onSeek: onSeek ?? service.seekTo,
          );
        },
      ),
    );
  }
}

class _TimeshiftControlsContent extends StatelessWidget {
  final TimeshiftState state;
  final VoidCallback onGoLive;
  final VoidCallback? onSaveBuffer;
  final Function(Duration) onSeek;

  const _TimeshiftControlsContent({
    required this.state,
    required this.onGoLive,
    this.onSaveBuffer,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
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
          // Timeshift progress bar
          _buildTimeshiftBar(context),
          const SizedBox(height: 8),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Behind live indicator
              if (state.isBehindLive) ...[
                Container(
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
                ),
              ] else ...[
                // Live indicator
                Container(
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
                ),
              ],
              // Buffer info
              Text(
                'Buffer: ${state.bufferDurationText}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              // Go to live button
              if (state.isBehindLive)
                TextButton.icon(
                  onPressed: onGoLive,
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
              // Save buffer button
              if (state.isBehindLive && onSaveBuffer != null)
                IconButton(
                  onPressed: onSaveBuffer,
                  icon: const Icon(Icons.save, color: Colors.white70),
                  iconSize: 20,
                  tooltip: 'Save buffer',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeshiftBar(BuildContext context) {
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
        onSeek(newPosition);
      },
      onTapDown: (details) {
        final localPosition = details.localPosition.dx;
        final percent = (localPosition / bufferWidth).clamp(0.0, 1.0);
        final newPosition = Duration(seconds: (bufferSeconds * percent).round());
        onSeek(newPosition);
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

/// Compact timeshift indicator for showing in player overlay
class TimeshiftIndicator extends StatelessWidget {
  const TimeshiftIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: TimeshiftService(),
      child: Consumer<TimeshiftService>(
        builder: (context, service, child) {
          final state = service.state;

          if (!state.isBuffering || !state.isBehindLive) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_filled, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  state.behindLiveText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: service.goLive,
                  child: const Text(
                    'GO LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dialog for saving timeshift buffer
class SaveTimeshiftDialog extends StatefulWidget {
  final TimeshiftState state;
  final Function(Duration?) onSave;

  const SaveTimeshiftDialog({
    super.key,
    required this.state,
    required this.onSave,
  });

  @override
  State<SaveTimeshiftDialog> createState() => _SaveTimeshiftDialogState();
}

class _SaveTimeshiftDialogState extends State<SaveTimeshiftDialog> {
  bool _recordAdditional = false;
  int _additionalMinutes = 30;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Timeshift Buffer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current buffer: ${widget.state.bufferDurationText}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Record additional time'),
            subtitle: const Text('Continue recording after saving buffer'),
            value: _recordAdditional,
            onChanged: (value) {
              setState(() {
                _recordAdditional = value ?? false;
              });
            },
          ),
          if (_recordAdditional) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Additional: '),
                Expanded(
                  child: Slider(
                    value: _additionalMinutes.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: '$_additionalMinutes min',
                    onChanged: (value) {
                      setState(() {
                        _additionalMinutes = value.round();
                      });
                    },
                  ),
                ),
                Text('$_additionalMinutes min'),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final additional = _recordAdditional
                ? Duration(minutes: _additionalMinutes)
                : null;
            widget.onSave(additional);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
