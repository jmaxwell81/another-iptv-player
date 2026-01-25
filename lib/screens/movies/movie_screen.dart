import 'dart:ui';

import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/consolidated_content_item.dart';
import 'package:another_iptv_player/models/content_source_link.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/repositories/favorites_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/widgets/source_selection_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../widgets/player_widget.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';
import 'package:another_iptv_player/widgets/tmdb_details_widget.dart';
import 'package:another_iptv_player/widgets/ratings_widget.dart';

class MovieScreen extends StatefulWidget {
  final ContentItem contentItem;

  /// Optional consolidated item for multi-source content
  final ConsolidatedContentItem? consolidatedItem;

  const MovieScreen({
    super.key,
    required this.contentItem,
    this.consolidatedItem,
  });

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  late final WatchHistoryService _watchHistoryService;
  late final IptvRepository? _repository;
  late final FavoritesRepository _favoritesRepository;

  WatchHistory? _watchHistory;
  Map<String, dynamic>? _vodInfo;
  bool _isLoadingHistory = true;
  bool _isLoadingVodInfo = true;
  List<ContentItem> _categoryMovies = [];
  bool _isFavorite = false;

  /// Currently selected source for multi-source content
  ContentSourceLink? _selectedSource;

  /// The actual content item to use for playback (may change when source changes)
  late ContentItem _activeContentItem;

  // Helper to determine if this is Xtream content
  bool get _contentIsXtream =>
      widget.contentItem.sourceType == PlaylistType.xtream ||
      (widget.contentItem.sourceType == null &&
          AppState.currentPlaylist?.type == PlaylistType.xtream);

  // Helper to determine if this is M3U content
  bool get _contentIsM3u =>
      widget.contentItem.sourceType == PlaylistType.m3u ||
      (widget.contentItem.sourceType == null &&
          AppState.currentPlaylist?.type == PlaylistType.m3u);

  // Helper to get playlist ID
  String get _playlistId =>
      widget.contentItem.sourcePlaylistId ??
      AppState.currentPlaylist?.id ??
      'unknown';

  // Helper to get display name with renaming rules applied
  String get _displayName => widget.contentItem.name.applyRenamingRules(
        contentType: widget.contentItem.contentType,
        itemId: widget.contentItem.id,
        playlistId: _playlistId,
      );

  /// Whether this item has multiple sources available
  bool get _hasMultipleSources =>
      widget.consolidatedItem != null &&
      widget.consolidatedItem!.hasMultipleSources;

  /// Get available sources
  List<ContentSourceLink> get _availableSources =>
      widget.consolidatedItem?.sourceLinks ?? [];

  @override
  void initState() {
    super.initState();
    _watchHistoryService = WatchHistoryService();
    _favoritesRepository = FavoritesRepository();

    // Initialize active content item and selected source
    _activeContentItem = widget.contentItem;
    if (widget.consolidatedItem != null) {
      _selectedSource = widget.consolidatedItem!.preferredSource;
      if (_selectedSource != null) {
        _activeContentItem = widget.consolidatedItem!.toContentItemWithSource(_selectedSource!);
      }
    }

    // Determine if this is Xtream content and get the right repository
    final sourcePlaylistId = widget.contentItem.sourcePlaylistId;
    final contentIsXtream = widget.contentItem.sourceType == PlaylistType.xtream ||
        (widget.contentItem.sourceType == null &&
            AppState.currentPlaylist?.type == PlaylistType.xtream);

    if (contentIsXtream) {
      // Try to get repository from xtreamRepositories (combined mode) or create new one
      if (sourcePlaylistId != null && AppState.xtreamRepositories.containsKey(sourcePlaylistId)) {
        _repository = AppState.xtreamRepositories[sourcePlaylistId];
      } else if (AppState.currentPlaylist != null &&
          AppState.currentPlaylist!.type == PlaylistType.xtream) {
        _repository = IptvRepository(
          ApiConfig(
            baseUrl: AppState.currentPlaylist!.url!,
            username: AppState.currentPlaylist!.username!,
            password: AppState.currentPlaylist!.password!,
          ),
          AppState.currentPlaylist!.id,
        );
      } else {
        _repository = null;
      }
    } else {
      _repository = null;
    }

    _loadWatchHistory();
    _loadVodInfo();
    _loadCategoryMovies();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final isFav = await _favoritesRepository.isFavorite(
        widget.contentItem.id,
        widget.contentItem.contentType,
      );
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  /// Handle source selection change
  void _onSourceSelected(ContentSourceLink source) {
    if (source == _selectedSource) return;

    setState(() {
      _selectedSource = source;
      if (widget.consolidatedItem != null) {
        _activeContentItem = widget.consolidatedItem!.toContentItemWithSource(source);
      }
    });

    // Optionally reload VOD info from new source
    _loadVodInfo();
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        await _favoritesRepository.removeFavorite(
          widget.contentItem.id,
          widget.contentItem.contentType,
        );
        if (mounted) {
          setState(() {
            _isFavorite = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.removed_from_favorites)),
          );
        }
      } else {
        final now = DateTime.now();
        // Use sourcePlaylistId from content item or fallback to currentPlaylist
        final playlistId = widget.contentItem.sourcePlaylistId ??
            AppState.currentPlaylist?.id ??
            'unknown';
        final favorite = Favorite(
          id: const Uuid().v4(),
          playlistId: playlistId,
          contentType: widget.contentItem.contentType,
          streamId: widget.contentItem.id,
          name: widget.contentItem.name,
          imagePath: widget.contentItem.imagePath,
          createdAt: now,
          updatedAt: now,
        );
        await _favoritesRepository.addFavoriteFromData(favorite);
        if (mounted) {
          setState(() {
            _isFavorite = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.added_to_favorites)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadCategoryMovies() async {
    try {
      if (_contentIsXtream && _repository != null) {
        final vod = widget.contentItem.vodStream;
        final categoryId = vod?.categoryId;

        if (categoryId != null) {
          final movies = await _repository!.getMovies(categoryId: categoryId);
          if (movies != null && mounted) {
            setState(() {
              _categoryMovies = movies
                  .map((x) => ContentItem(
                        x.streamId,
                        x.name,
                        x.streamIcon,
                        ContentType.vod,
                        vodStream: x,
                        containerExtension: x.containerExtension,
                      ))
                  .toList();
            });
          }
        }
      } else if (_contentIsM3u) {
        final m3uItem = widget.contentItem.m3uItem;
        final categoryId = m3uItem?.categoryId;

        if (categoryId != null) {
          final items = await AppState.m3uRepository!.getM3uItemsByCategoryId(
            categoryId: categoryId,
            contentType: ContentType.vod,
          );
          if (items != null && mounted) {
            setState(() {
              _categoryMovies = items
                  .map((x) => ContentItem(
                        x.id,
                        x.name ?? 'NO NAME',
                        x.tvgLogo ?? '',
                        ContentType.vod,
                        m3uItem: x,
                      ))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading category movies: $e');
    }
  }

  Future<void> _loadWatchHistory() async {
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
      final streamId = _contentIsXtream
          ? widget.contentItem.id
          : widget.contentItem.m3uItem?.id ?? widget.contentItem.id;

      final history =
          await _watchHistoryService.getWatchHistory(_playlistId, streamId);

      if (!mounted) return;
      setState(() {
        _watchHistory = history;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _watchHistory = null;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadVodInfo() async {
    if (!_contentIsXtream || _repository == null) {
      if (!mounted) return;
      setState(() {
        _vodInfo = null;
        _isLoadingVodInfo = false;
      });
      return;
    }

    try {
      final info = await _repository!.getVodInfo(widget.contentItem.id);

      if (!mounted) return;
      setState(() {
        _vodInfo = info;
        _isLoadingVodInfo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vodInfo = null;
        _isLoadingVodInfo = false;
      });
    }
  }

  double? get _progress {
    final history = _watchHistory;
    if (history?.watchDuration == null || history?.totalDuration == null) {
      return null;
    }

    final total = history!.totalDuration!.inMilliseconds;
    if (total <= 0) return null;

    final value = history.watchDuration!.inMilliseconds / total;
    if (value <= 0) return null;

    return (value.clamp(0.0, 1.0)) as double;
  }

  String? get _posterUrl {
    if (_vodInfo != null) {
      final cover = _vodInfo!['cover_big'] ?? _vodInfo!['cover'];
      if (cover is String && cover.isNotEmpty) return cover;
    }
    if (widget.contentItem.coverPath?.isNotEmpty == true) {
      return widget.contentItem.coverPath;
    }
    if (widget.contentItem.imagePath.isNotEmpty) {
      return widget.contentItem.imagePath;
    }
    return widget.contentItem.vodStream?.streamIcon;
  }

  String? get _backdropUrl {
    if (_vodInfo != null) {
      final backdrop = _vodInfo!['backdrop_path'];
      if (backdrop is List && backdrop.isNotEmpty) {
        return backdrop.first.toString();
      } else if (backdrop is String && backdrop.isNotEmpty) {
        return backdrop;
      }
    }
    return null;
  }

  String? get _plotSummary {
    if (_vodInfo != null) {
      final plot = _vodInfo!['plot'];
      if (plot is String && plot.isNotEmpty) {
        return plot;
      }
    }
    return widget.contentItem.description?.trim();
  }

  String? get _directorInfo {
    if (_vodInfo != null) {
      final director = _vodInfo!['director'];
      if (director is String && director.isNotEmpty) {
        return director;
      }
    }
    return null;
  }

  String? get _castInfo {
    if (_vodInfo != null) {
      final cast = _vodInfo!['cast'];
      if (cast is String && cast.isNotEmpty) {
        return cast;
      }
    }
    return null;
  }

  int? get _duration {
    if (_vodInfo != null) {
      final duration = _vodInfo!['duration'];
      if (duration is int) {
        return duration;
      }
    }
    return widget.contentItem.duration?.inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.star : Icons.star_border,
                color: _isFavorite ? Colors.amber : Colors.white,
              ),
              onPressed: _toggleFavorite,
              tooltip: _isFavorite
                  ? context.loc.remove_from_favorites
                  : context.loc.add_to_favorites,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BACKDROP LAYER
          _buildBackdrop(),

          // 2. CONTENT LAYER
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 700;
              final topPadding =
                  MediaQuery.of(context).padding.top + kToolbarHeight + 20;

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: isDesktop ? topPadding : topPadding + 100,
                  bottom: 100,
                  left: 16,
                  right: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: isDesktop
                        ? _buildDesktopLayout(context)
                        : _buildMobileLayout(context),
                  ),
                ),
              );
            },
          ),

          // 3. PLAY BUTTON (Fixed at bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildPlayButton(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    final url = _backdropUrl ?? _posterUrl;
    if (url == null) return Container(color: Colors.black);

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: Colors.black),
        ),
        // Blur if using poster or just to dim backdrop
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _backdropUrl != null ? 5 : 15,
            sigmaY: _backdropUrl != null ? 5 : 15,
          ),
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.2),
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                Theme.of(context).scaffoldBackgroundColor,
              ],
              stops: const [0.0, 0.4, 0.8, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPoster(height: 300),
        const SizedBox(height: 24),
        _buildTitle(context, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        // IMDB and Rotten Tomatoes ratings
        RatingsWidget(
          imdbId: _extractImdbId(),
          title: _displayName,
          year: _extractYear(),
        ),
        if (_buildRatingSection(context) != null) ...[
          _buildRatingSection(context)!,
          const SizedBox(height: 16),
        ],
        if (_buildInfoChips(context) != null) ...[
          _buildInfoChips(context)!,
          const SizedBox(height: 24),
        ],
        if (_buildDescriptionSection(context) != null) ...[
          _buildDescriptionSection(context)!,
          const SizedBox(height: 24),
        ],
        if (_buildExtraDetails(context) != null) ...[
          _buildExtraDetails(context)!,
          const SizedBox(height: 24),
        ],
        // TMDB Enhanced Details
        TmdbDetailsWidget(
          contentId: widget.contentItem.id,
          playlistId: _playlistId,
          contentType: 'vod',
          title: _displayName,
          imdbId: _extractImdbId(),
          year: _extractYear(),
        ),
        // Source Selection (for multi-source content)
        if (_hasMultipleSources) ...[
          const SizedBox(height: 24),
          _buildSourceSelectionSection(context),
        ],
        if (_buildTrailerButton(context) != null) ...[
          _buildTrailerButton(context)!,
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// Build the source selection section for multi-source content
  Widget _buildSourceSelectionSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: SourceSelectionWidget(
        sources: _availableSources,
        selectedSource: _selectedSource,
        onSourceSelected: _onSourceSelected,
      ),
    );
  }

  int? _extractYear() {
    // Try to extract year from release date or vodInfo
    if (_vodInfo != null) {
      final releaseDate = _vodInfo!['releaseDate'] ?? _vodInfo!['release_date'] ?? _vodInfo!['year'];
      if (releaseDate is String && releaseDate.isNotEmpty) {
        final yearMatch = RegExp(r'(\d{4})').firstMatch(releaseDate);
        if (yearMatch != null) {
          return int.tryParse(yearMatch.group(1)!);
        }
      }
    }
    return null;
  }

  String? _extractImdbId() {
    // Try to extract IMDB ID from vodInfo if available
    if (_vodInfo != null) {
      final imdbId = _vodInfo!['imdb_id'] ?? _vodInfo!['imdb'];
      if (imdbId is String && imdbId.isNotEmpty) {
        return imdbId;
      }
    }
    return null;
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPoster(height: 450),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(context, textAlign: TextAlign.start),
              const SizedBox(height: 16),
              // IMDB and Rotten Tomatoes ratings
              RatingsWidget(
                imdbId: _extractImdbId(),
                title: _displayName,
                year: _extractYear(),
              ),
              if (_buildRatingSection(context) != null) ...[
                _buildRatingSection(context)!,
                const SizedBox(height: 16),
              ],
              if (_buildInfoChips(context) != null) ...[
                _buildInfoChips(context)!,
                const SizedBox(height: 24),
              ],
              if (_buildDescriptionSection(context) != null) ...[
                _buildDescriptionSection(context)!,
                const SizedBox(height: 24),
              ],
              if (_buildExtraDetails(context) != null) ...[
                _buildExtraDetails(context)!,
                const SizedBox(height: 24),
              ],
              // TMDB Enhanced Details
              TmdbDetailsWidget(
                contentId: widget.contentItem.id,
                playlistId: _playlistId,
                contentType: 'vod',
                title: _displayName,
                imdbId: _extractImdbId(),
                year: _extractYear(),
              ),
              // Source Selection (for multi-source content)
              if (_hasMultipleSources) ...[
                const SizedBox(height: 24),
                _buildSourceSelectionSection(context),
              ],
              if (_buildTrailerButton(context) != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildTrailerButton(context)!,
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPoster({required double height}) {
    final url = _posterUrl;
    if (url == null) return const SizedBox.shrink();

    return Container(
      height: height,
      width: height * 0.66, // Standard poster ratio
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade900,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade900,
            child: const Icon(Icons.movie, size: 50, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, {required TextAlign textAlign}) {
    return Text(
      _displayName,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(0, 2),
              ),
            ],
          ),
    );
  }

  Widget? _buildRatingSection(BuildContext context) {
    final vod = widget.contentItem.vodStream;
    if (vod == null) {
      return null;
    }

    String? label;
    final parsedRating = double.tryParse(vod.rating.trim());
    if (parsedRating != null && parsedRating > 0) {
      final formatted = parsedRating % 1 == 0
          ? parsedRating.toStringAsFixed(0)
          : parsedRating.toStringAsFixed(1);
      label = '$formatted/10';
    } else if (vod.rating5based > 0) {
      final formatted = vod.rating5based % 1 == 0
          ? vod.rating5based.toStringAsFixed(0)
          : vod.rating5based.toStringAsFixed(1);
      label = '$formatted/5';
    }

    if (label == null) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          color: Colors.amber.shade500,
          size: 28,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white, // Ensure visibility on backdrop
              ),
        ),
      ],
    );
  }

  Widget? _buildInfoChips(BuildContext context) {
    final chips = <Widget>[];

    // Süre
    if (_duration != null && _duration! > 0) {
      final durationTime = Duration(seconds: _duration!);
      chips.add(
        _InfoChip(
          icon: Icons.access_time,
          label: _formatDuration(durationTime),
        ),
      );
    }

    // Tür/Genre
    final genre = widget.contentItem.vodStream?.genre ??
        (_vodInfo != null ? _vodInfo!['genre'] : null);
    if (genre is String && genre.trim().isNotEmpty) {
      chips.add(
        _InfoChip(
          icon: Icons.local_movies,
          label: genre.trim(),
        ),
      );
    }

    // Format
    final format = (widget.contentItem.containerExtension ??
            widget.contentItem.vodStream?.containerExtension)
        ?.trim();
    if (format != null && format.isNotEmpty) {
      chips.add(
        _InfoChip(
          icon: Icons.sd_card,
          label: format.toUpperCase(),
        ),
      );
    }

    // Yayın Yılı / Released
    if (_vodInfo != null) {
      final releaseDate = _vodInfo!['releaseDate'] ??
          _vodInfo!['release_date'] ??
          _vodInfo!['year'];
      if (releaseDate is String && releaseDate.trim().isNotEmpty) {
        chips.add(
          _InfoChip(
            icon: Icons.calendar_today,
            label: releaseDate.trim(),
          ),
        );
      }
    }

    if (chips.isEmpty) {
      return null;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center, // Center for mobile
      children: chips,
    );
  }

  Widget? _buildDescriptionSection(BuildContext context) {
    final description = _plotSummary?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.description,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget? _buildExtraDetails(BuildContext context) {
    final entries = <_DetailEntry>[];

    // Yönetmen
    final director = _directorInfo;
    if (director != null && director.isNotEmpty) {
      entries.add(
        _DetailEntry(
          icon: Icons.person,
          title: context.loc.director,
          value: director,
        ),
      );
    }

    // Oyuncular
    final cast = _castInfo;
    if (cast != null && cast.isNotEmpty) {
      entries.add(
        _DetailEntry(
          icon: Icons.people,
          title: context.loc.cast,
          value: cast,
        ),
      );
    }

    // Eklenme Tarihi
    final vod = widget.contentItem.vodStream;
    if (vod?.createdAt != null) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      entries.add(
        _DetailEntry(
          icon: Icons.calendar_today,
          title: context.loc.creation_date,
          value: DateFormat.yMMMMd(locale).format(vod!.createdAt!),
        ),
      );
    }

    if (entries.isEmpty) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.info,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entries
              .map((e) => _DetailCard(
                    icon: e.icon,
                    title: e.title,
                    value: e.value,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget? _buildTrailerButton(BuildContext context) {
    final vod = widget.contentItem.vodStream;
    if (vod == null || _displayName.isEmpty) {
      return null;
    }

    return FilledButton.tonalIcon(
      onPressed: () => _openTrailer(context),
      icon: const Icon(Icons.ondemand_video),
      label: Text(context.loc.trailer),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.2),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    final hasProgress = !_isLoadingHistory &&
        progress != null &&
        progress > 0.01 &&
        progress < 0.98 &&
        _watchHistory?.totalDuration != null;

    final label = hasProgress
        ? context.loc.continue_watching
        : context.loc.start_watching;

    final children = <Widget>[];

    if (_isLoadingHistory) {
      children.add(const LinearProgressIndicator());
      children.add(const SizedBox(height: 16));
    } else if (hasProgress) {
      children.add(
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          borderRadius: BorderRadius.circular(2),
        ),
      );
      children.add(const SizedBox(height: 8));
      children.add(
        Text(
          '${_formatDuration(_watchHistory!.watchDuration!)} / '
          '${_formatDuration(_watchHistory!.totalDuration!)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    children.add(
      ElevatedButton.icon(
        onPressed: _openPlayer,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          shadowColor: theme.colorScheme.primary.withOpacity(0.5),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 32),
        label: Text(
          label,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final buffer = StringBuffer();
    if (hours > 0) {
      buffer.write(hours.toString().padLeft(2, '0'));
      buffer.write(':');
    }

    buffer.write(minutes.toString().padLeft(2, '0'));
    buffer.write(':');
    buffer.write(seconds.toString().padLeft(2, '0'));

    return buffer.toString();
  }

  Future<void> _openTrailer(BuildContext context) async {
    final vod = widget.contentItem.vodStream;
    if (vod == null) {
      return;
    }

    final trailerKey = vod.youtubeTrailer;
    final languageCode = Localizations.localeOf(context).languageCode;

    final String urlString;
    if (trailerKey != null && trailerKey.isNotEmpty) {
      urlString = 'https://www.youtube.com/watch?v=$trailerKey';
    } else {
      final query = Uri.encodeQueryComponent(
        '$_displayName trailer $languageCode',
      );
      urlString = 'https://www.youtube.com/results?search_query=$query';
    }

    final uri = Uri.parse(urlString);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.error_occurred_title)),
      );
    }
  }

  void _openPlayer() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _MoviePlayerPage(
          contentItem: _activeContentItem,
          queue:
              _categoryMovies.isNotEmpty
                  ? _categoryMovies
                  : [_activeContentItem],
        ),
      ),
    );
  }
}

class _DetailEntry {
  final IconData icon;
  final String title;
  final String value;

  _DetailEntry({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoviePlayerPage extends StatefulWidget {
  final ContentItem contentItem;
  final List<ContentItem> queue;

  const _MoviePlayerPage({required this.contentItem, required this.queue});

  @override
  State<_MoviePlayerPage> createState() => _MoviePlayerPageState();
}

class _MoviePlayerPageState extends State<_MoviePlayerPage> {
  @override
  void initState() {
    super.initState();
    _hideSystemUI();
  }

  @override
  void dispose() {
    _showSystemUI();
    super.dispose();
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox.expand(
          child: PlayerWidget(
            contentItem: widget.contentItem,
            queue: widget.queue,
          ),
        ),
      ),
    );
  }
}
