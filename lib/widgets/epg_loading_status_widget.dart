import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/epg_fetch_status.dart';

/// Widget to display EPG loading progress with detailed status
class EpgLoadingStatusWidget extends StatelessWidget {
  final EpgFetchProgress progress;
  final VoidCallback? onCancel;

  const EpgLoadingStatusWidget({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = progress.currentSource;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and cancel button
          Row(
            children: [
              Icon(
                Icons.downloading,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Downloading EPG Data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Skip/Cancel button
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Skip'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Source counter
          Text(
            progress.statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),

          // Source name
          if (source != null) ...[
            Text(
              source.playlistName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: source.progress > 0 ? source.progress : null,
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),

            // Progress details row
            Row(
              children: [
                // State indicator
                _buildStateChip(context, source.state),
                const Spacer(),

                // Percentage
                if (source.progress > 0)
                  Text(
                    source.progressPercentage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                // ETA
                if (source.estimatedRemaining != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '~${_formatDuration(source.estimatedRemaining!)} left',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],

                // Bytes downloaded
                if (source.totalBytes != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${_formatBytes(source.bytesDownloaded)} / ${_formatBytes(source.totalBytes!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ] else if (source.bytesDownloaded > 0) ...[
                  const SizedBox(width: 12),
                  Text(
                    _formatBytes(source.bytesDownloaded),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Completed sources summary
          if (progress.completedSources.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCompletedSummary(context),
          ],
        ],
      ),
    );
  }

  Widget _buildStateChip(BuildContext context, EpgFetchState state) {
    final theme = Theme.of(context);

    Color chipColor;
    IconData? icon;

    switch (state) {
      case EpgFetchState.checking:
        chipColor = theme.colorScheme.tertiary;
        icon = Icons.search;
        break;
      case EpgFetchState.downloading:
        chipColor = theme.colorScheme.primary;
        icon = Icons.cloud_download;
        break;
      case EpgFetchState.parsing:
        chipColor = theme.colorScheme.secondary;
        icon = Icons.data_array;
        break;
      case EpgFetchState.storing:
        chipColor = theme.colorScheme.secondary;
        icon = Icons.storage;
        break;
      case EpgFetchState.completed:
        chipColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case EpgFetchState.failed:
        chipColor = theme.colorScheme.error;
        icon = Icons.error;
        break;
      case EpgFetchState.skipped:
        chipColor = theme.colorScheme.outline;
        icon = Icons.skip_next;
        break;
      case EpgFetchState.cancelled:
        chipColor = theme.colorScheme.outline;
        icon = Icons.cancel;
        break;
      case EpgFetchState.idle:
        chipColor = theme.colorScheme.outline;
        icon = Icons.hourglass_empty;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: chipColor),
            const SizedBox(width: 4),
          ],
          Text(
            state.name.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSummary(BuildContext context) {
    final theme = Theme.of(context);
    final completed = progress.completedSources;

    final successCount = completed.where((s) => s.state == EpgFetchState.completed).length;
    final failedCount = completed.where((s) => s.state == EpgFetchState.failed).length;
    final skippedCount = completed.where((s) => s.state == EpgFetchState.skipped).length;

    return Row(
      children: [
        Text(
          'Completed: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (successCount > 0) ...[
          Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 2),
          Text(
            '$successCount',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
          ),
          const SizedBox(width: 8),
        ],
        if (skippedCount > 0) ...[
          Icon(Icons.skip_next, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 2),
          Text(
            '$skippedCount skipped',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (failedCount > 0) ...[
          Icon(Icons.error, size: 14, color: theme.colorScheme.error),
          const SizedBox(width: 2),
          Text(
            '$failedCount failed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// Compact version of the EPG loading status for app bar
class EpgLoadingStatusCompact extends StatelessWidget {
  final EpgFetchProgress progress;
  final VoidCallback? onCancel;

  const EpgLoadingStatusCompact({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = progress.currentSource;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: source != null && source.progress > 0
                ? source.progress
                : null,
          ),
        ),
        const SizedBox(width: 8),
        // Status text
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              progress.statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (source != null)
              Text(
                '${source.stateDescription} ${source.progress > 0 ? source.progressPercentage : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        // Skip button
        if (onCancel != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.skip_next, size: 18),
            onPressed: onCancel,
            tooltip: 'Skip current source',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ],
    );
  }
}
