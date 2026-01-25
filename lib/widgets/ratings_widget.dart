import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/omdb_service.dart';
import 'package:another_iptv_player/services/service_locator.dart';

/// Widget that displays IMDB and Rotten Tomatoes ratings
class RatingsWidget extends StatefulWidget {
  final String? imdbId;
  final String? title;
  final int? year;

  const RatingsWidget({
    super.key,
    this.imdbId,
    this.title,
    this.year,
  });

  @override
  State<RatingsWidget> createState() => _RatingsWidgetState();
}

class _RatingsWidgetState extends State<RatingsWidget> {
  final OmdbService _omdbService = getIt<OmdbService>();
  OmdbDetails? _omdbDetails;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    if (!_omdbService.isConfigured) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      OmdbDetails? details;

      // Try to fetch by IMDB ID first (most accurate)
      if (widget.imdbId != null && widget.imdbId!.isNotEmpty) {
        details = await _omdbService.getDetailsByImdbId(widget.imdbId!);
      }

      // If not found by IMDB ID, try by title
      if (details == null && widget.title != null && widget.title!.isNotEmpty) {
        details = await _omdbService.getDetailsByTitle(
          widget.title!,
          year: widget.year,
        );
      }

      if (mounted) {
        setState(() {
          _omdbDetails = details;
          _isLoading = false;
          _hasError = details == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_omdbService.isConfigured) {
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

    if (_hasError || _omdbDetails == null) {
      return const SizedBox.shrink();
    }

    final imdbRating = _omdbDetails!.imdbRating;
    final rtScore = _omdbDetails!.rottenTomatoesScore;
    final metascore = _omdbDetails!.metascore;

    // Don't show widget if no ratings available
    if ((imdbRating == null || imdbRating == 'N/A') &&
        (rtScore == null) &&
        (metascore == null || metascore == 'N/A')) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.yellow.shade700.withOpacity(0.15),
            Colors.red.shade700.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // IMDB Rating
          if (imdbRating != null && imdbRating != 'N/A')
            Expanded(
              child: _buildRatingCard(
                context,
                logo: 'IMDB',
                logoColor: const Color(0xFFF5C518),
                rating: imdbRating,
                maxRating: '/10',
                icon: Icons.star_rounded,
              ),
            ),

          // Rotten Tomatoes Score
          if (rtScore != null) ...[
            if (imdbRating != null && imdbRating != 'N/A')
              const SizedBox(width: 12),
            Expanded(
              child: _buildRatingCard(
                context,
                logo: 'RT',
                logoColor: const Color(0xFFFA320A),
                rating: rtScore,
                maxRating: '',
                icon: _getRottenTomatoesIcon(rtScore),
              ),
            ),
          ],

          // Metacritic Score
          if (metascore != null && metascore != 'N/A') ...[
            if ((imdbRating != null && imdbRating != 'N/A') || rtScore != null)
              const SizedBox(width: 12),
            Expanded(
              child: _buildRatingCard(
                context,
                logo: 'MC',
                logoColor: _getMetacriticColor(metascore),
                rating: metascore,
                maxRating: '/100',
                icon: Icons.rate_review_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingCard(
    BuildContext context, {
    required String logo,
    required Color logoColor,
    required String rating,
    required String maxRating,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: logoColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: logoColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              logo,
              style: TextStyle(
                color: logoColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Icon and Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: logoColor, size: 20),
              const SizedBox(width: 6),
              Text(
                rating,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              if (maxRating.isNotEmpty)
                Text(
                  maxRating,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getRottenTomatoesIcon(String score) {
    // Extract percentage from score like "85%"
    final percentStr = score.replaceAll('%', '').trim();
    final percent = int.tryParse(percentStr) ?? 0;

    // Fresh (60%+) vs Rotten (<60%)
    if (percent >= 60) {
      return Icons.local_florist; // Fresh tomato
    } else {
      return Icons.clear; // Rotten tomato
    }
  }

  Color _getMetacriticColor(String score) {
    final scoreInt = int.tryParse(score) ?? 0;

    // Metacritic color scheme
    if (scoreInt >= 61) {
      return const Color(0xFF66CC33); // Green - Generally favorable
    } else if (scoreInt >= 40) {
      return const Color(0xFFFFCC33); // Yellow - Mixed or average
    } else {
      return const Color(0xFFFF0000); // Red - Generally unfavorable
    }
  }
}

/// Compact rating badge for list items
class CompactRatingBadge extends StatelessWidget {
  final String rating;
  final String source; // 'imdb', 'rt', 'mc'

  const CompactRatingBadge({
    super.key,
    required this.rating,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (source.toLowerCase()) {
      case 'imdb':
        color = const Color(0xFFF5C518);
        label = rating;
        icon = Icons.star_rounded;
        break;
      case 'rt':
        color = const Color(0xFFFA320A);
        label = rating;
        icon = Icons.local_florist;
        break;
      case 'mc':
        color = _getMetacriticColor(rating);
        label = rating;
        icon = Icons.rate_review_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMetacriticColor(String score) {
    final scoreInt = int.tryParse(score.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (scoreInt >= 61) {
      return const Color(0xFF66CC33);
    } else if (scoreInt >= 40) {
      return const Color(0xFFFFCC33);
    } else {
      return const Color(0xFFFF0000);
    }
  }
}
