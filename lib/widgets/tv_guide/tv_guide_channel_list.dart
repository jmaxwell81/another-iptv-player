import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/tv_guide_channel.dart';

class TvGuideChannelList extends StatelessWidget {
  final List<TvGuideChannel> channels;
  final double channelHeight;
  final double channelColumnWidth;
  final ScrollController scrollController;
  final void Function(TvGuideChannel)? onChannelTap;

  const TvGuideChannelList({
    super.key,
    required this.channels,
    required this.scrollController,
    this.channelHeight = 60,
    this.channelColumnWidth = 150,
    this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: channelColumnWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: ListView.builder(
        controller: scrollController,
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return _ChannelRow(
            channel: channel,
            height: channelHeight,
            onTap: onChannelTap != null ? () => onChannelTap!(channel) : null,
          );
        },
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final TvGuideChannel channel;
  final double height;
  final VoidCallback? onTap;

  const _ChannelRow({
    required this.channel,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Channel icon
            _buildChannelIcon(theme),
            const SizedBox(width: 8),
            // Channel info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.currentProgram != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      channel.currentProgram!.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // EPG indicator
            if (channel.hasEpgData)
              Icon(
                Icons.calendar_today,
                size: 12,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelIcon(ThemeData theme) {
    if (channel.icon != null && channel.icon!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: channel.icon!,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            width: 32,
            height: 32,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.tv, size: 16),
          ),
          errorWidget: (context, url, error) => Container(
            width: 32,
            height: 32,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.tv,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.tv,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
