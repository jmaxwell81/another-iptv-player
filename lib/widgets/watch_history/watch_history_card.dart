import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';

class WatchHistoryCard extends StatelessWidget {
  final WatchHistory history;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showProgress;

  const WatchHistoryCard({
    super.key,
    required this.history,
    required this.width,
    required this.height,
    this.onTap,
    this.onRemove,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Background/Thumbnail
              _buildThumbnail(),

              // Remove Button
              if (onRemove != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),

              // Progress percentage badge (if applicable)
              if (showProgress &&
                  history.watchDuration != null &&
                  history.totalDuration != null &&
                  history.totalDuration!.inMilliseconds > 0)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildProgressBadge(),
                  ),
                ),

              // Content Info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        history.title.applyRenamingRules(
                          contentType: history.contentType,
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (history.imagePath != null && history.imagePath!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: history.imagePath!,
        width: double.infinity,
        height: double.infinity,
        fit: _getFitForContentType(),
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _buildDefaultThumbnail(),
      );
    } else {
      return _buildDefaultThumbnail();
    }
  }

  BoxFit _getFitForContentType() {
    // Canlı yayınlar için contain kullan (logolar için)
    if (history.contentType == ContentType.liveStream) {
      return BoxFit.contain;
    }
    // Film ve diziler için cover kullan (posterler için)
    return BoxFit.cover;
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getContentTypeColor(history.contentType).withOpacity(0.8),
            _getContentTypeColor(history.contentType),
          ],
        ),
      ),
      child: Icon(
        _getContentTypeIcon(history.contentType),
        size: 48,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProgressBadge() {
    // For series, show episode progress
    if (history.contentType == ContentType.series &&
        history.seasonNumber != null &&
        history.episodeNumber != null) {
      final episodeText = history.totalEpisodes != null
          ? 'S${history.seasonNumber} E${history.episodeNumber}/${history.totalEpisodes}'
          : 'S${history.seasonNumber} E${history.episodeNumber}';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          episodeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // For movies, show percentage watched
    final progress = history.totalDuration!.inMilliseconds.isInfinite
        ? 0.0
        : (history.watchDuration!.inMilliseconds /
              history.totalDuration!.inMilliseconds);

    final percentage = ((progress.isInfinite || progress.isNaN ? 0 : progress) * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$percentage%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getContentTypeColor(ContentType type) {
    switch (type) {
      case ContentType.liveStream:
        return Colors.red;
      case ContentType.vod:
        return Colors.blue;
      case ContentType.series:
        return Colors.green;
    }
  }

  IconData _getContentTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.liveStream:
        return Icons.live_tv;
      case ContentType.vod:
        return Icons.movie;
      case ContentType.series:
        return Icons.tv;
    }
  }

  String _getContentTypeText(ContentType type) {
    switch (type) {
      case ContentType.liveStream:
        return 'CANLI';
      case ContentType.vod:
        return 'FİLM';
      case ContentType.series:
        return 'DİZİ';
    }
  }

  String _formatLastWatched(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}g önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}s önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}dk önce';
    } else {
      return 'Az önce';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }
}
