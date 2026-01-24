import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_filter.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/offline_items_repository.dart';
import 'package:another_iptv_player/services/content_filter_apply_service.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/widgets/content_filter_dialog.dart';
import '../controllers/category_detail_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/hidden_items_controller.dart';
import '../widgets/category_detail/category_app_bar.dart';
import '../widgets/category_detail/content_states.dart';
import '../widgets/category_detail/content_grid.dart';
import '../models/favorite.dart';
import '../services/app_state.dart';
import '../services/parental_control_service.dart';

class CategoryDetailScreen extends StatelessWidget {
  final CategoryViewModel category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CategoryDetailController(category)),
        ChangeNotifierProvider(create: (_) => FavoritesController()..loadFavorites()),
        ChangeNotifierProvider(create: (_) => HiddenItemsController()..loadHiddenItems()),
      ],
      child: const _CategoryDetailView(),
    );
  }
}

class _CategoryDetailView extends StatefulWidget {
  const _CategoryDetailView();

  @override
  State<_CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<_CategoryDetailView> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineItemsRepository _offlineItemsRepository = OfflineItemsRepository();
  final ContentFilterApplyService _filterService = ContentFilterApplyService();
  Set<String> _offlineStreamIds = {};
  ContentFilter _contentFilter = const ContentFilter();
  Set<String> _availableGenres = {};
  List<ContentItem>? _filteredItems;
  bool _isApplyingFilter = false;

  @override
  void initState() {
    super.initState();
    _loadOfflineItems();
  }

  Future<void> _loadOfflineItems() async {
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId != null) {
      final offlineIds = await _offlineItemsRepository.getOfflineStreamIds(playlistId);
      if (mounted) {
        setState(() {
          _offlineStreamIds = offlineIds;
        });
      }
    }
  }

  Future<void> _loadAvailableGenres(List<ContentItem> items) async {
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) return;

    final genres = await _filterService.extractGenres(items, playlistId);
    if (mounted) {
      setState(() {
        _availableGenres = genres;
      });
    }
  }

  Future<void> _applyFilter(List<ContentItem> items) async {
    if (!_contentFilter.hasActiveFilters && !_contentFilter.hasCustomSort) {
      setState(() {
        _filteredItems = null;
      });
      return;
    }

    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) return;

    setState(() {
      _isApplyingFilter = true;
    });

    final filtered = await _filterService.applyFilter(items, _contentFilter, playlistId);

    if (mounted) {
      setState(() {
        _filteredItems = filtered;
        _isApplyingFilter = false;
      });
    }
  }

  void _showFilterDialog(CategoryDetailController controller) async {
    // Load genres from TMDB cache if not already loaded
    if (_availableGenres.isEmpty) {
      await _loadAvailableGenres(controller.displayItems);
    }

    if (!mounted) return;

    // Determine if this is a movie category (show box office filter)
    final isMovie = controller.category.contentItems.isNotEmpty &&
        controller.category.contentItems.first.contentType == ContentType.vod;

    final result = await ContentFilterDialog.show(
      context,
      initialFilter: _contentFilter,
      availableGenres: _availableGenres,
      showBoxOffice: isMovie,
    );

    if (result != null && mounted) {
      setState(() {
        _contentFilter = result;
      });
      await _applyFilter(controller.displayItems);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<CategoryDetailController, FavoritesController, HiddenItemsController>(
      builder: (context, controller, favoritesController, hiddenController, child) {
        // Determine if this is a filterable content type (movies or series)
        final isFilterable = controller.category.contentItems.isNotEmpty &&
            (controller.category.contentItems.first.contentType == ContentType.vod ||
             controller.category.contentItems.first.contentType == ContentType.series);

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              CategoryAppBar(
                title: controller.category.category.categoryName,
                isSearching: controller.isSearching,
                searchController: _searchController,
                onSearchStart: controller.startSearch,
                onSearchStop: () {
                  controller.stopSearch();
                  _searchController.clear();
                },
                onSearchChanged: controller.searchContent,
                onSortPressed: () => _showSortOptions(controller),
                onFilterPressed: isFilterable ? () => _showFilterDialog(controller) : null,
                activeFilterCount: _contentFilter.activeFilterCount,
              ),
            ],
            body: _buildBody(controller, favoritesController, hiddenController),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    CategoryDetailController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenController,
  ) {
    if (controller.isLoading) return const LoadingState();
    if (_isApplyingFilter) return const LoadingState();
    if (controller.errorMessage != null) {
      return ErrorState(
        message: controller.errorMessage!,
        onRetry: controller.loadContent,
      );
    }
    if (controller.isEmpty) return const EmptyState();

    // Use filtered items if filter is active, otherwise use controller items
    var displayItems = (_filteredItems ?? controller.displayItems)
        .where((item) => !hiddenController.isHidden(item.id))
        .toList();

    // Apply parental control filtering
    final parentalService = ParentalControlService();
    final (regularItems, blockedItems) = parentalService.separateContent(displayItems);

    // If parental controls are enabled and locked, only show regular items
    // If unlocked, show regular items first, then blocked items at the end
    if (parentalService.isEnabled) {
      if (parentalService.isUnlocked) {
        displayItems = [...regularItems, ...blockedItems];
      } else {
        displayItems = regularItems;
      }
    }

    final favoriteStreamIds = favoritesController.favorites.map((f) => f.streamId).toSet();
    final hiddenStreamIds = hiddenController.hiddenStreamIds;

    // Sort: favorites at top, offline at end, blocked at very end
    final blockedIds = blockedItems.map((i) => i.id).toSet();
    displayItems.sort((a, b) {
      // Keep blocked items at the very end
      final aIsBlocked = blockedIds.contains(a.id);
      final bIsBlocked = blockedIds.contains(b.id);
      if (aIsBlocked && !bIsBlocked) return 1;
      if (!aIsBlocked && bIsBlocked) return -1;

      // Among non-blocked items, keep offline items at end
      final aIsOffline = _offlineStreamIds.contains(a.id);
      final bIsOffline = _offlineStreamIds.contains(b.id);
      if (aIsOffline && !bIsOffline) return 1;
      if (!aIsOffline && bIsOffline) return -1;

      // Among non-offline/non-blocked items, sort favorites to top
      final aIsFavorite = favoriteStreamIds.contains(a.id);
      final bIsFavorite = favoriteStreamIds.contains(b.id);
      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;
      return 0; // Keep original order for items with same status
    });

    return Column(
      children: [
        if (controller.genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: _buildGenreSelector(controller),
          ),
        Expanded(
          child: ContentGrid(
            items: displayItems,
            onItemTap: (item) => navigateByContentType(context, item),
            favoriteStreamIds: favoriteStreamIds,
            hiddenStreamIds: hiddenStreamIds,
            offlineStreamIds: _offlineStreamIds,
            onToggleFavorite: (item) => _toggleFavorite(context, item, favoritesController),
            onToggleHidden: (item) => _toggleHidden(context, item, hiddenController),
          ),
        ),
      ],
    );
  }

  void _toggleFavorite(BuildContext context, ContentItem item, FavoritesController controller) async {
    final isFav = controller.favorites.any((f) => f.streamId == item.id);
    if (isFav) {
      final success = await controller.removeFavoriteByStreamId(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? context.loc.removed_from_favorites : 'Error removing favorite')),
        );
      }
    } else {
      final now = DateTime.now();
      // Use item's sourcePlaylistId in combined mode, fall back to currentPlaylist
      final playlistId = item.sourcePlaylistId ?? AppState.currentPlaylist?.id ?? 'unified';
      final favorite = Favorite(
        id: const Uuid().v4(),
        playlistId: playlistId,
        contentType: item.contentType,
        streamId: item.id,
        name: item.name,
        imagePath: item.imagePath,
        createdAt: now,
        updatedAt: now,
      );
      final success = await controller.addFavoriteFromData(favorite);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? context.loc.added_to_favorites : 'Error adding favorite')),
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

  Widget _buildGenreSelector(CategoryDetailController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.loc.all),
            selected: controller.selectedGenre == null,
            onSelected: (_) => controller.filterByGenre(null),
          ),
          ...controller.genres.map(
                (g) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(_capitalizeGenre(g)),
                selected: controller.selectedGenre == g,
                onSelected: (_) => controller.filterByGenre(g),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(CategoryDetailController controller) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('A → Z'),
                onTap: () {
                  controller.sortItems("ascending");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Z → A'),
                onTap: () {
                  controller.sortItems("descending");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(context.loc.release_date),
                onTap: () {
                  controller.sortItems("release_date");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_rate),
                title: Text(context.loc.rating),
                onTap: () {
                  controller.sortItems("rating");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _capitalizeGenre(String genre) {
    if (genre.isEmpty) return genre;
    return genre
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      final first = word.characters.first.toUpperCase();
      final rest = word.characters.skip(1).join();
      return '$first$rest';
    })
        .join(' ');
  }
}