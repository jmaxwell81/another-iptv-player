import 'package:flutter/material.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/service_locator.dart';

class PlaylistStats {
  final int liveStreams;
  final int movies;
  final int series;
  final DateTime? lastRefresh;

  PlaylistStats({
    required this.liveStreams,
    required this.movies,
    required this.series,
    this.lastRefresh,
  });

  int get total => liveStreams + movies + series;
}

class PlaylistRefreshWidget extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback? onRefreshPressed;

  const PlaylistRefreshWidget({
    super.key,
    required this.playlist,
    this.onRefreshPressed,
  });

  @override
  State<PlaylistRefreshWidget> createState() => _PlaylistRefreshWidgetState();
}

class _PlaylistRefreshWidgetState extends State<PlaylistRefreshWidget> {
  final _database = getIt<AppDatabase>();
  PlaylistStats? _stats;
  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  bool _autoRefreshEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadAutoRefreshSettings();
  }

  Future<void> _loadAutoRefreshSettings() async {
    final enabled = await UserPreferences.getAutoRefreshEnabled();
    final lastRefresh = await UserPreferences.getLastRefreshTime(widget.playlist.id);
    if (mounted) {
      setState(() {
        _autoRefreshEnabled = enabled;
        _lastRefreshTime = lastRefresh;
      });
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      final playlistId = widget.playlist.id;

      int liveCount = 0;
      int moviesCount = 0;
      int seriesCount = 0;

      if (widget.playlist.type == PlaylistType.xtream) {
        // Get counts from database for Xtream playlist
        liveCount = await _database.getLiveStreamCount(playlistId);
        moviesCount = await _database.getVodStreamCount(playlistId);
        seriesCount = await _database.getSeriesCount(playlistId);
      } else {
        // Get counts for M3U playlist
        liveCount = await _database.getM3uLiveCount(playlistId);
        moviesCount = await _database.getM3uMoviesCount(playlistId);
        seriesCount = await _database.getM3uSeriesCount(playlistId);
      }

      final lastRefresh = await UserPreferences.getLastRefreshTime(playlistId);

      if (mounted) {
        setState(() {
          _stats = PlaylistStats(
            liveStreams: liveCount,
            movies: moviesCount,
            series: seriesCount,
            lastRefresh: lastRefresh,
          );
          _lastRefreshTime = lastRefresh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stats = PlaylistStats(liveStreams: 0, movies: 0, series: 0);
          _isLoading = false;
        });
      }
    }
  }

  void _onRefresh() {
    setState(() => _isRefreshing = true);
    // Save refresh time
    UserPreferences.setLastRefreshTime(widget.playlist.id, DateTime.now());
    widget.onRefreshPressed?.call();
  }

  Future<void> _toggleAutoRefresh(bool value) async {
    await UserPreferences.setAutoRefreshEnabled(value);
    setState(() => _autoRefreshEnabled = value);
  }

  String _formatLastRefresh(DateTime? time) {
    if (time == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with refresh button
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Content Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isRefreshing ? null : _onRefresh,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_isRefreshing ? 'Refreshing...' : 'Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Stats grid
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_stats != null)
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.live_tv,
                      label: 'Live',
                      count: _stats!.liveStreams,
                      color: Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.movie,
                      label: 'Movies',
                      count: _stats!.movies,
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.tv,
                      label: 'Series',
                      count: _stats!.series,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

            // Total count and last refresh
            if (_stats != null && !_isLoading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_add_check,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Total: ${_formatNumber(_stats!.total)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatLastRefresh(_lastRefreshTime),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Auto-refresh toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.autorenew,
                      size: 20,
                      color: _autoRefreshEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Auto-refresh on startup',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Switch(
                      value: _autoRefreshEnabled,
                      onChanged: _toggleAutoRefresh,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          _formatNumber(count),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
