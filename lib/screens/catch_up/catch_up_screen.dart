import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:another_iptv_player/models/catch_up.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/catch_up_service.dart';
import 'package:another_iptv_player/screens/live_stream/live_stream_screen.dart';

class CatchUpScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final String playlistId;
  final String? channelIcon;

  const CatchUpScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.playlistId,
    this.channelIcon,
  });

  @override
  State<CatchUpScreen> createState() => _CatchUpScreenState();
}

class _CatchUpScreenState extends State<CatchUpScreen> {
  final CatchUpService _service = CatchUpService();
  int _selectedDays = 3;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  void _loadPrograms() {
    _service.getCatchUpPrograms(
      channelId: widget.channelId,
      playlistId: widget.playlistId,
      daysBack: _selectedDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Catch Up'),
              Text(
                widget.channelName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            // Days filter
            PopupMenuButton<int>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter days',
              onSelected: (days) {
                setState(() {
                  _selectedDays = days;
                });
                _loadPrograms();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 1, child: Text('Last 24 hours')),
                const PopupMenuItem(value: 3, child: Text('Last 3 days')),
                const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              ],
            ),
            // Refresh
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPrograms,
            ),
          ],
        ),
        body: Consumer<CatchUpService>(
          builder: (context, service, child) {
            if (service.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (service.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(service.errorMessage!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadPrograms,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (service.programs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text('No catch up content available'),
                    const SizedBox(height: 8),
                    Text(
                      'This channel may not support catch up\nor there is no EPG data',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }

            final programsByDate = service.getProgramsByDate();

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: programsByDate.length,
              itemBuilder: (context, index) {
                final date = programsByDate.keys.elementAt(index);
                final programs = programsByDate[date]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Text(
                        date,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...programs.map((program) => _buildProgramCard(context, program)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgramCard(BuildContext context, CatchUpProgram program) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.Hm();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _playProgram(context, program),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 60,
                  child: program.icon != null && program.icon!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: program.icon!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.tv),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: widget.channelIcon != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.channelIcon!,
                                  fit: BoxFit.contain,
                                )
                              : const Icon(Icons.tv),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${timeFormat.format(program.startTime)} - ${timeFormat.format(program.endTime)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${program.duration.inMinutes} min',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    if (program.description != null && program.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        program.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Play button
              IconButton(
                icon: const Icon(Icons.play_circle_filled),
                iconSize: 36,
                color: theme.colorScheme.primary,
                onPressed: () => _playProgram(context, program),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playProgram(BuildContext context, CatchUpProgram program) {
    // Create a ContentItem for the catch up program
    // Use isCatchUp flag and overrideUrl for catch up playback with seek support
    final contentItem = ContentItem(
      program.id,
      '${program.title} (${program.timeRangeText})',
      program.icon ?? widget.channelIcon ?? '',
      ContentType.liveStream,
      sourcePlaylistId: program.playlistId,
      isCatchUp: true,
      overrideUrl: program.catchUpUrl,
    );

    // Navigate to player
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          content: contentItem,
        ),
      ),
    );
  }
}
