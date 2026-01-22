import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/screens/search_screen.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/xtream_code_home_controller.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/screens/category_detail_screen.dart';
import 'package:another_iptv_player/screens/xtream-codes/xtream_code_playlist_settings_screen.dart';
import 'package:another_iptv_player/screens/watch_history_screen.dart';
import 'package:another_iptv_player/screens/favorites/favorites_screen.dart';
import 'package:another_iptv_player/screens/tv_guide/tv_guide_screen.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/pip_manager.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:another_iptv_player/widgets/category_section.dart';
import 'package:another_iptv_player/widgets/global_search_delegate.dart';
import 'package:another_iptv_player/widgets/live_stream_preview_widget.dart';
import 'package:another_iptv_player/widgets/pip_overlay_widget.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/hidden_items_controller.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:uuid/uuid.dart';
import '../../models/content_type.dart';
import '../../services/event_bus.dart';

class XtreamCodeHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const XtreamCodeHomeScreen({super.key, required this.playlist});

  @override
  State<XtreamCodeHomeScreen> createState() => _XtreamCodeHomeScreenState();
}

class _XtreamCodeHomeScreenState extends State<XtreamCodeHomeScreen> {
  late XtreamCodeHomeController _controller;
  late FavoritesController _favoritesController;
  late HiddenItemsController _hiddenItemsController;
  static const double _desktopBreakpoint = 900.0;
  static const double _largeScreenBreakpoint = 1200.0;
  static const double _defaultNavWidth = 80.0;
  static const double _largeNavWidth = 100.0;
  static const double _defaultItemHeight = 60.0;
  static const double _largeItemHeight = 70.0;
  static const double _defaultIconSize = 24.0;
  static const double _largeIconSize = 28.0;
  static const double _defaultFontSize = 10.0;
  static const double _largeFontSize = 11.0;
  int? _hoveredIndex;

  // Preview state
  ContentItem? _previewItem;
  final PipManager _pipManager = PipManager();
  int _lastIndex = 2; // Track last index for navigation events

  @override
  void initState() {
    super.initState();
    _initializeController();
    _favoritesController = FavoritesController();
    _favoritesController.loadFavorites();
    _hiddenItemsController = HiddenItemsController();
    _hiddenItemsController.loadHiddenItems();
    // Listen for controller changes to emit navigation events
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_controller.currentIndex != _lastIndex) {
      _lastIndex = _controller.currentIndex;
      // Emit navigation event for PiP handling
      EventBus().emit('navigation_change', _indexToScreenName(_controller.currentIndex));
    }
  }

  String _indexToScreenName(int index) {
    switch (index) {
      case 0:
        return 'history';
      case 1:
        return 'favorites';
      case 2:
        return 'live_streams';
      case 3:
        return 'tv_guide';
      case 4:
        return 'movies';
      case 5:
        return 'series';
      case 6:
        return 'settings';
      default:
        return 'unknown';
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _favoritesController.dispose();
    _hiddenItemsController.dispose();
    super.dispose();
  }

  void _initializeController() {
    // Ensure currentPlaylist is always set when viewing this screen
    AppState.currentPlaylist = widget.playlist;

    final repository = IptvRepository(
      ApiConfig(
        baseUrl: widget.playlist.url!,
        username: widget.playlist.username!,
        password: widget.playlist.password!,
      ),
      widget.playlist.id,
    );
    AppState.xtreamCodeRepository = repository;
    _controller = XtreamCodeHomeController(false);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _controller),
        ChangeNotifierProvider.value(value: _favoritesController),
        ChangeNotifierProvider.value(value: _hiddenItemsController),
      ],
      child: Consumer3<XtreamCodeHomeController, FavoritesController, HiddenItemsController>(
        builder: (context, controller, favoritesController, hiddenItemsController, child) =>
            _buildMainContent(context, controller, favoritesController, hiddenItemsController),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    XtreamCodeHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    if (controller.isLoading) {
      return _buildLoadingScreen(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktopLayout(context, controller, constraints, favoritesController, hiddenItemsController);
        }
        return _buildMobileLayout(context, controller, favoritesController, hiddenItemsController);
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.loc.loading_playlists),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    XtreamCodeHomeController controller,
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
    XtreamCodeHomeController controller,
    BoxConstraints constraints,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    return Scaffold(
      body: Row(
        children: [
          _buildDesktopNavigationBar(context, controller, constraints),
          Expanded(child: _buildPageView(controller, favoritesController, hiddenItemsController)),
        ],
      ),
    );
  }

  Widget _buildPageView(
    XtreamCodeHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    return IndexedStack(
      index: controller.currentIndex,
      children: _buildPages(controller, favoritesController, hiddenItemsController),
    );
  }

  List<Widget> _buildPages(
    XtreamCodeHomeController controller,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    final favoriteStreamIds = favoritesController.favorites.map((f) => f.streamId).toSet();
    final hiddenStreamIds = hiddenItemsController.hiddenStreamIds;
    return [
      WatchHistoryScreen(
        key: ValueKey('watch_history_${controller.currentIndex}'),
        playlistId: widget.playlist.id,
      ),
      FavoritesScreen(
        key: ValueKey('favorites_${controller.currentIndex}'),
        playlistId: widget.playlist.id,
      ),
      _buildContentPage(
        controller.visibleLiveCategories,
        ContentType.liveStream,
        controller,
        favoriteStreamIds,
        hiddenStreamIds,
        favoritesController,
        hiddenItemsController,
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
      ),
      _buildContentPage(
        controller.visibleSeriesCategories,
        ContentType.series,
        controller,
        favoriteStreamIds,
        hiddenStreamIds,
        favoritesController,
        hiddenItemsController,
      ),
      XtreamCodePlaylistSettingsScreen(playlist: widget.playlist),
    ];
  }

  Widget _buildContentPage(
    List<CategoryViewModel> categories,
    ContentType contentType,
    XtreamCodeHomeController controller,
    Set<String> favoriteStreamIds,
    Set<String> hiddenStreamIds,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    final isLiveStreamPage = contentType == ContentType.liveStream;

    return Scaffold(
      appBar: _buildAppBar(context, controller, contentType),
      body: Stack(
        children: [
          Column(
            children: [
              // Live stream preview panel (only for live streams page on desktop)
              if (isLiveStreamPage && ResponsiveHelper.isDesktopOrTV(context))
                LiveStreamPreviewWidget(
                  height: 220,
                  onPreviewStarted: () {
                    // Preview started
                  },
                  onPreviewClosed: () {
                    setState(() => _previewItem = null);
                  },
                ),
              // Main category list
              Expanded(
                child: _buildCategoryList(
                  categories,
                  contentType,
                  favoriteStreamIds,
                  hiddenStreamIds,
                  favoritesController,
                  hiddenItemsController,
                ),
              ),
            ],
          ),
          // PiP overlay (shows when navigating away from preview source)
          if (!isLiveStreamPage)
            PipOverlayWidget(
              currentScreen: _getScreenName(contentType),
            ),
        ],
      ),
    );
  }

  String _getScreenName(ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return 'live_streams';
      case ContentType.vod:
        return 'movies';
      case ContentType.series:
        return 'series';
    }
  }

  AppBar _buildAppBar(
    BuildContext context,
    XtreamCodeHomeController controller,
    ContentType contentType,
  ) {
    if (ResponsiveHelper.isDesktopOrTV(context)) {
      return _buildDesktopAppBar(context, contentType);
    }
    return _buildMobileAppBar(context, controller, contentType);
  }

  AppBar _buildDesktopAppBar(BuildContext context, ContentType contentType) {
    return AppBar(
      title: SelectableText(
        _getDesktopTitle(context, contentType),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => _showGlobalSearch(context),
        ),
      ],
    );
  }

  String _getDesktopTitle(BuildContext context, ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return context.loc.live_streams;
      case ContentType.vod:
        return context.loc.movies;
      case ContentType.series:
        return context.loc.series_plural;
    }
  }

  AppBar _buildMobileAppBar(
    BuildContext context,
    XtreamCodeHomeController controller,
    ContentType contentType,
  ) {
    return AppBar(
      title: SelectableText(
        controller.getPageTitle(context),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => _showGlobalSearch(context),
        ),
      ],
    );
  }

  void _navigateToSearch(BuildContext context, ContentType contentType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(contentType: contentType),
      ),
    );
  }

  void _showGlobalSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: GlobalSearchDelegate(
        onResultSelected: (result) {
          // Navigate to the appropriate panel
          _controller.onNavigationTap(result.panelIndex);
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

  Widget _buildCategoryList(
    List<CategoryViewModel> categories,
    ContentType contentType,
    Set<String> favoriteStreamIds,
    Set<String> hiddenStreamIds,
    FavoritesController favoritesController,
    HiddenItemsController hiddenItemsController,
  ) {
    return ListView.builder(
      shrinkWrap: true,
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
    // Filter out hidden items from display
    final filteredCategory = CategoryViewModel(
      category: category.category,
      contentItems: category.contentItems
          .where((item) => !hiddenStreamIds.contains(item.id))
          .toList(),
    );

    return CategorySection(
      category: filteredCategory,
      cardWidth: ResponsiveHelper.getCardWidth(context),
      cardHeight: ResponsiveHelper.getCardHeight(context),
      onSeeAllTap: () => _navigateToCategoryDetail(category),
      onContentTap: (content) => navigateByContentType(context, content),
      favoriteStreamIds: favoriteStreamIds,
      hiddenStreamIds: hiddenStreamIds,
      onToggleFavorite: (item) => _toggleFavorite(context, item, favoritesController),
      onToggleHidden: (item) => _toggleHidden(context, item, hiddenItemsController),
      onHideCategory: (categoryId, categoryName) => _hideCategory(context, categoryId, categoryName),
    );
  }

  Future<void> _hideCategory(BuildContext context, String categoryId, String categoryName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hide Category'),
        content: Text('Are you sure you want to hide "$categoryName"? This will hide all items in this category. You can unhide it from Settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Hide'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.hideCategory(categoryId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "$categoryName" hidden.')),
        );
      }
    }
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
      final success = await controller.addFavoriteFromData(favorite);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? context.loc.added_to_favorites : 'Error: ${controller.error ?? "unknown"}')),
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
          // ignore: deprecated_member_use_from_same_package
          SnackBar(content: Text(context.loc.unmarked_as_watched)),
        );
      }
    } else {
      await controller.hideItem(item);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // ignore: deprecated_member_use_from_same_package
          SnackBar(content: Text(context.loc.marked_as_watched)),
        );
      }
    }
  }

  void _navigateToCategoryDetail(CategoryViewModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(category: category),
      ),
    );
  }

  Widget _buildBottomNavigationBar(
    BuildContext context,
    XtreamCodeHomeController controller,
  ) {
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
        items: _buildBottomNavigationItems(context),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavigationItems(
    BuildContext context,
  ) {
    return _getNavigationItems(context).map((item) {
      return BottomNavigationBarItem(icon: Icon(item.icon), label: item.label);
    }).toList();
  }

  Widget _buildDesktopNavigationBar(
    BuildContext context,
    XtreamCodeHomeController controller,
    BoxConstraints constraints,
  ) {
    final navWidth = _getNavigationWidth(constraints.maxWidth);
    return Container(
      width: navWidth,
      decoration: _getNavigationBarDecoration(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDesktopNavigationItems(context, controller, constraints),
        ],
      ),
    );
  }

  Widget _buildDesktopNavigationItems(
    BuildContext context,
    XtreamCodeHomeController controller,
    BoxConstraints constraints,
  ) {
    final items = _getNavigationItems(context);
    final sizes = _getNavigationSizes(constraints.maxWidth);
    return Column(
      children: items.map((item) {
        final isSelected = controller.currentIndex == item.index;
        return _buildNavigationItem(
          context,
          item,
          isSelected,
          sizes,
          () => controller.onNavigationTap(item.index),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context,
    NavigationItem item,
    bool isSelected,
    NavigationSizes sizes,
    VoidCallback onTap,
  ) {
    return _XtreamDesktopNavItem(
      icon: item.icon,
      label: item.label,
      isSelected: isSelected,
      sizes: sizes,
      onTap: onTap,
    );
  }

  BoxDecoration _getNavigationBarDecoration(BuildContext context) {
    return const BoxDecoration(
      color: AppThemes.netflixBlack,
      border: Border(
        right: BorderSide(color: AppThemes.dividerGrey, width: 0.5),
      ),
    );
  }

  double _getNavigationWidth(double screenWidth) {
    return screenWidth >= _largeScreenBreakpoint
        ? _largeNavWidth
        : _defaultNavWidth;
  }

  NavigationSizes _getNavigationSizes(double screenWidth) {
    final isLargeScreen = screenWidth >= _largeScreenBreakpoint;
    return NavigationSizes(
      itemHeight: isLargeScreen ? _largeItemHeight : _defaultItemHeight,
      iconSize: isLargeScreen ? _largeIconSize : _defaultIconSize,
      fontSize: isLargeScreen ? _largeFontSize : _defaultFontSize,
    );
  }

  Color _getIconColor(BuildContext context, bool isSelected) {
    return isSelected ? AppThemes.textWhite : AppThemes.iconGrey;
  }

  Color _getTextColor(BuildContext context, bool isSelected) {
    return isSelected ? AppThemes.textWhite : AppThemes.iconGrey;
  }

  List<NavigationItem> _getNavigationItems(BuildContext context) {
    return [
      NavigationItem(icon: Icons.history, label: context.loc.history, index: 0),
      NavigationItem(icon: Icons.favorite, label: context.loc.favorites, index: 1),
      NavigationItem(icon: Icons.live_tv, label: context.loc.live, index: 2),
      NavigationItem(icon: Icons.calendar_view_day, label: 'Guide', index: 3),
      NavigationItem(
        icon: Icons.movie_outlined,
        label: context.loc.movie,
        index: 4,
      ),
      NavigationItem(
        icon: Icons.tv,
        label: context.loc.series_plural,
        index: 5,
      ),
      NavigationItem(
        icon: Icons.settings,
        label: context.loc.settings,
        index: 6,
      ),
    ];
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final int index;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class NavigationSizes {
  final double itemHeight;
  final double iconSize;
  final double fontSize;

  const NavigationSizes({
    required this.itemHeight,
    required this.iconSize,
    required this.fontSize,
  });
}

/// Desktop navigation item with hover effects
class _XtreamDesktopNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final NavigationSizes sizes;
  final VoidCallback onTap;

  const _XtreamDesktopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.sizes,
    required this.onTap,
  });

  @override
  State<_XtreamDesktopNavItem> createState() => _XtreamDesktopNavItemState();
}

class _XtreamDesktopNavItemState extends State<_XtreamDesktopNavItem> {
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
          width: double.infinity,
          height: widget.sizes.itemHeight,
          margin: const EdgeInsets.symmetric(vertical: 2),
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
                size: widget.sizes.iconSize,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? AppThemes.textWhite : AppThemes.iconGrey,
                  fontSize: widget.sizes.fontSize,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
