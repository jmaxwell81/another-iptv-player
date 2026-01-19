import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/unified_home_controller.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/hidden_items_controller.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/screens/category_detail_screen.dart';
import 'package:another_iptv_player/screens/watch_history_screen.dart';
import 'package:another_iptv_player/screens/favorites/favorites_screen.dart';
import 'package:another_iptv_player/screens/settings/general_settings_section.dart';
import 'package:another_iptv_player/screens/tv_guide/tv_guide_screen.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:another_iptv_player/widgets/category_section.dart';

/// Home screen for combined/unified mode showing content from multiple playlists
class UnifiedHomeScreen extends StatefulWidget {
  const UnifiedHomeScreen({super.key});

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  late UnifiedHomeController _controller;
  late FavoritesController _favoritesController;
  late HiddenItemsController _hiddenItemsController;

  static const double _desktopBreakpoint = 900.0;

  @override
  void initState() {
    super.initState();
    _controller = UnifiedHomeController();
    _favoritesController = FavoritesController();
    _favoritesController.loadFavorites();
    _hiddenItemsController = HiddenItemsController();
    _hiddenItemsController.loadHiddenItems(); // Loads from all active playlists in combined mode
  }

  @override
  void dispose() {
    _controller.dispose();
    _favoritesController.dispose();
    _hiddenItemsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _controller),
        ChangeNotifierProvider.value(value: _favoritesController),
        ChangeNotifierProvider.value(value: _hiddenItemsController),
      ],
      child: Consumer3<UnifiedHomeController, FavoritesController, HiddenItemsController>(
        builder: (context, controller, favoritesController, hiddenItemsController, child) =>
            _buildMainContent(context, controller, favoritesController, hiddenItemsController),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    UnifiedHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    if (controller.isLoading) {
      return _buildLoadingScreen(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktopLayout(context, controller, favoritesController, hiddenItemsController);
        }
        return _buildMobileLayout(context, controller, favoritesController, hiddenItemsController);
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combined Sources'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading content from ${AppState.activePlaylists.length} sources...'),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    UnifiedHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    return Scaffold(
      body: _buildPageView(controller, favoritesController, hiddenItemsController),
      bottomNavigationBar: _buildBottomNavigationBar(context, controller),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    UnifiedHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    return Scaffold(
      body: Row(
        children: [
          _buildDesktopNavigation(context, controller),
          Expanded(
            child: _buildCurrentPage(controller, favoritesController, hiddenItemsController),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavigation(BuildContext context, UnifiedHomeController controller) {
    final items = _getNavigationItems(context);
    return Container(
      width: 80,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = controller.currentIndex == index;
            return InkWell(
              onTap: () => controller.onNavigationTap(index),
              child: Container(
                height: 60,
                width: double.infinity,
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getNavigationItems(BuildContext context) {
    return [
      {'icon': Icons.history, 'label': 'History'},
      {'icon': Icons.favorite, 'label': 'Favorites'},
      {'icon': Icons.live_tv, 'label': 'Live'},
      {'icon': Icons.calendar_view_day, 'label': 'TV Guide'},
      {'icon': Icons.movie, 'label': 'Movies'},
      {'icon': Icons.tv, 'label': 'Series'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];
  }

  Widget _buildBottomNavigationBar(BuildContext context, UnifiedHomeController controller) {
    return BottomNavigationBar(
      currentIndex: controller.currentIndex,
      onTap: controller.onNavigationTap,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
        BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_view_day), label: 'TV Guide'),
        BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Movies'),
        BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Series'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }

  Widget _buildPageView(
    UnifiedHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    return PageView(
      controller: controller.pageController,
      onPageChanged: controller.onPageChanged,
      children: _buildPages(controller, favoritesController, hiddenItemsController),
    );
  }

  Widget _buildCurrentPage(
    UnifiedHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    final pages = _buildPages(controller, favoritesController, hiddenItemsController);
    return IndexedStack(
      index: controller.currentIndex,
      children: pages,
    );
  }

  List<Widget> _buildPages(
    UnifiedHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    final favoriteStreamIds = favoritesController.favorites.map((f) => f.streamId).toSet();
    final hiddenStreamIds = hiddenItemsController.hiddenItems.map((h) => h.streamId).toSet();

    return [
      WatchHistoryScreen(playlistId: 'unified'),
      FavoritesScreen(playlistId: 'unified'),
      _buildContentPage(
        controller.visibleLiveCategories,
        ContentType.liveStream,
        controller,
        favoriteStreamIds,
        hiddenStreamIds,
        favoritesController,
        hiddenItemsController,
        'Live Streams',
      ),
      const TvGuideScreen(),
      _buildContentPage(
        controller.visibleMovieCategories,
        ContentType.vod,
        controller,
        favoriteStreamIds,
        hiddenStreamIds,
        favoritesController,
        hiddenItemsController,
        'Movies',
      ),
      _buildContentPage(
        controller.visibleSeriesCategories,
        ContentType.series,
        controller,
        favoriteStreamIds,
        hiddenStreamIds,
        favoritesController,
        hiddenItemsController,
        'Series',
      ),
      _buildSettingsPage(),
    ];
  }

  Widget _buildContentPage(
    List<CategoryViewModel> categories,
    ContentType contentType,
    UnifiedHomeController controller,
    Set<String> favoriteStreamIds,
    Set<String> hiddenStreamIds,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
    String title,
  ) {
    final categoryType = _contentTypeToCategoryType(contentType);
    final currentFilter = controller.getSourceFilter(categoryType);
    final availableSources = controller.availableSources;
    final hasFilter = currentFilter != null && currentFilter.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        actions: [
          // Source filter button
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilter,
              label: hasFilter ? Text('${currentFilter!.length}') : null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showSourceFilterSheet(context, controller, categoryType, availableSources),
            tooltip: 'Filter by source',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshAllContent(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No content available',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure you have active sources selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : _buildCategoryList(
              categories,
              contentType,
              favoriteStreamIds,
              hiddenStreamIds,
              favoritesController,
              hiddenItemsController,
            ),
    );
  }

  Widget _buildCategoryList(
    List<CategoryViewModel> categories,
    ContentType contentType,
    Set<String> favoriteStreamIds,
    Set<String> hiddenStreamIds,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, index) => _buildCategorySection(
        categories[index],
        contentType,
        favoriteStreamIds,
        hiddenStreamIds,
        favoritesController,
        hiddenItemsController,
      ),
    );
  }

  Widget _buildCategorySection(
    CategoryViewModel category,
    ContentType contentType,
    Set<String> favoriteStreamIds,
    Set<String> hiddenStreamIds,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    // Filter out hidden items
    final filteredCategory = CategoryViewModel(
      category: category.category,
      contentItems: category.contentItems
          .where((item) => !hiddenStreamIds.contains(item.id))
          .toList(),
    );

    if (filteredCategory.contentItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return CategorySection(
      category: filteredCategory,
      cardWidth: ResponsiveHelper.getCardWidth(context),
      cardHeight: ResponsiveHelper.getCardHeight(context),
      onSeeAllTap: () => _navigateToCategoryDetail(category),
      onContentTap: (item) => navigateByContentType(context, item),
      onToggleFavorite: (item) => _toggleFavorite(item, favoriteStreamIds, favoritesController),
      onToggleHidden: (item) => _toggleHidden(item, hiddenItemsController),
      onHideCategory: (categoryId, categoryName) => _hideCategory(categoryId, categoryName),
      favoriteStreamIds: favoriteStreamIds,
      hiddenStreamIds: hiddenStreamIds,
      playlistId: 'unified',
    );
  }

  void _navigateToCategoryDetail(CategoryViewModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(category: category),
      ),
    );
  }

  void _toggleFavorite(
    ContentItem item,
    Set<String> favoriteStreamIds,
    FavoritesController favoritesController,
  ) {
    final isFavorite = favoriteStreamIds.contains(item.id);
    if (isFavorite) {
      favoritesController.removeFavoriteByStreamId(item.id);
    } else {
      favoritesController.addFavorite(item);
    }
  }

  void _toggleHidden(ContentItem item, HiddenItemsController hiddenItemsController) {
    final isHidden = hiddenItemsController.isHidden(item.id);
    if (isHidden) {
      hiddenItemsController.unhideItem(item);
    } else {
      hiddenItemsController.hideItem(item);
    }
  }

  Future<void> _hideCategory(String categoryId, String categoryName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide Category'),
        content: Text('Hide "$categoryName"? You can show it again in Settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Save the hidden category preference (with name for cross-source matching)
      await UserPreferences.hideCategoryWithName(categoryId, categoryName);

      // Refresh the view - use the controller from the state, not from context
      await _controller.loadHiddenCategories();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$categoryName" hidden')),
        );
      }
    }
  }

  Widget _buildSettingsPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: GeneralSettingsWidget(),
      ),
    );
  }

  /// Convert ContentType to CategoryType for source filtering
  CategoryType _contentTypeToCategoryType(ContentType contentType) {
    return ContentType.toCategoryType(contentType);
  }

  /// Show bottom sheet for source filtering
  void _showSourceFilterSheet(
    BuildContext context,
    UnifiedHomeController controller,
    CategoryType categoryType,
    Map<String, String> availableSources,
  ) {
    final currentFilter = controller.getSourceFilter(categoryType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            final filter = controller.getSourceFilter(categoryType);
            final isAllSelected = filter == null || filter.isEmpty;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter by Source',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: () {
                            controller.resetSourceFilter(categoryType);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // All Sources option
                    CheckboxListTile(
                      title: const Text('All Sources'),
                      subtitle: Text('${availableSources.length} sources'),
                      value: isAllSelected,
                      onChanged: (value) {
                        if (value == true) {
                          controller.resetSourceFilter(categoryType);
                        }
                        setSheetState(() {});
                      },
                    ),
                    const Divider(),
                    // Individual sources
                    ...availableSources.entries.map((entry) {
                      final isSelected = filter?.contains(entry.key) ?? false;
                      final isXtream = AppState.xtreamRepositories.containsKey(entry.key);

                      return CheckboxListTile(
                        title: Text(entry.value),
                        subtitle: Text(isXtream ? 'Xtream Codes' : 'M3U'),
                        secondary: Icon(
                          isXtream ? Icons.live_tv : Icons.playlist_play,
                          color: isXtream ? Colors.blue : Colors.green,
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          controller.toggleSourceFilter(categoryType, entry.key);
                          setSheetState(() {});
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
