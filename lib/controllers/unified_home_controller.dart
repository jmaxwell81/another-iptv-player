import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/view_state.dart';
import 'package:another_iptv_player/repositories/unified_content_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';

/// Controller for the unified home screen (combined mode)
class UnifiedHomeController extends ChangeNotifier {
  late PageController _pageController;
  final UnifiedContentRepository _repository = UnifiedContentRepository();

  String? _errorMessage;
  ViewState _viewState = ViewState.idle;

  int _currentIndex = 0;
  bool _isLoading = false;

  final List<CategoryViewModel> _liveCategories = [];
  final List<CategoryViewModel> _movieCategories = [];
  final List<CategoryViewModel> _seriesCategories = [];

  // Hidden category IDs and names (for cross-source consistency)
  Set<String> _hiddenCategoryIds = {};
  Set<String> _hiddenCategoryNames = {};

  // Source filtering - per content type
  // null means "All Sources", otherwise contains selected playlist IDs
  Set<String>? _liveSourceFilter;
  Set<String>? _movieSourceFilter;
  Set<String>? _seriesSourceFilter;

  // Getters
  PageController get pageController => _pageController;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ViewState get viewState => _viewState;

  List<CategoryViewModel> get liveCategories => _liveCategories;
  List<CategoryViewModel> get movieCategories => _movieCategories;
  List<CategoryViewModel> get seriesCategories => _seriesCategories;

  // Hidden category management
  Set<String> get hiddenCategoryIds => _hiddenCategoryIds;

  // Source filter getters
  Set<String>? get liveSourceFilter => _liveSourceFilter;
  Set<String>? get movieSourceFilter => _movieSourceFilter;
  Set<String>? get seriesSourceFilter => _seriesSourceFilter;

  /// Get all available source names for filtering
  Map<String, String> get availableSources {
    final sources = <String, String>{};
    for (final entry in AppState.activePlaylists.entries) {
      sources[entry.key] = entry.value.name;
    }
    return sources;
  }

  UnifiedHomeController() {
    _pageController = PageController();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadDefaultPanel();
    await loadHiddenCategories();
    await loadAllContent();
  }

  Future<void> _loadDefaultPanel() async {
    final defaultPanel = await UserPreferences.getDefaultPanel();
    _currentIndex = _panelNameToIndex(defaultPanel);

    // Jump PageController to the correct page after loading preference
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
    } else {
      // If PageController doesn't have clients yet, recreate it with initial page
      _pageController = PageController(initialPage: _currentIndex);
    }

    notifyListeners();
  }

  int _panelNameToIndex(String panelName) {
    switch (panelName.toLowerCase()) {
      case 'history':
        return 0;
      case 'favorites':
        return 1;
      case 'live':
        return 2;
      case 'guide':
        return 3;
      case 'movies':
        return 4;
      case 'series':
        return 5;
      case 'settings':
        return 6;
      default:
        return 2; // Default to Live Streams
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Load hidden categories from preferences (both IDs and names)
  Future<void> loadHiddenCategories() async {
    final hiddenIds = await UserPreferences.getHiddenCategories();
    final hiddenNames = await UserPreferences.getHiddenCategoryNames();

    _hiddenCategoryIds = hiddenIds.toSet();
    _hiddenCategoryNames = hiddenNames.toSet();

    debugPrint('UnifiedHomeController: Loaded ${_hiddenCategoryIds.length} hidden IDs, ${_hiddenCategoryNames.length} hidden names');
    notifyListeners();
  }

  /// Migrate old hidden categories (ID-only) to include names
  /// This should be called after categories are loaded
  Future<void> _migrateHiddenCategoryNames() async {
    if (_hiddenCategoryIds.isEmpty) return;

    final allCategories = [..._liveCategories, ..._movieCategories, ..._seriesCategories];
    bool needsSave = false;

    // First pass: for non-merged categories, if hidden by ID, add the name
    for (final cat in allCategories) {
      final categoryId = cat.category.categoryId;
      final categoryName = cat.category.categoryName;
      final normalizedName = categoryName.toLowerCase().trim();

      // Skip merged categories in first pass
      if (categoryId.startsWith('merged_')) continue;

      // If this category is hidden by ID but name isn't in the set, add it
      if (_hiddenCategoryIds.contains(categoryId) && !_hiddenCategoryNames.contains(normalizedName)) {
        _hiddenCategoryNames.add(normalizedName);
        needsSave = true;
        debugPrint('UnifiedHomeController: Migrating hidden category name: $categoryName (ID: $categoryId)');
      }
    }

    // Second pass: for merged categories, check if any of the source categories were hidden
    // by looking at the content items and their original category IDs
    for (final cat in allCategories) {
      final categoryId = cat.category.categoryId;
      if (!categoryId.startsWith('merged_')) continue;

      final categoryName = cat.category.categoryName;
      final normalizedName = categoryName.toLowerCase().trim();

      // Check if any content item in this merged category came from a hidden category
      for (final contentItem in cat.contentItems) {
        // Get categoryId from the underlying stream object
        String? sourceCategoryId;
        if (contentItem.liveStream != null) {
          sourceCategoryId = contentItem.liveStream!.categoryId;
        } else if (contentItem.vodStream != null) {
          sourceCategoryId = contentItem.vodStream!.categoryId;
        } else if (contentItem.seriesStream != null) {
          sourceCategoryId = contentItem.seriesStream!.categoryId;
        } else if (contentItem.m3uItem != null) {
          sourceCategoryId = contentItem.m3uItem!.categoryId;
        }

        if (sourceCategoryId != null && _hiddenCategoryIds.contains(sourceCategoryId)) {
          // This merged category contains content from a hidden source category
          // Add the merged category's name to hidden names
          if (!_hiddenCategoryNames.contains(normalizedName)) {
            _hiddenCategoryNames.add(normalizedName);
            needsSave = true;
            debugPrint('UnifiedHomeController: Migrating merged category name: $categoryName (source ID: $sourceCategoryId)');
          }
          break; // Only need to find one match
        }
      }
    }

    if (needsSave) {
      await UserPreferences.setHiddenCategoryNames(_hiddenCategoryNames.toList());
      debugPrint('UnifiedHomeController: Saved ${_hiddenCategoryNames.length} hidden category names after migration');
      notifyListeners();
    }
  }

  // Hide a category (also adds its name for cross-source hiding)
  Future<void> hideCategory(String categoryId, String categoryName) async {
    _hiddenCategoryIds.add(categoryId);
    final normalizedName = categoryName.toLowerCase().trim();
    _hiddenCategoryNames.add(normalizedName);

    // Save both ID and name to preferences
    await UserPreferences.hideCategoryWithName(categoryId, categoryName);

    notifyListeners();
  }

  // Unhide a category
  Future<void> unhideCategory(String categoryId, String categoryName) async {
    _hiddenCategoryIds.remove(categoryId);
    final normalizedName = categoryName.toLowerCase().trim();
    _hiddenCategoryNames.remove(normalizedName);

    // Remove both ID and name from preferences
    await UserPreferences.unhideCategoryWithName(categoryId, categoryName);

    notifyListeners();
  }

  // Visible categories (filtered by hidden and source filter)
  List<CategoryViewModel> get visibleLiveCategories => _liveCategories
      .where((c) => !_isCategoryHidden(c) && _matchesSourceFilter(c, _liveSourceFilter))
      .toList();

  List<CategoryViewModel> get visibleMovieCategories => _movieCategories
      .where((c) => !_isCategoryHidden(c) && _matchesSourceFilter(c, _movieSourceFilter))
      .toList();

  List<CategoryViewModel> get visibleSeriesCategories => _seriesCategories
      .where((c) => !_isCategoryHidden(c) && _matchesSourceFilter(c, _seriesSourceFilter))
      .toList();

  /// Check if a category is hidden (by ID or by normalized name)
  bool _isCategoryHidden(CategoryViewModel category) {
    // Check by exact ID match
    if (_hiddenCategoryIds.contains(category.category.categoryId)) {
      return true;
    }
    // Check by normalized name match (for cross-source consistency)
    final normalizedName = category.category.categoryName.toLowerCase().trim();
    if (_hiddenCategoryNames.contains(normalizedName)) {
      return true;
    }
    return false;
  }

  /// Check if a category matches the source filter
  bool _matchesSourceFilter(CategoryViewModel category, Set<String>? sourceFilter) {
    // null filter means "All Sources"
    if (sourceFilter == null || sourceFilter.isEmpty) {
      return true;
    }
    // Check if category's playlist matches any selected source
    final playlistId = category.category.playlistId;
    if (playlistId == 'unified') {
      // Merged category - show if any of the merged sources are selected
      // For now, show merged categories when any source is selected
      return true;
    }
    return sourceFilter.contains(playlistId);
  }

  /// Set source filter for Live content
  void setLiveSourceFilter(Set<String>? sources) {
    _liveSourceFilter = sources;
    notifyListeners();
  }

  /// Set source filter for Movie content
  void setMovieSourceFilter(Set<String>? sources) {
    _movieSourceFilter = sources;
    notifyListeners();
  }

  /// Set source filter for Series content
  void setSeriesSourceFilter(Set<String>? sources) {
    _seriesSourceFilter = sources;
    notifyListeners();
  }

  /// Toggle a single source in the filter for a content type
  void toggleSourceFilter(CategoryType type, String playlistId) {
    Set<String>? currentFilter;
    switch (type) {
      case CategoryType.live:
        currentFilter = _liveSourceFilter;
        break;
      case CategoryType.vod:
        currentFilter = _movieSourceFilter;
        break;
      case CategoryType.series:
        currentFilter = _seriesSourceFilter;
        break;
    }

    // If currently "All Sources", create filter with just this source
    if (currentFilter == null) {
      currentFilter = {playlistId};
    } else if (currentFilter.contains(playlistId)) {
      // Remove this source
      currentFilter = Set.from(currentFilter)..remove(playlistId);
      // If empty, revert to "All Sources"
      if (currentFilter.isEmpty) {
        currentFilter = null;
      }
    } else {
      // Add this source
      currentFilter = Set.from(currentFilter)..add(playlistId);
    }

    switch (type) {
      case CategoryType.live:
        _liveSourceFilter = currentFilter;
        break;
      case CategoryType.vod:
        _movieSourceFilter = currentFilter;
        break;
      case CategoryType.series:
        _seriesSourceFilter = currentFilter;
        break;
    }
    notifyListeners();
  }

  /// Reset source filter to "All Sources" for a content type
  void resetSourceFilter(CategoryType type) {
    switch (type) {
      case CategoryType.live:
        _liveSourceFilter = null;
        break;
      case CategoryType.vod:
        _movieSourceFilter = null;
        break;
      case CategoryType.series:
        _seriesSourceFilter = null;
        break;
    }
    notifyListeners();
  }

  /// Get the current source filter for a content type
  Set<String>? getSourceFilter(CategoryType type) {
    switch (type) {
      case CategoryType.live:
        return _liveSourceFilter;
      case CategoryType.vod:
        return _movieSourceFilter;
      case CategoryType.series:
        return _seriesSourceFilter;
    }
  }

  void onNavigationTap(int index) {
    _currentIndex = index;
    notifyListeners();

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void onPageChanged(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  String getPageTitle(BuildContext context) {
    switch (currentIndex) {
      case 0:
        return 'History';
      case 1:
        return 'Favorites';
      case 2:
        return 'Live Streams';
      case 3:
        return 'TV Guide';
      case 4:
        return 'Movies';
      case 5:
        return 'Series';
      case 6:
        return 'Settings';
      default:
        return 'Unified Player';
    }
  }

  void _setViewState(ViewState state) {
    _viewState = state;
    if (state != ViewState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// Load all content from all active playlists
  Future<void> loadAllContent() async {
    _isLoading = true;
    _setViewState(ViewState.loading);
    notifyListeners();

    try {
      // Load all category types in parallel
      final results = await Future.wait([
        _repository.getUnifiedCategories(type: CategoryType.live),
        _repository.getUnifiedCategories(type: CategoryType.vod),
        _repository.getUnifiedCategories(type: CategoryType.series),
      ]);

      _liveCategories.clear();
      _liveCategories.addAll(results[0]);

      _movieCategories.clear();
      _movieCategories.addAll(results[1]);

      _seriesCategories.clear();
      _seriesCategories.addAll(results[2]);

      debugPrint('UnifiedHomeController: Loaded ${_liveCategories.length} live, ${_movieCategories.length} movie, ${_seriesCategories.length} series categories');

      // Migrate old hidden categories (ID-only) to include names for cross-source matching
      await _migrateHiddenCategoryNames();

      _setViewState(ViewState.success);
    } catch (e, st) {
      debugPrint('UnifiedHomeController: Error loading content: $e');
      debugPrint(st.toString());
      _errorMessage = 'Failed to load content: $e';
      _setViewState(ViewState.error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh all content
  Future<void> refreshAllContent() async {
    await loadAllContent();
  }
}
