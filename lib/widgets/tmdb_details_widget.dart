import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/services/tmdb_service.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';

/// Widget that displays enhanced TMDB details like cast, similar content, etc.
class TmdbDetailsWidget extends StatefulWidget {
  final String contentId;
  final String playlistId;
  final String contentType; // 'vod' or 'series'
  final String title;
  final String? imdbId;
  final int? year;
  final Function(int tmdbId, String title, String? posterPath)? onSimilarTapped;

  const TmdbDetailsWidget({
    super.key,
    required this.contentId,
    required this.playlistId,
    required this.contentType,
    required this.title,
    this.imdbId,
    this.year,
    this.onSimilarTapped,
  });

  @override
  State<TmdbDetailsWidget> createState() => _TmdbDetailsWidgetState();
}

class _TmdbDetailsWidgetState extends State<TmdbDetailsWidget> {
  final TmdbService _tmdbService = getIt<TmdbService>();

  ContentDetailsData? _details;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (!_tmdbService.isConfigured) {
      setState(() {
        _isLoading = false;
        _error = null; // Don't show error, just don't display TMDB data
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await _tmdbService.fetchAndCacheDetails(
        contentId: widget.contentId,
        playlistId: widget.playlistId,
        contentType: widget.contentType,
        title: widget.title,
        imdbId: widget.imdbId,
        year: widget.year,
      );

      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_tmdbService.isConfigured) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_details == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TMDB Rating
        if (_details!.voteAverage != null && _details!.voteAverage! > 0) ...[
          _buildTmdbRating(context),
          const SizedBox(height: 24),
        ],

        // Cast section with photos
        if (_details!.cast != null && _details!.cast!.isNotEmpty) ...[
          _buildCastSection(context),
          const SizedBox(height: 24),
        ],

        // Similar content
        if (_details!.similarContent != null && _details!.similarContent!.isNotEmpty) ...[
          _buildSimilarSection(context),
          const SizedBox(height: 24),
        ],

        // Keywords/Tags
        if (_details!.keywords != null && _details!.keywords!.isNotEmpty) ...[
          _buildKeywordsSection(context),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildTmdbRating(BuildContext context) {
    final rating = _details!.voteAverage!;
    final voteCount = _details!.voteCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.15),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // TMDB Logo/Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF01D277).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'TMDB',
              style: TextStyle(
                color: Color(0xFF01D277),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Rating display
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber.shade500, size: 28),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/10',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Vote count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatVoteCount(voteCount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                context.loc.votes,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCastSection(BuildContext context) {
    List<dynamic> castList = [];
    try {
      castList = jsonDecode(_details!.cast!);
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (castList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.cast,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : null,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: castList.length,
            itemBuilder: (context, index) {
              final cast = castList[index];
              return _buildCastCard(
                context,
                name: cast['name'] ?? '',
                character: cast['character'],
                profilePath: cast['profile'],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCastCard(
    BuildContext context, {
    required String name,
    String? character,
    String? profilePath,
  }) {
    final imageUrl = profilePath != null
        ? TmdbService.getProfileUrl(profilePath)
        : null;

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          // Profile image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.person, color: Colors.grey, size: 40),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.person, color: Colors.grey, size: 40),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.person, color: Colors.grey, size: 40),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          // Character name
          if (character != null && character.isNotEmpty)
            Text(
              character,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSimilarSection(BuildContext context) {
    List<dynamic> similarIds = [];
    try {
      similarIds = jsonDecode(_details!.similarContent!);
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (similarIds.isEmpty) return const SizedBox.shrink();

    // For now, just show that similar content is available
    // In a full implementation, we'd fetch details for these IDs
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.loc.similar_content,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : null,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${similarIds.length}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.movie_filter,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.loc.similar_content_available(similarIds.length.toString()),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordsSection(BuildContext context) {
    List<dynamic> keywords = [];
    try {
      keywords = jsonDecode(_details!.keywords!);
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (keywords.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.keywords,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: keywords.take(10).map<Widget>((keyword) {
            final keywordStr = keyword is String ? keyword : keyword.toString();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Text(
                keywordStr,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// Compact TMDB rating widget for use in list items
class TmdbRatingBadge extends StatelessWidget {
  final double rating;
  final int? voteCount;
  final bool compact;

  const TmdbRatingBadge({
    super.key,
    required this.rating,
    this.voteCount,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF01D277).withOpacity(0.2),
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: Colors.amber,
            size: compact ? 12 : 14,
          ),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: const Color(0xFF01D277),
              fontWeight: FontWeight.bold,
              fontSize: compact ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
