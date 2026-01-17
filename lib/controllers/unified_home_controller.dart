import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/view_state.dart';
import 'package:another_iptv_player/repositories/unified_content_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

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

  // Hidden category IDs
  Set<String> _hiddenCategoryIds = {};

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

  UnifiedHomeController() {
    _pageController = PageController();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await loadHiddenCategories();
    await loadAllContent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Load hidden categories from preferences
  Future<void> loadHiddenCategories() async {
    final hidden = await UserPreferences.getHiddenCategories();
    _hiddenCategoryIds = hidden.toSet();
    notifyListeners();
  }

  // Hide a category
  Future<void> hideCategory(String categoryId) async {
    _hiddenCategoryIds.add(categoryId);
    await UserPreferences.hideCategory(categoryId);
    notifyListeners();
  }

  // Unhide a category
  Future<void> unhideCategory(String categoryId) async {
    _hiddenCategoryIds.remove(categoryId);
    await UserPreferences.unhideCategory(categoryId);
    notifyListeners();
  }

  // Visible categories (filtered by hidden)
  List<CategoryViewModel> get visibleLiveCategories => _liveCategories
      .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
      .toList();

  List<CategoryViewModel> get visibleMovieCategories => _movieCategories
      .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
      .toList();

  List<CategoryViewModel> get visibleSeriesCategories => _seriesCategories
      .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
      .toList();

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
        return 'Movies';
      case 4:
        return 'Series';
      case 5:
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

      _setViewState(ViewState.success);
      debugPrint('UnifiedHomeController: Loaded ${_liveCategories.length} live, ${_movieCategories.length} movie, ${_seriesCategories.length} series categories');
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
