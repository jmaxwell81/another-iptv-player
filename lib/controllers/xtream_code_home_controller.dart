import 'dart:async';
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
import 'package:another_iptv_player/services/content_filter_service.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';
import 'package:another_iptv_player/services/content_consolidation_service.dart';
import 'package:another_iptv_player/services/content_preference_service.dart';
import 'package:another_iptv_player/services/hidden_favorites_service.dart';
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

  // Event subscriptions
  StreamSubscription? _configChangedSubscription;

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
    List<CategoryViewModel> result;
    if (playlistId == null) {
      result = _applyContentFiltering(filtered);
    } else {
      result = _applyContentFiltering(CategoryConfigService().applyConfig(
        playlistId: playlistId,
        type: CategoryType.live,
        categories: filtered,
      ));
    }
    // Add hidden favorites category at the top if available
    if (_hiddenFavoritesLive != null) {
      return [_hiddenFavoritesLive!, ...result];
    }
    return result;
  }

  List<CategoryViewModel> get visibleMovieCategories {
    final filtered = _movieCategories
        .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
        .where((c) => !_parentalService.shouldHideCategory(
            c.category.categoryId, c.category.categoryName))
        .toList();
    final playlistId = AppState.currentPlaylist?.id;
    List<CategoryViewModel> result;
    if (playlistId == null) {
      result = _applyContentFiltering(filtered);
    } else {
      result = _applyContentFiltering(CategoryConfigService().applyConfig(
        playlistId: playlistId,
        type: CategoryType.vod,
        categories: filtered,
      ));
    }
    // Add hidden favorites category at the top if available
    if (_hiddenFavoritesVod != null) {
      return [_hiddenFavoritesVod!, ...result];
    }
    return result;
  }

  List<CategoryViewModel> get visibleSeriesCategories {
    final filtered = _seriesCategories
        .where((c) => !_hiddenCategoryIds.contains(c.category.categoryId))
        .where((c) => !_parentalService.shouldHideCategory(
            c.category.categoryId, c.category.categoryName))
        .toList();
    final playlistId = AppState.currentPlaylist?.id;
    List<CategoryViewModel> result;
    if (playlistId == null) {
      result = _applyContentFiltering(filtered);
    } else {
      result = _applyContentFiltering(CategoryConfigService().applyConfig(
        playlistId: playlistId,
        type: CategoryType.series,
        categories: filtered,
      ));
    }
    // Add hidden favorites category at the top if available
    if (_hiddenFavoritesSeries != null) {
      return [_hiddenFavoritesSeries!, ...result];
    }
    return result;
  }

  // Consolidation service for merging duplicates
  final ContentConsolidationService _consolidationService = ContentConsolidationService();
  final ContentPreferenceService _preferenceService = ContentPreferenceService();
  final HiddenFavoritesService _hiddenFavoritesService = HiddenFavoritesService();
  final ContentFilterService _contentFilterService = ContentFilterService();
  bool _consolidationEnabled = true;

  // Hidden favorites category cache (built once per session)
  CategoryViewModel? _hiddenFavoritesLive;
  CategoryViewModel? _hiddenFavoritesVod;
  CategoryViewModel? _hiddenFavoritesSeries;

  // Filter content items within categories based on parental controls, content filters, and consolidate
  List<CategoryViewModel> _applyContentFiltering(List<CategoryViewModel> categories) {
    return categories.map((category) {
      // First apply parental controls
      var filteredItems = _parentalService.filterContent<ContentItem>(
        category.contentItems,
        getId: (item) => item.id,
        getName: (item) => item.name,
        getCategoryId: (item) => category.category.categoryId,
        getCategoryName: (item) => category.category.categoryName,
      );

      // Then apply content filter rules (like ## pattern)
      filteredItems = filteredItems.where((item) {
        return !_contentFilterService.shouldHideContent(
          item.name,
          categoryId: category.category.categoryId,
        );
      }).toList();

      // Apply consolidation if enabled
      if (_consolidationEnabled && filteredItems.length > 1) {
        try {
          final consolidated = _consolidationService.consolidateWithPreferences(
            filteredItems,
            preferredQuality: _preferenceService.preferredQuality,
            preferredLanguage: _preferenceService.preferredLanguage,
          );

          if (consolidated.length < filteredItems.length) {
            debugPrint('Consolidated ${category.category.categoryName}: '
                '${filteredItems.length} -> ${consolidated.length} items');
          }

          return category.withConsolidatedItems(consolidated);
        } catch (e) {
          debugPrint('Error consolidating ${category.category.categoryName}: $e');
        }
      }

      return CategoryViewModel(
        category: category.category,
        contentItems: filteredItems,
      );
    }).where((category) => category.contentItems.isNotEmpty ||
        (category.consolidatedItems?.isNotEmpty ?? false)).toList();
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
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Listen for category config changes to refresh the view
    _configChangedSubscription = EventBus().on<String>('category_config_changed').listen((playlistId) {
      if (playlistId == AppState.currentPlaylist?.id) {
        // Config changed for current playlist, refresh the view
        notifyListeners();
      }
    });
  }

  Future<void> _initializeData(bool all) async {
    // Load default panel preference
    await _loadDefaultPanel();
    // Initialize parental controls
    await _parentalService.initialize();
    // Initialize content filter service
    await _contentFilterService.initialize();
    // Load consolidation preferences
    await _preferenceService.loadPreferences();
    _consolidationEnabled = await UserPreferences.getConsolidationEnabled();
    // Initialize hidden favorites service
    await _hiddenFavoritesService.initialize();
    // Load category configuration (ordering, merging)
    await CategoryConfigService().loadConfigs();
    await loadHiddenCategories();
    await _loadCategories(all);
    // Build hidden favorites categories after loading all categories
    await _buildHiddenFavoritesCategories();
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
    _configChangedSubscription?.cancel();
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

  /// Build hidden favorites categories for each content type
  Future<void> _buildHiddenFavoritesCategories() async {
    try {
      final hiddenNames = await UserPreferences.getHiddenCategoryNames();

      _hiddenFavoritesLive = await _hiddenFavoritesService.buildHiddenFavoritesCategory(
        type: CategoryType.live,
        hiddenCategoryIds: _hiddenCategoryIds,
        hiddenCategoryNames: hiddenNames.toSet(),
        allCategories: _liveCategories,
      );

      _hiddenFavoritesVod = await _hiddenFavoritesService.buildHiddenFavoritesCategory(
        type: CategoryType.vod,
        hiddenCategoryIds: _hiddenCategoryIds,
        hiddenCategoryNames: hiddenNames.toSet(),
        allCategories: _movieCategories,
      );

      _hiddenFavoritesSeries = await _hiddenFavoritesService.buildHiddenFavoritesCategory(
        type: CategoryType.series,
        hiddenCategoryIds: _hiddenCategoryIds,
        hiddenCategoryNames: hiddenNames.toSet(),
        allCategories: _seriesCategories,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error building hidden favorites categories: $e');
    }
  }
}
