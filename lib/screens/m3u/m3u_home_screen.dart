import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/screens/m3u/m3u_items_screen.dart';
import 'package:another_iptv_player/screens/m3u/m3u_playlist_settings_screen.dart';
import 'package:another_iptv_player/screens/tv_guide/tv_guide_screen.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/m3u_home_controller.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/screens/category_detail_screen.dart';
import 'package:another_iptv_player/widgets/category_section.dart';
import 'package:another_iptv_player/widgets/global_search_delegate.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';

import '../../services/app_state.dart';
import '../../controllers/favorites_controller.dart';
import '../../repositories/user_preferences.dart';
import '../watch_history_screen.dart';
import '../favorites/favorites_screen.dart';

class M3UHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const M3UHomeScreen({super.key, required this.playlist});

  @override
  State<M3UHomeScreen> createState() => _M3UHomeScreenState();
}

class _M3UHomeScreenState extends State<M3UHomeScreen> {
  late M3UHomeController _controller;
  late FavoritesController _favoritesController;

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

  // Categories that should show only favorites
  Set<String> _favoritesOnlyCategories = {};

  // Pinned categories (appear at top)
  List<String> _pinnedCategories = [];

  // Demoted categories (appear at bottom)
  List<String> _demotedCategories = [];

  @override
  void initState() {
    super.initState();
    _initializeController();
    _favoritesController = FavoritesController();
    _favoritesController.loadFavorites();
    _loadFavoritesOnlyCategories();
    _loadPinnedCategories();
    _loadDemotedCategories();
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
    final pinned = await UserPreferences.getPinnedCategories();
    if (mounted) {
      setState(() {
        _pinnedCategories = pinned;
      });
    }
  }

  Future<void> _togglePinnedCategory(String categoryId) async {
    if (_pinnedCategories.contains(categoryId)) {
      await UserPreferences.unpinCategory(categoryId);
    } else {
      await UserPreferences.pinCategoryToTop(categoryId);
    }
    await _loadPinnedCategories();
  }

  Future<void> _loadDemotedCategories() async {
    final demoted = await UserPreferences.getDemotedCategories();
    if (mounted) {
      setState(() {
        _demotedCategories = demoted;
      });
    }
  }

  Future<void> _toggleDemotedCategory(String categoryId) async {
    if (_demotedCategories.contains(categoryId)) {
      await UserPreferences.undemoteCategory(categoryId);
    } else {
      await UserPreferences.demoteCategoryToBottom(categoryId);
    }
    await _loadDemotedCategories();
    await _loadPinnedCategories(); // Refresh pinned too since demoting removes from pinned
  }

  /// Sort categories: pinned first, then normal, then demoted
  List<CategoryViewModel> _sortCategoriesWithPinnedFirst(List<CategoryViewModel> categories) {
    if (_pinnedCategories.isEmpty && _demotedCategories.isEmpty) return categories;

    final pinned = <CategoryViewModel>[];
    final normal = <CategoryViewModel>[];
    final demoted = <CategoryViewModel>[];

    // First, find all pinned categories in pinned order
    for (final pinnedId in _pinnedCategories) {
      final cat = categories.firstWhere(
        (c) => c.category.categoryId == pinnedId,
        orElse: () => CategoryViewModel(
          category: Category(categoryId: '', categoryName: '', parentId: 0, playlistId: '', type: CategoryType.live),
          contentItems: [],
        ),
      );
      if (cat.category.categoryId.isNotEmpty) {
        pinned.add(cat);
      }
    }

    // Find all demoted categories in demoted order
    for (final demotedId in _demotedCategories) {
      final cat = categories.firstWhere(
        (c) => c.category.categoryId == demotedId,
        orElse: () => CategoryViewModel(
          category: Category(categoryId: '', categoryName: '', parentId: 0, playlistId: '', type: CategoryType.live),
          contentItems: [],
        ),
      );
      if (cat.category.categoryId.isNotEmpty) {
        demoted.add(cat);
      }
    }

    // Add normal categories (neither pinned nor demoted)
    for (final cat in categories) {
      final catId = cat.category.categoryId;
      if (!_pinnedCategories.contains(catId) && !_demotedCategories.contains(catId)) {
        normal.add(cat);
      }
    }

    return [...pinned, ...normal, ...demoted];
  }

  @override
  void dispose() {
    _controller.dispose();
    _favoritesController.dispose();
    super.dispose();
  }

  void _initializeController() {
    // Ensure currentPlaylist is always set when viewing this screen
    AppState.currentPlaylist = widget.playlist;

    AppState.m3uRepository = M3uRepository();
    _controller = M3UHomeController();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _controller),
        ChangeNotifierProvider.value(value: _favoritesController),
      ],
      child: Consumer<M3UHomeController>(
        builder: (context, controller, child) =>
            _buildMainContent(context, controller),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, M3UHomeController controller) {
    if (controller.isLoading) {
      return _buildLoadingScreen(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktopLayout(context, controller, constraints);
        }

        return _buildMobileLayout(context, controller);
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
            Text(context.loc.loading_lists),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    M3UHomeController controller,
  ) {
    return Scaffold(
      body: _buildPageView(controller),
      bottomNavigationBar: _buildBottomNavigationBar(context, controller),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    M3UHomeController controller,
    BoxConstraints constraints,
  ) {
    return Scaffold(
      body: Row(
        children: [
          _buildDesktopNavigationBar(context, controller, constraints),
          Expanded(child: _buildPageView(controller)),
        ],
      ),
    );
  }

  Widget _buildPageView(M3UHomeController controller) {
    return IndexedStack(
      index: controller.currentIndex,
      children: _buildPages(controller),
    );
  }

  List<Widget> _buildPages(M3UHomeController controller) {
    return [
      WatchHistoryScreen(
        key: ValueKey('watch_history_${controller.currentIndex}'),
        playlistId: widget.playlist.id,
      ),
      FavoritesScreen(
        key: ValueKey('favorites_${controller.currentIndex}'),
        playlistId: widget.playlist.id,
      ),
      M3uItemsScreen(m3uItems: controller.m3uItems!),
      const TvGuideScreen(),
      M3uPlaylistSettingsScreen(playlist: widget.playlist),
    ];
  }

  Widget _buildContentPage(
    List<CategoryViewModel> categories,
    M3UHomeController controller,
  ) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _buildSliverAppBar(context, controller),
      ],
      body: _buildCategoryList(categories),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    M3UHomeController controller,
  ) {
    if (ResponsiveHelper.isDesktopOrTV(context)) {
      return _buildDesktopSliverAppBar(context);
    }

    return _buildMobileSliverAppBar(context, controller);
  }

  SliverAppBar _buildDesktopSliverAppBar(BuildContext context) {
    return SliverAppBar(
      title: SelectableText(
        context.loc.live_streams,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      floating: true,
      snap: true,
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

  SliverAppBar _buildMobileSliverAppBar(
    BuildContext context,
    M3UHomeController controller,
  ) {
    return SliverAppBar(
      title: SelectableText(
        controller.getPageTitle(context),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      floating: true,
      snap: true,
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

  void _showGlobalSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: GlobalSearchDelegate(
        onResultSelected: (result) {
          // M3U has all content in panel 2 (unlike Xtream which has separate panels)
          _controller.onNavigationTap(2);
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

  Widget _buildCategoryList(List<CategoryViewModel> categories) {
    // Sort categories with pinned ones first
    final sortedCategories = _sortCategoriesWithPinnedFirst(categories);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) => _buildCategorySection(sortedCategories[index]),
    );
  }

  Widget _buildCategorySection(CategoryViewModel category) {
    final favoriteStreamIds = _favoritesController.favorites.map((f) => f.streamId).toSet();
    final categoryId = category.category.categoryId;
    final pinnedIndex = _pinnedCategories.indexOf(categoryId);
    return CategorySection(
      category: category,
      cardWidth: ResponsiveHelper.getCardWidth(context),
      cardHeight: ResponsiveHelper.getCardHeight(context),
      onSeeAllTap: () => _navigateToCategoryDetail(category),
      onContentTap: (content) => navigateByContentType(context, content),
      favoriteStreamIds: favoriteStreamIds,
      isFavoritesOnly: _favoritesOnlyCategories.contains(categoryId),
      onToggleFavoritesOnly: _toggleFavoritesOnlyCategory,
      isPinned: pinnedIndex >= 0,
      pinnedIndex: pinnedIndex >= 0 ? pinnedIndex : null,
      onTogglePinned: _togglePinnedCategory,
      onMoveToTop: () async {
        await UserPreferences.pinCategoryToTop(categoryId);
        await _loadPinnedCategories();
      },
      isDemoted: _demotedCategories.contains(categoryId),
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

  Widget _buildBottomNavigationBar(
    BuildContext context,
    M3UHomeController controller,
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
    M3UHomeController controller,
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
    M3UHomeController controller,
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
    return _M3uDesktopNavItem(
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
      NavigationItem(icon: Icons.all_inbox, label: context.loc.all, index: 2),
      NavigationItem(icon: Icons.calendar_view_day, label: 'Guide', index: 3),
      NavigationItem(
        icon: Icons.settings,
        label: context.loc.settings,
        index: 4,
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
class _M3uDesktopNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final NavigationSizes sizes;
  final VoidCallback onTap;

  const _M3uDesktopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.sizes,
    required this.onTap,
  });

  @override
  State<_M3uDesktopNavItem> createState() => _M3uDesktopNavItemState();
}

class _M3uDesktopNavItemState extends State<_M3uDesktopNavItem> {
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
