import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/hidden_items_controller.dart';
import '../../widgets/content_card.dart';

class SearchScreen extends StatelessWidget {
  final ContentType contentType;

  const SearchScreen({super.key, required this.contentType});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesController()..loadFavorites()),
        ChangeNotifierProvider(create: (_) => HiddenItemsController()..loadHiddenItems()),
      ],
      child: _SearchScreenContent(contentType: contentType),
    );
  }
}

class _SearchScreenContent extends StatefulWidget {
  final ContentType contentType;

  const _SearchScreenContent({required this.contentType});

  @override
  _SearchScreenContentState createState() => _SearchScreenContentState();
}

class _SearchScreenContentState extends State<_SearchScreenContent> {
  bool isSearching = false;
  bool isLoading = false;
  String? errorMessage;
  bool isSearched = false;
  TextEditingController searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  List<ContentItem> contentItems = [];
  IptvRepository repository = AppState.xtreamCodeRepository!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startSearch();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  String _getSearchHint(BuildContext context) {
    switch (widget.contentType) {
      case ContentType.liveStream:
        return context.loc.search_live_stream;
      case ContentType.vod:
        return context.loc.search_movie;
      case ContentType.series:
        return context.loc.search_series;
    }
  }

  String _getScreenTitle(BuildContext context) {
    switch (widget.contentType) {
      case ContentType.liveStream:
        return context.loc.search_live_stream;
      case ContentType.vod:
        return context.loc.search_movie;
      case ContentType.series:
        return context.loc.search_series;
    }
  }

  void startSearch() {
    setState(() {
      isSearching = true;
      isSearched = true;
    });
    Future.delayed(Duration(milliseconds: 100), () {
      searchFocusNode.requestFocus();
    });
  }

  void stopSearch() {
    setState(() {
      isSearching = false;
      searchController.clear();
      contentItems = [];
    });
    searchFocusNode.unfocus();
  }

  Future<void> _performSearch(String value) async {
    if (value.isEmpty || value.trim().isEmpty) {
      setState(() {
        contentItems = [];
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      contentItems = [];
    });

    try {
      List<ContentItem> searchResults = [];

      switch (widget.contentType) {
        case ContentType.liveStream:
          var liveStreams = await repository.searchLiveStreams(value);
          searchResults = liveStreams
              .map(
                (x) => ContentItem(
                  x.streamId,
                  x.name,
                  x.streamIcon,
                  ContentType.liveStream,
                  liveStream: x,
                ),
              )
              .toList();
          break;

        case ContentType.vod:
          var vodStreams = await repository.searchMovies(value);
          searchResults = vodStreams
              .map(
                (x) => ContentItem(
                  x.streamId,
                  x.name,
                  x.streamIcon,
                  ContentType.vod,
                  containerExtension: x.containerExtension,
                  vodStream: x,
                ),
              )
              .toList();
          break;

        case ContentType.series:
          var series = await repository.searchSeries(value);
          searchResults = series
              .map(
                (x) => ContentItem(
                  x.seriesId,
                  x.name,
                  x.cover ?? '',
                  ContentType.series,
                  seriesStream: x,
                ),
              )
              .toList();
          break;
      }

      setState(() {
        contentItems = searchResults;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                decoration: InputDecoration(
                  hintText: _getSearchHint(context),
                  border: InputBorder.none,
                ),
                autofocus: true,
                onChanged: _performSearch,
              )
            : SelectableText(
                _getScreenTitle(context),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          if (isSearching)
            IconButton(icon: Icon(Icons.clear), onPressed: stopSearch)
          else
            IconButton(icon: Icon(Icons.search), onPressed: startSearch),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    return _buildContentGrid(context);
  }

  Widget _buildContentGrid(BuildContext context) {
    if (contentItems.isEmpty &&
        isSearched &&
        searchController.text.isNotEmpty) {
      return _buildEmptyState();
    }

    if (contentItems.isEmpty) {
      return _buildInitialState();
    }

    return Consumer2<FavoritesController, HiddenItemsController>(
      builder: (context, favoritesController, hiddenController, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: _buildGridDelegate(context),
          itemCount: contentItems.length,
          itemBuilder: (context, index) =>
              _buildContentItem(context, index, contentItems, favoritesController, hiddenController),
        );
      },
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount _buildGridDelegate(
    BuildContext context,
  ) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: ResponsiveHelper.getCrossAxisCount(context),
      childAspectRatio: 0.65,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    );
  }

  Widget _buildContentItem(
    BuildContext context,
    int index,
    List<ContentItem> contentItems,
    FavoritesController favoritesController,
    HiddenItemsController hiddenController,
  ) {
    final contentItem = contentItems[index];
    final isFavorite = favoritesController.favorites.any((f) => f.streamId == contentItem.id);
    final isHidden = hiddenController.isHidden(contentItem.id);

    return ContentCard(
      content: contentItem,
      width: 150,
      onTap: () => navigateByContentType(context, contentItem),
      isFavorite: isFavorite,
      isHidden: isHidden,
      showContextMenu: true,
      onToggleFavorite: (item) => _toggleFavorite(context, item, favoritesController),
      onToggleHidden: (item) => _toggleHidden(context, item, hiddenController),
    );
  }

  void _toggleFavorite(BuildContext context, ContentItem item, FavoritesController controller) async {
    final isFav = controller.favorites.any((f) => f.streamId == item.id);
    if (isFav) {
      await controller.removeFavoriteByStreamId(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.removed_from_favorites)),
        );
      }
    } else {
      final now = DateTime.now();
      final favorite = Favorite(
        id: const Uuid().v4(),
        playlistId: AppState.currentPlaylist!.id,
        contentType: item.contentType,
        streamId: item.id,
        name: item.name,
        imagePath: item.imagePath,
        createdAt: now,
        updatedAt: now,
      );
      await controller.addFavoriteFromData(favorite);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.added_to_favorites)),
        );
      }
    }
  }

  void _toggleHidden(BuildContext context, ContentItem item, HiddenItemsController controller) async {
    final isHid = controller.isHidden(item.id);
    if (isHid) {
      await controller.unhideItem(item);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.item_unhidden)),
        );
      }
    } else {
      await controller.hideItem(item);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.item_hidden)),
        );
      }
    }
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          // Burası zaten yorum satırında
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getEmptyStateIcon(), size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            _getEmptyStateMessage(),
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getEmptyStateIcon() {
    switch (widget.contentType) {
      case ContentType.liveStream:
        return Icons.live_tv_outlined;
      case ContentType.vod:
        return Icons.movie_outlined;
      case ContentType.series:
        return Icons.tv_outlined;
    }
  }

  String _getEmptyStateMessage() {
    switch (widget.contentType) {
      case ContentType.liveStream:
        return context.loc.live_stream_not_found;
      case ContentType.vod:
        return context.loc.movie_not_found;
      case ContentType.series:
        return 'Dizi bulunamadı'; // Bu için localization key'ine ihtiyaç var
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            '${context.loc.error_occurred}: $errorMessage',
            style: const TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
