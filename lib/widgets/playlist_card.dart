import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:flutter/material.dart';
import '../../../../models/playlist_model.dart';
import '../../utils/playlist_utils.dart';

class PlaylistCard extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onRefresh;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onDelete,
    this.onEdit,
    this.onRefresh,
  });

  @override
  State<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<PlaylistCard> {
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _loadLastRefreshTime();
  }

  Future<void> _loadLastRefreshTime() async {
    final time = await UserPreferences.getLastRefreshTime(widget.playlist.id);
    if (mounted) {
      setState(() {
        _lastRefreshTime = time;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppThemes.surfaceGrey,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _PlaylistIcon(type: widget.playlist.type),
              const SizedBox(width: 16),
              Expanded(
                child: _PlaylistInfo(
                  playlist: widget.playlist,
                  lastRefreshTime: _lastRefreshTime,
                ),
              ),
              _PlaylistMenu(
                onDelete: widget.onDelete,
                onEdit: widget.onEdit,
                onRefresh: widget.onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistIcon extends StatelessWidget {
  final PlaylistType type;

  const _PlaylistIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: PlaylistUtils.getPlaylistColor(type),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Icon(
        PlaylistUtils.getPlaylistIcon(type),
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _PlaylistInfo extends StatelessWidget {
  final Playlist playlist;
  final DateTime? lastRefreshTime;

  const _PlaylistInfo({required this.playlist, this.lastRefreshTime});

  String _formatLastRefresh(DateTime? time) {
    if (time == null) return 'Never refreshed';

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return PlaylistUtils.formatDate(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          playlist.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppThemes.textWhite,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _TypeChip(type: playlist.type),
            const SizedBox(width: 8),
            const Icon(Icons.access_time, size: 12, color: AppThemes.iconGrey),
            const SizedBox(width: 4),
            Text(
              PlaylistUtils.formatDate(playlist.createdAt),
              style: const TextStyle(fontSize: 12, color: AppThemes.textGrey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.sync,
              size: 12,
              color: lastRefreshTime == null ? Colors.orange : AppThemes.iconGrey,
            ),
            const SizedBox(width: 4),
            Text(
              _formatLastRefresh(lastRefreshTime),
              style: TextStyle(
                fontSize: 11,
                color: lastRefreshTime == null ? Colors.orange : AppThemes.textGrey,
              ),
            ),
          ],
        ),
        if (playlist.url != null) ...[
          const SizedBox(height: 4),
          Text(
            playlist.url!,
            style: const TextStyle(fontSize: 11, color: AppThemes.iconGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final PlaylistType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = PlaylistUtils.getPlaylistColor(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _PlaylistMenu extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onRefresh;

  const _PlaylistMenu({required this.onDelete, this.onEdit, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      itemBuilder: (context) => [
        if (onRefresh != null)
          PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.sync, color: Theme.of(context).colorScheme.primary, size: 20),
                SizedBox(width: 8),
                Text('Refresh'),
              ],
            ),
          ),
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 20),
                SizedBox(width: 8),
                Text(context.loc.edit),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(context.loc.delete, style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'refresh') {
          onRefresh?.call();
        } else if (value == 'edit') {
          onEdit?.call();
        } else if (value == 'delete') {
          onDelete();
        }
      },
    );
  }
}
