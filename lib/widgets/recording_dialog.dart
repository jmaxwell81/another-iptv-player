import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/recording_job.dart';
import 'package:another_iptv_player/services/live_recording_service.dart';

/// Dialog for starting a live stream recording
class RecordingDialog extends StatefulWidget {
  final ContentItem content;
  final String playlistId;

  const RecordingDialog({
    super.key,
    required this.content,
    required this.playlistId,
  });

  @override
  State<RecordingDialog> createState() => _RecordingDialogState();

  /// Show the recording dialog
  static Future<RecordingJob?> show(
    BuildContext context, {
    required ContentItem content,
    required String playlistId,
  }) {
    return showDialog<RecordingJob>(
      context: context,
      builder: (context) => RecordingDialog(
        content: content,
        playlistId: playlistId,
      ),
    );
  }
}

class _RecordingDialogState extends State<RecordingDialog> {
  final LiveRecordingService _recordingService = LiveRecordingService();
  bool _isCheckingFfmpeg = true;
  bool _ffmpegAvailable = false;
  String? _ffmpegError;
  String _installInstructions = '';

  // Duration selection
  int _selectedMinutes = 30;
  final List<int> _presetMinutes = [15, 30, 60, 90, 120, 180];
  bool _useCustomDuration = false;
  final _customMinutesController = TextEditingController(text: '30');

  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
  }

  @override
  void dispose() {
    _customMinutesController.dispose();
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    setState(() => _isCheckingFfmpeg = true);

    await _recordingService.initialize();
    final (available, error, instructions) = await _recordingService.checkFfmpeg();

    if (mounted) {
      setState(() {
        _isCheckingFfmpeg = false;
        _ffmpegAvailable = available;
        _ffmpegError = error;
        _installInstructions = instructions;
      });
    }
  }

  int get _durationMinutes {
    if (_useCustomDuration) {
      return int.tryParse(_customMinutesController.text) ?? 30;
    }
    return _selectedMinutes;
  }

  Future<void> _startRecording() async {
    setState(() => _isStarting = true);

    final job = await _recordingService.startRecording(
      content: widget.content,
      playlistId: widget.playlistId,
      duration: Duration(minutes: _durationMinutes),
    );

    if (mounted) {
      if (job != null) {
        Navigator.of(context).pop(job);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording started: ${widget.content.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          const Text('Record Live Stream'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: _isCheckingFfmpeg
            ? _buildCheckingFfmpeg()
            : _ffmpegAvailable
                ? _buildDurationSelection(theme)
                : _buildFfmpegNotFound(theme),
      ),
      actions: _buildActions(theme),
    );
  }

  Widget _buildCheckingFfmpeg() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Checking FFmpeg availability...'),
      ],
    );
  }

  Widget _buildFfmpegNotFound(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FFmpeg Not Found',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    if (_ffmpegError != null)
                      Text(
                        _ffmpegError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Recording requires FFmpeg to be installed on your system.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Installation Instructions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                _installInstructions,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _installInstructions));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Instructions copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _checkFfmpeg,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Check Again'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationSelection(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.live_tv, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.content.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Will be saved to your Recordings',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Duration label
        const Text(
          'Recording Duration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Preset duration chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presetMinutes.map((minutes) {
              final isSelected = !_useCustomDuration && _selectedMinutes == minutes;
              return ChoiceChip(
                label: Text(_formatMinutes(minutes)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _useCustomDuration = false;
                      _selectedMinutes = minutes;
                    });
                  }
                },
              );
            }),
            ChoiceChip(
              label: const Text('Custom'),
              selected: _useCustomDuration,
              onSelected: (selected) {
                setState(() {
                  _useCustomDuration = selected;
                });
              },
            ),
          ],
        ),

        // Custom duration input
        if (_useCustomDuration) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _customMinutesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('minutes'),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Info note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recording will continue in the background. You can watch other content while recording.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  List<Widget> _buildActions(ThemeData theme) {
    if (_isCheckingFfmpeg) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ];
    }

    if (!_ffmpegAvailable) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isStarting ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: _isStarting ? null : _startRecording,
        icon: _isStarting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fiber_manual_record, size: 16),
        label: Text(_isStarting ? 'Starting...' : 'Start Recording'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
        ),
      ),
    ];
  }
}
