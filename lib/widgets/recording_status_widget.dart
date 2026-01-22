import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/recording_job.dart';
import 'package:another_iptv_player/services/live_recording_service.dart';

/// Widget that displays active recording status in the player or app bar
class RecordingStatusWidget extends StatefulWidget {
  /// Whether to show as a compact indicator or full status
  final bool compact;

  /// Optional specific content ID to show status for
  final String? contentId;

  const RecordingStatusWidget({
    super.key,
    this.compact = false,
    this.contentId,
  });

  @override
  State<RecordingStatusWidget> createState() => _RecordingStatusWidgetState();
}

class _RecordingStatusWidgetState extends State<RecordingStatusWidget>
    with SingleTickerProviderStateMixin {
  final LiveRecordingService _recordingService = LiveRecordingService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _recordingService.addListener(_onRecordingStateChanged);
    _recordingService.initialize();

    // Pulsing animation for recording indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recordingService.removeListener(_onRecordingStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onRecordingStateChanged() {
    if (mounted) setState(() {});
  }

  RecordingJob? get _relevantJob {
    if (widget.contentId != null) {
      return _recordingService.getRecordingForContent(widget.contentId!);
    }
    // Return first active job if no specific content ID
    final activeJobs = _recordingService.activeJobs;
    return activeJobs.isNotEmpty ? activeJobs.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final job = _relevantJob;

    if (job == null) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompactIndicator(job);
    }

    return _buildFullStatus(context, job);
  }

  Widget _buildCompactIndicator(RecordingJob job) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: _pulseAnimation.value * 0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
              const SizedBox(width: 4),
              Text(
                'REC ${job.recordedDurationText}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullStatus(BuildContext context, RecordingJob job) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Icon(
                      Icons.fiber_manual_record,
                      color: Colors.red.withValues(alpha: _pulseAnimation.value),
                      size: 14,
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recording',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${job.recordedDurationText} / ${job.targetDurationText}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),

            // Content name
            Text(
              job.contentName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Action buttons
            Row(
              children: [
                Text(
                  '${job.remainingDurationText} remaining',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                // Extend button
                TextButton.icon(
                  onPressed: () => _showExtendDialog(context, job),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Extend'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                // Stop button
                TextButton.icon(
                  onPressed: () => _showStopConfirmation(context, job),
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('Stop'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExtendDialog(BuildContext context, RecordingJob job) {
    showDialog(
      context: context,
      builder: (context) => _ExtendRecordingDialog(
        job: job,
        onExtend: (duration) async {
          await _recordingService.extendRecording(job.id, duration);
        },
      ),
    );
  }

  void _showStopConfirmation(BuildContext context, RecordingJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stop recording "${job.contentName}"?'),
            const SizedBox(height: 8),
            Text(
              'Recorded: ${job.recordedDurationText}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Recording'),
          ),
          FilledButton(
            onPressed: () {
              _recordingService.stopRecording(job.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recording stopped and saved')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Stop Recording'),
          ),
        ],
      ),
    );
  }
}

class _ExtendRecordingDialog extends StatefulWidget {
  final RecordingJob job;
  final Future<void> Function(Duration duration) onExtend;

  const _ExtendRecordingDialog({
    required this.job,
    required this.onExtend,
  });

  @override
  State<_ExtendRecordingDialog> createState() => _ExtendRecordingDialogState();
}

class _ExtendRecordingDialogState extends State<_ExtendRecordingDialog> {
  int _selectedMinutes = 30;
  bool _isExtending = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Extend Recording'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add more time to "${widget.job.contentName}"'),
          const SizedBox(height: 16),
          const Text('Add:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [15, 30, 60, 90].map((minutes) {
              return ChoiceChip(
                label: Text('$minutes min'),
                selected: _selectedMinutes == minutes,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedMinutes = minutes);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'New total: ${_formatDuration(widget.job.targetDuration + Duration(minutes: _selectedMinutes))}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isExtending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isExtending
              ? null
              : () async {
                  setState(() => _isExtending = true);
                  await widget.onExtend(Duration(minutes: _selectedMinutes));
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Recording extended by $_selectedMinutes minutes')),
                    );
                  }
                },
          child: _isExtending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Extend'),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Compact recording indicator for overlays
class RecordingIndicator extends StatelessWidget {
  final String? contentId;

  const RecordingIndicator({super.key, this.contentId});

  @override
  Widget build(BuildContext context) {
    return RecordingStatusWidget(
      compact: true,
      contentId: contentId,
    );
  }
}

/// Full-page recordings manager
class RecordingsManagerWidget extends StatefulWidget {
  const RecordingsManagerWidget({super.key});

  @override
  State<RecordingsManagerWidget> createState() => _RecordingsManagerWidgetState();
}

class _RecordingsManagerWidgetState extends State<RecordingsManagerWidget> {
  final LiveRecordingService _recordingService = LiveRecordingService();

  @override
  void initState() {
    super.initState();
    _recordingService.addListener(_onRecordingStateChanged);
    _recordingService.initialize();
  }

  @override
  void dispose() {
    _recordingService.removeListener(_onRecordingStateChanged);
    super.dispose();
  }

  void _onRecordingStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeJobs = _recordingService.activeJobs;
    final completedJobs = _recordingService.completedJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        actions: [
          if (completedJobs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear completed',
              onPressed: () => _showClearConfirmation(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active recordings
          if (activeJobs.isNotEmpty) ...[
            Text(
              'Active Recordings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...activeJobs.map((job) => _buildJobCard(context, job, isActive: true)),
            const SizedBox(height: 24),
          ],

          // Completed recordings
          if (completedJobs.isNotEmpty) ...[
            Text(
              'Completed Recordings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...completedJobs.map((job) => _buildJobCard(context, job, isActive: false)),
          ],

          // Empty state
          if (activeJobs.isEmpty && completedJobs.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a recording from any live stream player',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, RecordingJob job, {required bool isActive}) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    switch (job.status) {
      case RecordingStatus.recording:
        statusColor = Colors.red;
        statusIcon = Icons.fiber_manual_record;
        break;
      case RecordingStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case RecordingStatus.failed:
        statusColor = Colors.orange;
        statusIcon = Icons.error;
        break;
      case RecordingStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job.contentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  job.statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isActive) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: job.progress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Text(
                  isActive
                      ? '${job.recordedDurationText} / ${job.targetDurationText}'
                      : 'Duration: ${job.recordedDurationText}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (job.errorMessage != null)
                  Tooltip(
                    message: job.errorMessage!,
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ),
                if (!isActive)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _deleteRecording(context, job),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRecording(BuildContext context, RecordingJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: Text('Delete "${job.contentName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _recordingService.deleteRecording(job.id);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Recordings?'),
        content: const Text('Delete all completed recordings? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _recordingService.clearCompletedRecordings();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
