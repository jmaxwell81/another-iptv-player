import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/recording_job.dart';
import 'package:another_iptv_player/services/live_recording_service.dart';
import 'package:another_iptv_player/widgets/recording_status_widget.dart';

/// Section widget that displays recordings in the Recent/Watch History screen
class RecordingsSection extends StatefulWidget {
  final double cardWidth;
  final double cardHeight;

  const RecordingsSection({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  State<RecordingsSection> createState() => _RecordingsSectionState();
}

class _RecordingsSectionState extends State<RecordingsSection> {
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
    final activeJobs = _recordingService.activeJobs;
    final completedJobs = _recordingService.completedJobs;
    final allJobs = [...activeJobs, ...completedJobs];

    if (allJobs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Recordings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (activeJobs.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activeJobs.length} active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (allJobs.length > 5)
                TextButton(
                  onPressed: () => _openRecordingsManager(context),
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: widget.cardHeight + 16,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: allJobs.length > 10 ? 10 : allJobs.length,
            itemBuilder: (context, index) {
              final job = allJobs[index];
              return _RecordingCard(
                job: job,
                width: widget.cardWidth,
                height: widget.cardHeight,
                onTap: () => _onRecordingTap(context, job),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _openRecordingsManager(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordingsManagerWidget(),
      ),
    );
  }

  void _onRecordingTap(BuildContext context, RecordingJob job) {
    if (job.isActive) {
      // Show active recording dialog with stop/extend options
      _showActiveRecordingDialog(context, job);
    } else {
      // Show completed recording options (play, delete)
      _showCompletedRecordingDialog(context, job);
    }
  }

  void _showActiveRecordingDialog(BuildContext context, RecordingJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Recording in Progress'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.contentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: job.progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            const SizedBox(height: 8),
            Text('${job.recordedDurationText} / ${job.targetDurationText}'),
            Text(
              '${job.remainingDurationText} remaining',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showExtendDialog(context, job);
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Extend'),
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
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  void _showExtendDialog(BuildContext context, RecordingJob job) {
    int selectedMinutes = 30;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Extend Recording'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add more time to "${job.contentName}"'),
              const SizedBox(height: 16),
              const Text('Add:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [15, 30, 60, 90].map((minutes) {
                  return ChoiceChip(
                    label: Text('$minutes min'),
                    selected: selectedMinutes == minutes,
                    onSelected: (selected) {
                      if (selected) {
                        setDialogState(() => selectedMinutes = minutes);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await _recordingService.extendRecording(
                  job.id,
                  Duration(minutes: selectedMinutes),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Recording extended by $selectedMinutes minutes')),
                  );
                }
              },
              child: const Text('Extend'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletedRecordingDialog(BuildContext context, RecordingJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              job.status == RecordingStatus.completed
                  ? Icons.check_circle
                  : job.status == RecordingStatus.failed
                      ? Icons.error
                      : Icons.cancel,
              color: job.status == RecordingStatus.completed
                  ? Colors.green
                  : job.status == RecordingStatus.failed
                      ? Colors.orange
                      : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(job.statusText),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.contentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Duration: ${job.recordedDurationText}'),
            if (job.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                job.errorMessage!,
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDelete(context, job);
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, RecordingJob job) {
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
}

/// Card widget for displaying a recording in the horizontal list
class _RecordingCard extends StatelessWidget {
  final RecordingJob job;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _RecordingCard({
    required this.job,
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = job.isActive;

    Color statusColor;
    IconData statusIcon;
    switch (job.status) {
      case RecordingStatus.recording:
      case RecordingStatus.pending:
        statusColor = Colors.red;
        statusIcon = Icons.fiber_manual_record;
        break;
      case RecordingStatus.paused:
        statusColor = Colors.amber;
        statusIcon = Icons.pause_circle;
        break;
      case RecordingStatus.completing:
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_bottom;
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
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Colors.red, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            // Background with recording icon
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withOpacity(0.2),
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.videocam,
                    size: 48,
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
              ),
            ),

            // Status badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'REC' : job.statusText.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Progress bar (for active recordings)
            if (isActive)
              Positioned(
                bottom: 48,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: job.progress,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${job.recordedDurationText} / ${job.targetDurationText}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

            // Content name
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.contentName,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isActive)
                    Text(
                      job.recordedDurationText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
