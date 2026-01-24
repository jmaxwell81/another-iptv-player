import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/unified_home_controller.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/hidden_items_controller.dart';
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_filters.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/screens/category_detail_screen.dart';
import 'package:another_iptv_player/screens/watch_history_screen.dart';
import 'package:another_iptv_player/screens/favorites/favorites_screen.dart';
import 'package:another_iptv_player/screens/settings/general_settings_section.dart';
import 'package:another_iptv_player/screens/tv_guide/tv_guide_screen.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/source_offline_service.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:another_iptv_player/widgets/category_section.dart';
import 'package:another_iptv_player/widgets/global_search_delegate.dart';
import 'package:another_iptv_player/widgets/tv/tv_focus_scope.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';

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

  // Categories that should show only favorites
  Set<String> _favoritesOnlyCategories = {};

  // Pinned categories (appear at top) - both IDs and names for reliable matching
  List<String> _pinnedCategoryIds = [];
  List<String> _pinnedCategoryNames = [];

  // Demoted categories (appear at bottom) - both IDs and names for reliable matching
  List<String> _demotedCategoryIds = [];
  List<String> _demotedCategoryNames = [];

  // Source offline service for recovery notifications
  final SourceOfflineService _sourceOfflineService = SourceOfflineService();
  StreamSubscription<SourceStatusEvent>? _sourceStatusSubscription;

  @override
  void initState() {
    super.initState();
    _controller = UnifiedHomeController();
    _favoritesController = FavoritesController();
    _favoritesController.loadFavorites();
    _hiddenItemsController = HiddenItemsController();
    _hiddenItemsController.loadHiddenItems(); // Loads from all active playlists in combined mode
    _loadFavoritesOnlyCategories();
    _loadPinnedCategories();
    _loadDemotedCategories();
    _subscribeToSourceStatus();
  }

  /// Subscribe to source status events for showing recovery/offline notifications
  void _subscribeToSourceStatus() {
    _sourceStatusSubscription = _sourceOfflineService.statusEvents.listen((event) {
      if (!mounted) return;

      final playlist = AppState.activePlaylists[event.playlistId];
      final sourceName = playlist?.name ?? 'Source';

      if (event.isOnline) {
        // Source recovered - show success notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$sourceName is back online'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // Source went offline - show warning notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$sourceName is offline${event.error != null ? ': ${event.error}' : ''}'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  Future<void> _loadFavoritesOnlyCategories() async {
    final categories = await UserPreferences.getFavoritesOnlyCategories();
    if (mounted) {
      setState(() {
        _favoritesOnlyCategories = categories.toSet();
      });
    }
  }

  Future<void> _toggleFavoritesOnlyCategory(String categoryId) async {
    await UserPreferences.toggleFavoritesOnlyCategory(categoryId);
    if (mounted) {
      setState(() {
        if (_favoritesOnlyCategories.contains(categoryId)) {
          _favoritesOnlyCategories.remove(categoryId);
        } else {
          _favoritesOnlyCategories.add(categoryId);
        }
      });
    }
  }

  Future<void> _loadPinnedCategories() async {
    final pinnedIds = await UserPreferences.getPinnedCategories();
    final pinnedNames = await UserPreferences.getPinnedCategoryNames();
    if (mounted) {
      setState(() {
        _pinnedCategoryIds = pinnedIds;
        _pinnedCategoryNames = pinnedNames;
      });
    }
  }

  Future<void> _togglePinnedCategory(String categoryId, String categoryName) async {
    final normalizedName = categoryName.toLowerCase().trim();
    final isPinned = _pinnedCategoryIds.contains(categoryId) ||
        _pinnedCategoryNames.contains(normalizedName);

    if (isPinned) {
      await UserPreferences.unpinCategoryWithName(categoryId, categoryName);
    } else {
      await UserPreferences.pinCategoryToTopWithName(categoryId, categoryName);
    }
    await _loadPinnedCategories();
  }

  Future<void> _loadDemotedCategories() async {
    final demotedIds = await UserPreferences.getDemotedCategories();
    final demotedNames = await UserPreferences.getDemotedCategoryNames();
    if (mounted) {
      setState(() {
        _demotedCategoryIds = demotedIds;
        _demotedCategoryNames = demotedNames;
      });
    }
  }

  Future<void> _toggleDemotedCategory(String categoryId, String categoryName) async {
    final normalizedName = categoryName.toLowerCase().trim();
    final isDemoted = _demotedCategoryIds.contains(categoryId) ||
        _demotedCategoryNames.contains(normalizedName);

    if (isDemoted) {
      await UserPreferences.undemoteCategoryWithName(categoryId, categoryName);
    } else {
      await UserPreferences.demoteCategoryToBottomWithName(categoryId, categoryName);
    }
    await _loadDemotedCategories();
    await _loadPinnedCategories(); // Refresh pinned too since demoting removes from pinned
  }

  /// Check if a category is pinned (by ID or normalized name)
  bool _isCategoryPinned(CategoryViewModel category) {
    final catId = category.category.categoryId;
    final normalizedName = category.category.categoryName.toLowerCase().trim();
    return _pinnedCategoryIds.contains(catId) || _pinnedCategoryNames.contains(normalizedName);
  }

  /// Check if a category is demoted (by ID or normalized name)
  bool _isCategoryDemoted(CategoryViewModel category) {
    final catId = category.category.categoryId;
    final normalizedName = category.category.categoryName.toLowerCase().trim();
    return _demotedCategoryIds.contains(catId) || _demotedCategoryNames.contains(normalizedName);
  }

  /// Get the pinned index for a category (by ID or name)
  int _getPinnedIndex(CategoryViewModel category) {
    final catId = category.category.categoryId;
    final normalizedName = category.category.categoryName.toLowerCase().trim();

    // Check ID first
    final idIndex = _pinnedCategoryIds.indexOf(catId);
    if (idIndex >= 0) return idIndex;

    // Check name
    final nameIndex = _pinnedCategoryNames.indexOf(normalizedName);
    return nameIndex;
  }

  /// Sort categories: pinned first, then normal, then demoted
  List<CategoryViewModel> _sortCategoriesWithPinnedFirst(List<CategoryViewModel> categories) {
    if (_pinnedCategoryIds.isEmpty && _pinnedCategoryNames.isEmpty &&
        _demotedCategoryIds.isEmpty && _demotedCategoryNames.isEmpty) {
      return categories;
    }

    final pinned = <CategoryViewModel>[];
    final normal = <CategoryViewModel>[];
    final demoted = <CategoryViewModel>[];

    // Separate categories into pinned, normal, and demoted
    for (final cat in categories) {
      if (_isCategoryPinned(cat)) {
        pinned.add(cat);
      } else if (_isCategoryDemoted(cat)) {
        demoted.add(cat);
      } else {
        normal.add(cat);
      }
    }

    // Sort pinned categories by their pinned order
    pinned.sort((a, b) {
      final aIndex = _getPinnedIndex(a);
      final bIndex = _getPinnedIndex(b);
      return aIndex.compareTo(bIndex);
    });

    return [...pinned, ...normal, ...demoted];
  }

  @override
  void dispose() {
    _sourceStatusSubscription?.cancel();
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
      color: AppThemes.netflixBlack,
      child: Column(
        children: [
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = controller.currentIndex == index;
            return _DesktopNavItem(
              icon: item['icon'] as IconData,
              label: item['label'] as String,
              isSelected: isSelected,
              onTap: () => controller.onNavigationTap(index),
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
    return Container(
      decoration: const BoxDecoration(
        color: AppThemes.netflixBlack,
        border: Border(
          top: BorderSide(color: AppThemes.dividerGrey, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: controller.currentIndex,
        onTap: controller.onNavigationTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppThemes.textWhite,
        unselectedItemColor: AppThemes.iconGrey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_view_day), label: 'TV Guide'),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Movies'),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Series'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
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
    final filters = controller.getFilters(categoryType);
    final availableSources = controller.availableSources;
    final filterCount = filters.activeFilterCount;
    final hasFilter = filterCount > 0;

    // For Live, only use source filter
    final isLive = contentType == ContentType.liveStream;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        actions: [
          // Global search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showGlobalSearch(context, controller),
            tooltip: 'Search',
          ),
          // Filter button
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilter,
              label: hasFilter ? Text('$filterCount') : null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => isLive
                ? _showSourceFilterSheet(context, controller, categoryType, availableSources)
                : _showContentFilterSheet(context, controller, categoryType, availableSources),
            tooltip: isLive ? 'Filter by source' : 'Filters',
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
    // Apply parental control filtering to categories
    final parentalService = ParentalControlService();
    final allCategories = categories.map((c) => c.category).toList();
    final (List<Category> regularCategories, List<Category> blockedCategories) = parentalService.separateCategories(allCategories);

    List<CategoryViewModel> filteredCategories;
    if (parentalService.isEnabled) {
      if (parentalService.isUnlocked) {
        // Show regular categories first, then blocked at the end
        final regularCategoryIds = regularCategories.map((Category c) => c.categoryId).toSet();
        final blockedCategoryIds = blockedCategories.map((Category c) => c.categoryId).toSet();
        filteredCategories = [
          ...categories.where((c) => regularCategoryIds.contains(c.category.categoryId)),
          ...categories.where((c) => blockedCategoryIds.contains(c.category.categoryId)),
        ];
      } else {
        // Only show regular categories when locked
        final regularCategoryIds = regularCategories.map((Category c) => c.categoryId).toSet();
        filteredCategories = categories.where((c) => regularCategoryIds.contains(c.category.categoryId)).toList();
      }
    } else {
      filteredCategories = categories;
    }

    // Sort categories with pinned ones first
    final sortedCategories = _sortCategoriesWithPinnedFirst(filteredCategories);

    // Wrap with TvVerticalFocusColumn for vertical D-pad navigation between category rows
    return TvVerticalFocusColumn(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) => _buildCategorySection(
          sortedCategories[index],
          contentType,
          favoriteStreamIds,
          hiddenStreamIds,
          favoritesController,
          hiddenItemsController,
        ),
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
    var contentItems = category.contentItems
        .where((item) => !hiddenStreamIds.contains(item.id))
        .toList();

    // Apply parental control filtering to content items
    final parentalService = ParentalControlService();
    final (regularItems, blockedItems) = parentalService.separateContent(contentItems);

    if (parentalService.isEnabled) {
      if (parentalService.isUnlocked) {
        // Show regular items first, then blocked at the end
        contentItems = [...regularItems, ...blockedItems];
      } else {
        // Only show regular items when locked
        contentItems = regularItems;
      }
    }

    final filteredCategory = CategoryViewModel(
      category: category.category,
      contentItems: contentItems,
    );

    if (filteredCategory.contentItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final categoryId = category.category.categoryId;
    final categoryName = category.category.categoryName;
    final isPinned = _isCategoryPinned(category);
    final pinnedIndex = _getPinnedIndex(category);
    final isDemoted = _isCategoryDemoted(category);

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
      isFavoritesOnly: _favoritesOnlyCategories.contains(categoryId),
      onToggleFavoritesOnly: _toggleFavoritesOnlyCategory,
      isPinned: isPinned,
      pinnedIndex: isPinned ? pinnedIndex : null,
      onTogglePinned: _togglePinnedCategory,
      onMoveToTop: () async {
        await UserPreferences.pinCategoryToTopWithName(categoryId, categoryName);
        await _loadPinnedCategories();
      },
      isDemoted: isDemoted,
      onToggleDemoted: _toggleDemotedCategory,
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

  /// Show global search dialog
  void _showGlobalSearch(BuildContext context, UnifiedHomeController controller) {
    showSearch(
      context: context,
      delegate: GlobalSearchDelegate(
        onResultSelected: (result) {
          // Navigate to the appropriate panel
          controller.onNavigationTap(result.panelIndex);
          // Play the selected content
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              navigateByContentType(context, result.item);
            }
          });
        },
      ),
    );
  }

  /// Show bottom sheet for source filtering
  void _showSourceFilterSheet(
    BuildContext context,
    UnifiedHomeController controller,
    CategoryType categoryType,
    Map<String, String> availableSources,
  ) {
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

  /// Show comprehensive filter sheet for Movies/Series (rating, genre, year, source)
  void _showContentFilterSheet(
    BuildContext context,
    UnifiedHomeController controller,
    CategoryType categoryType,
    Map<String, String> availableSources,
  ) {
    final isMovies = categoryType == CategoryType.vod;
    final initialFilters = controller.getFilters(categoryType);
    final availableGenres = isMovies
        ? (controller.availableMovieGenres.toList()..sort())
        : (controller.availableSeriesGenres.toList()..sort());
    final availableYears = isMovies
        ? (controller.availableMovieYears.toList()..sort((a, b) => b.compareTo(a)))
        : (controller.availableSeriesYears.toList()..sort((a, b) => b.compareTo(a)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        // Local state for the filter sheet
        double? selectedRating = initialFilters.minRating;
        Set<String> selectedGenres = Set.from(initialFilters.genres);
        int? selectedMinYear = initialFilters.minYear;
        int? selectedMaxYear = initialFilters.maxYear;
        Set<String> selectedSources = Set.from(initialFilters.sources);
        ContentSortBy selectedSort = initialFilters.sortBy;

        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            final hasActiveFilters = selectedRating != null ||
                selectedGenres.isNotEmpty ||
                selectedMinYear != null ||
                selectedMaxYear != null ||
                selectedSources.isNotEmpty;
            final hasNonDefaultSort = selectedSort != ContentSortBy.addedDate;

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filters',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextButton(
                              onPressed: (hasActiveFilters || hasNonDefaultSort)
                                  ? () {
                                      setSheetState(() {
                                        selectedRating = null;
                                        selectedGenres.clear();
                                        selectedMinYear = null;
                                        selectedMaxYear = null;
                                        selectedSources.clear();
                                        selectedSort = ContentSortBy.addedDate;
                                      });
                                    }
                                  : null,
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Filter content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            // Sort options
                            const SizedBox(height: 16),
                            Text(
                              'Sort By',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: ContentSortBy.values.map((sortOption) {
                                final isSelected = selectedSort == sortOption;
                                return ChoiceChip(
                                  avatar: Icon(sortOption.icon, size: 18),
                                  label: Text(sortOption.label),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setSheetState(() {
                                        selectedSort = sortOption;
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),

                            // Rating filter
                            const SizedBox(height: 24),
                            Text(
                              'Minimum Rating',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: RatingThresholds.values.map((rating) {
                                final isSelected = selectedRating == (rating == 0 ? null : rating);
                                return FilterChip(
                                  label: Text(RatingThresholds.getLabel(rating)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setSheetState(() {
                                      selectedRating = selected && rating > 0 ? rating : null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            // Genre filter
                            if (availableGenres.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Genres',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (selectedGenres.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        setSheetState(() {
                                          selectedGenres.clear();
                                        });
                                      },
                                      child: const Text('Clear'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: availableGenres.map((genre) {
                                  final isSelected = selectedGenres.contains(genre);
                                  return FilterChip(
                                    label: Text(genre),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setSheetState(() {
                                        if (selected) {
                                          selectedGenres.add(genre);
                                        } else {
                                          selectedGenres.remove(genre);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],

                            // Year filter
                            if (availableYears.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                'Release Year',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int?>(
                                      value: selectedMinYear,
                                      decoration: const InputDecoration(
                                        labelText: 'From',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('Any'),
                                        ),
                                        ...availableYears.map((year) => DropdownMenuItem<int?>(
                                          value: year,
                                          child: Text('$year'),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setSheetState(() {
                                          selectedMinYear = value;
                                          // Ensure maxYear is not less than minYear
                                          if (selectedMaxYear != null && value != null && selectedMaxYear! < value) {
                                            selectedMaxYear = value;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<int?>(
                                      value: selectedMaxYear,
                                      decoration: const InputDecoration(
                                        labelText: 'To',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('Any'),
                                        ),
                                        ...availableYears.map((year) => DropdownMenuItem<int?>(
                                          value: year,
                                          child: Text('$year'),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setSheetState(() {
                                          selectedMaxYear = value;
                                          // Ensure minYear is not greater than maxYear
                                          if (selectedMinYear != null && value != null && selectedMinYear! > value) {
                                            selectedMinYear = value;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Quick year presets
                              Wrap(
                                spacing: 8,
                                children: [
                                  ActionChip(
                                    label: Text('${YearRanges.currentYear}'),
                                    onPressed: () {
                                      setSheetState(() {
                                        selectedMinYear = YearRanges.currentYear;
                                        selectedMaxYear = YearRanges.currentYear;
                                      });
                                    },
                                  ),
                                  ActionChip(
                                    label: const Text('Last 5 years'),
                                    onPressed: () {
                                      setSheetState(() {
                                        selectedMinYear = YearRanges.currentYear - 5;
                                        selectedMaxYear = null;
                                      });
                                    },
                                  ),
                                  ActionChip(
                                    label: const Text('Classics'),
                                    onPressed: () {
                                      setSheetState(() {
                                        selectedMinYear = null;
                                        selectedMaxYear = 2000;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],

                            // Source filter
                            if (availableSources.length > 1) ...[
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sources',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (selectedSources.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        setSheetState(() {
                                          selectedSources.clear();
                                        });
                                      },
                                      child: const Text('All Sources'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: availableSources.entries.map((entry) {
                                  final isSelected = selectedSources.contains(entry.key);
                                  final isXtream = AppState.xtreamRepositories.containsKey(entry.key);
                                  return FilterChip(
                                    avatar: Icon(
                                      isXtream ? Icons.live_tv : Icons.playlist_play,
                                      size: 18,
                                      color: isSelected ? null : (isXtream ? Colors.blue : Colors.green),
                                    ),
                                    label: Text(entry.value),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setSheetState(() {
                                        if (selected) {
                                          selectedSources.add(entry.key);
                                        } else {
                                          selectedSources.remove(entry.key);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      // Apply button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              // Apply the filters
                              final newFilters = ContentFilters(
                                minRating: selectedRating,
                                genres: selectedGenres,
                                minYear: selectedMinYear,
                                maxYear: selectedMaxYear,
                                sources: selectedSources,
                                sortBy: selectedSort,
                              );

                              if (isMovies) {
                                controller.setMovieFilters(newFilters);
                              } else {
                                controller.setSeriesFilters(newFilters);
                              }

                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Desktop navigation item with hover effects
class _DesktopNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DesktopNavItem> createState() => _DesktopNavItemState();
}

class _DesktopNavItemState extends State<_DesktopNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white.withOpacity(0.1)
                : _isHovered
                    ? Colors.white.withOpacity(0.05)
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.isSelected ? AppThemes.accentRed : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected ? AppThemes.textWhite : AppThemes.iconGrey,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isSelected ? AppThemes.textWhite : AppThemes.iconGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
