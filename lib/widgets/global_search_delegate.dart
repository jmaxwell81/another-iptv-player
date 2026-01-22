import 'dart:async';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/controllers/global_search_controller.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/widgets/smart_cached_image.dart';

/// Search result with navigation callback
class GlobalSearchResultItem {
  final ContentItem item;
  final int panelIndex; // Index of the panel to navigate to

  GlobalSearchResultItem({
    required this.item,
    required this.panelIndex,
  });
}

/// Global search delegate for searching across all content types
class GlobalSearchDelegate extends SearchDelegate<GlobalSearchResultItem?> {
  final GlobalSearchController _controller = GlobalSearchController();
  final Function(GlobalSearchResultItem) onResultSelected;
  Timer? _debounce;

  GlobalSearchDelegate({
    required this.onResultSelected,
  }) : super(
          searchFieldLabel: 'Search live, movies, series...',
          keyboardType: TextInputType.text,
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            _controller.clearResults();
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Debounce search
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _controller.search(query);
    });

    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (query.isEmpty) {
          return _buildEmptyQueryState(context);
        }

        if (_controller.isSearching) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_controller.errorMessage!),
              ],
            ),
          );
        }

        final results = _controller.results;
        if (results.isEmpty) {
          return _buildNoResultsState(context);
        }

        return _buildResultsList(context, results);
      },
    );
  }

  Widget _buildEmptyQueryState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Search across all content',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Find live streams, movies, and series',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for "$query"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, GlobalSearchResult results) {
    return ListView(
      children: [
        // Live Streams section
        if (results.liveStreams.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Live Streams',
            Icons.live_tv,
            results.liveStreams.length,
          ),
          ...results.liveStreams.take(10).map(
                (item) => _buildResultTile(context, item, 2), // Panel index 2 for Live
              ),
          if (results.liveStreams.length > 10)
            _buildShowMoreTile(context, results.liveStreams.length - 10, 'live streams'),
        ],

        // Movies section
        if (results.movies.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Movies',
            Icons.movie,
            results.movies.length,
          ),
          ...results.movies.take(10).map(
                (item) => _buildResultTile(context, item, 4), // Panel index 4 for Movies
              ),
          if (results.movies.length > 10)
            _buildShowMoreTile(context, results.movies.length - 10, 'movies'),
        ],

        // Series section
        if (results.series.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Series',
            Icons.tv,
            results.series.length,
          ),
          ...results.series.take(10).map(
                (item) => _buildResultTile(context, item, 5), // Panel index 5 for Series
              ),
          if (results.series.length > 10)
            _buildShowMoreTile(context, results.series.length - 10, 'series'),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, ContentItem item, int panelIndex) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 50,
          height: 50,
          child: item.imagePath.isNotEmpty
              ? SmartCachedImage(
                  imageUrl: item.imagePath,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(item.contentType),
                  errorWidget: (context, url, error) => _buildPlaceholder(item.contentType),
                )
              : _buildPlaceholder(item.contentType),
        ),
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _getContentTypeLabel(item.contentType),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      trailing: Icon(
        Icons.play_arrow,
        color: Theme.of(context).colorScheme.primary,
      ),
      onTap: () {
        final result = GlobalSearchResultItem(
          item: item,
          panelIndex: panelIndex,
        );
        onResultSelected(result);
        close(context, result);
      },
    );
  }

  Widget _buildPlaceholder(ContentType contentType) {
    IconData icon;
    switch (contentType) {
      case ContentType.liveStream:
        icon = Icons.live_tv;
        break;
      case ContentType.vod:
        icon = Icons.movie;
        break;
      case ContentType.series:
        icon = Icons.tv;
        break;
    }
    return Container(
      color: Colors.grey[800],
      child: Icon(icon, color: Colors.grey[600], size: 24),
    );
  }

  Widget _buildShowMoreTile(BuildContext context, int moreCount, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '+ $moreCount more $type',
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getContentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.liveStream:
        return 'Live Stream';
      case ContentType.vod:
        return 'Movie';
      case ContentType.series:
        return 'Series';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
