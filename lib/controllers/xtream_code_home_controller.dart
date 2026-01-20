import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/view_state.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/category_config_service.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';
import '../repositories/user_preferences.dart';
import '../screens/xtream-codes/xtream_code_data_loader_screen.dart';

class XtreamCodeHomeController extends ChangeNotifier {
  late PageController _pageController;
  final IptvRepository _repository = AppState.xtreamCodeRepository!;
  String? _errorMessage;
  ViewState _viewState = ViewState.idle;

  int _currentIndex = 2; // Default to Live Streams, will be updated from preferences
  final bool _isLoading = false;

  final List<CategoryViewModel> _liveCategories = [];
  final List<CategoryViewModel> _movieCategories = [];
  final List<CategoryViewModel> _seriesCategories = [];

  // --- Category hidden ---
  Set<String> _hiddenCategoryIds = {};

  // Getter for hidden category IDs
  Set<String> get hiddenCategoryIds => _hiddenCategoryIds;

  // Load hidden categories from preferences
  Future<void> loadHiddenCategories() async {
    final hidden = await UserPreferences.getHiddenCategories();
    _hiddenCategoryIds = hidden.toSet();
    notifyListeners();
  }

  // Hide a category and update UI immediately
  Future<void> hideCategory(String categoryId) async {
    _hiddenCategoryIds.add(categoryId);
    await UserPreferences.hideCategory(categoryId);
    notifyListeners();
  }

  // Unhide a category and update UI immediately
  Future<void> unhideCategory(String categoryId) async {
    _hiddenCategoryIds.remove(categoryId);
    await UserPreferences.unhideCategory(categoryId);
    notifyListeners();
  }

  // Parental control service for filtering content
  final ParentalControlService _parentalService = ParentalControlService();

  // Getters for visible categories (filtered by hidden, parental controls, then merged/ordered)
  List<CategoryViewModel> get visibleLiveCategories {
    final filtered = _liveCategories
        .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
        .where((c) => !_parentalService.shouldHideCategory(
            c.category.categoryId, c.category.categoryName))
        .toList();
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) return _applyContentFiltering(filtered);
    return _applyContentFiltering(CategoryConfigService().applyConfig(
      playlistId: playlistId,
      type: CategoryType.live,
      categories: filtered,
    ));
  }

  List<CategoryViewModel> get visibleMovieCategories {
    final filtered = _movieCategories
        .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
        .where((c) => !_parentalService.shouldHideCategory(
            c.category.categoryId, c.category.categoryName))
        .toList();
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) return _applyContentFiltering(filtered);
    return _applyContentFiltering(CategoryConfigService().applyConfig(
      playlistId: playlistId,
      type: CategoryType.vod,
      categories: filtered,
    ));
  }

  List<CategoryViewModel> get visibleSeriesCategories {
    final filtered = _seriesCategories
        .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
        .where((c) => !_parentalService.shouldHideCategory(
            c.category.categoryId, c.category.categoryName))
        .toList();
    final playlistId = AppState.currentPlaylist?.id;
    if (playlistId == null) return _applyContentFiltering(filtered);
    return _applyContentFiltering(CategoryConfigService().applyConfig(
      playlistId: playlistId,
      type: CategoryType.series,
      categories: filtered,
    ));
  }

  // Filter content items within categories based on parental controls
  List<CategoryViewModel> _applyContentFiltering(List<CategoryViewModel> categories) {
    return categories.map((category) {
      final filteredItems = _parentalService.filterContent<ContentItem>(
        category.contentItems,
        getId: (item) => item.id,
        getName: (item) => item.name,
        getCategoryId: (item) => category.category.categoryId,
        getCategoryName: (item) => category.category.categoryName,
      );
      return CategoryViewModel(
        category: category.category,
        contentItems: filteredItems,
      );
    }).where((category) => category.contentItems.isNotEmpty).toList();
  }

  // Getters
  PageController get pageController => _pageController;

  int get currentIndex => _currentIndex;

  bool get isLoading => _isLoading;

  List<CategoryViewModel>? get liveCategories => _liveCategories;

  List<CategoryViewModel> get movieCategories => _movieCategories;

  List<CategoryViewModel> get seriesCategories => _seriesCategories;

  XtreamCodeHomeController(bool all) {
    _pageController = PageController();
    _initializeData(all);
  }

  Future<void> _initializeData(bool all) async {
    // Load default panel preference
    await _loadDefaultPanel();
    // Initialize parental controls
    await _parentalService.initialize();
    await loadHiddenCategories();
    await _loadCategories(all);
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

  void onNavigationTap(int index) {
    _currentIndex = index;
    notifyListeners();

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 300),
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
        return context.loc.history;
      case 1:
        return context.loc.favorites;
      case 2:
        return context.loc.live_streams;
      case 3:
        return 'TV Guide';
      case 4:
        return context.loc.movies;
      case 5:
        return context.loc.series_plural;
      case 6:
        return context.loc.settings;
      default:
        return 'Another IPTV Player';
    }
  }

  void _setViewState(ViewState state) {
    _viewState = state;
    if (state != ViewState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  Future<void> _loadCategories(bool all) async {
    try {
      var liveCategories = await _repository.getLiveCategories();
      if (liveCategories != null && liveCategories.isNotEmpty) {
        for (var liveCategory in liveCategories) {
          var liveStreams = await _repository.getLiveChannelsByCategoryId(
            categoryId: liveCategory.categoryId,
            top: 10,
          );

          if (liveStreams == null || liveStreams.isEmpty) continue;

          final playlistId = AppState.currentPlaylist?.id;
          var categoryViewModel = CategoryViewModel(
            category: liveCategory,
            contentItems: liveStreams
                .map(
                  (x) => ContentItem(
                x.streamId,
                x.name,
                x.streamIcon,
                ContentType.liveStream,
                liveStream: x,
                sourcePlaylistId: playlistId,
                sourceType: PlaylistType.xtream,
              ),
            )
                .toList(),
          );
          if (!all) {
            if (!await UserPreferences.getHiddenCategory(
              liveCategory.categoryId,
            )) {
              _liveCategories.add(categoryViewModel);
            }
          } else {
            _liveCategories.add(categoryViewModel);
          }
        }
      }

      var movieCategories = await _repository.getVodCategories();
      if (movieCategories != null && movieCategories.isNotEmpty) {
        for (var movieCategory in movieCategories) {
          var movies = await _repository.getMovies(
            categoryId: movieCategory.categoryId,
            top: 10,
          );

          if (movies == null || movies.isEmpty) {
            continue;
          }

          final playlistId = AppState.currentPlaylist?.id;
          var categoryViewModel = CategoryViewModel(
            category: movieCategory,
            contentItems: movies
                .map(
                  (x) => ContentItem(
                x.streamId,
                x.name,
                x.streamIcon,
                ContentType.vod,
                containerExtension: x.containerExtension,
                vodStream: x,
                sourcePlaylistId: playlistId,
                sourceType: PlaylistType.xtream,
              ),
            )
                .toList(),
          );
          if (!all) {
            if (!await UserPreferences.getHiddenCategory(
              movieCategory.categoryId,
            )) {
              _movieCategories.add(categoryViewModel);
            }
          } else {
            _movieCategories.add(categoryViewModel);
          }
        }
      }

      var seriesCategories = await _repository.getSeriesCategories();
      if (seriesCategories != null && seriesCategories.isNotEmpty) {
        for (var seriesCategory in seriesCategories) {
          var series = await _repository.getSeries(
            categoryId: seriesCategory.categoryId,
            top: 10,
          );

          if (series == null || series.isEmpty) {
            continue;
          }

          final playlistId = AppState.currentPlaylist?.id;
          var categoryViewModel = CategoryViewModel(
            category: seriesCategory,
            contentItems: series
                .map(
                  (x) => ContentItem(
                x.seriesId,
                x.name,
                x.cover ?? '',
                ContentType.series,
                seriesStream: x,
                sourcePlaylistId: playlistId,
                sourceType: PlaylistType.xtream,
              ),
            )
                .toList(),
          );
          if (!all) {
            if (!await UserPreferences.getHiddenCategory(
              seriesCategory.categoryId,
            )) {
              _seriesCategories.add(categoryViewModel);
            }
          } else {
            _seriesCategories.add(categoryViewModel);
          }
        }
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint(st.toString());
      _errorMessage = 'Kategoriler yüklenemedi: $e';
      _setViewState(ViewState.error);
    }
  }

  refreshAllData(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => XtreamCodeDataLoaderScreen(
          playlist: AppState.currentPlaylist!,
          refreshAll: true,
        ),
      ),
    );
  }
}
