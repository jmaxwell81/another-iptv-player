import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import '../controllers/category_detail_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/hidden_items_controller.dart';
import '../widgets/category_detail/category_app_bar.dart';
import '../widgets/category_detail/content_states.dart';
import '../widgets/category_detail/content_grid.dart';
import '../models/favorite.dart';
import '../services/app_state.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<CategoryDetailController, FavoritesController, HiddenItemsController>(
      builder: (context, controller, favoritesController, hiddenController, child) {
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
    if (controller.errorMessage != null) {
      return ErrorState(
        message: controller.errorMessage!,
        onRetry: controller.loadContent,
      );
    }
    if (controller.isEmpty) return const EmptyState();

    // Show all items - hidden items will be displayed greyed out
    final displayItems = controller.displayItems;

    final favoriteStreamIds = favoritesController.favorites.map((f) => f.streamId).toSet();
    final hiddenStreamIds = hiddenController.hiddenStreamIds;

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