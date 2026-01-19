import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:intl/intl.dart';

class TvGuideProgramCell extends StatelessWidget {
  final EpgProgram program;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const TvGuideProgramCell({
    super.key,
    required this.program,
    required this.width,
    this.height = 60,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = program.isLive;
    final isPast = program.isPast;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap ?? () => _showProgramDetails(context),
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isLive
              ? theme.colorScheme.primaryContainer
              : isPast
                  ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: isLive
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Progress indicator for live programs
            if (isLive)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: width * program.progress,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    program.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isLive ? FontWeight.bold : FontWeight.normal,
                      color: isPast
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (width > 100) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeRange(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            // Live badge
            if (isLive)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'LIVE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRange() {
    final startFormat = DateFormat.Hm();
    final endFormat = DateFormat.Hm();
    return '${startFormat.format(program.startTime)} - ${endFormat.format(program.endTime)}';
  }

  void _showProgramDetails(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      program.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (program.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LIVE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Time
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeRange(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Progress for live programs
              if (program.isLive) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: program.progress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDurationRemaining()} remaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // Category
              if (program.category != null) ...[
                const SizedBox(height: 12),
                Chip(
                  label: Text(program.category!),
                  labelStyle: theme.textTheme.labelSmall,
                ),
              ],
              // Description
              if (program.description != null && program.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  program.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration() {
    final duration = program.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDurationRemaining() {
    final remaining = program.remainingTime;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
