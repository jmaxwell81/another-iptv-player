import 'dart:async';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/m3u_item.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/view_state.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/content_filter_service.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';
import 'package:another_iptv_player/services/content_consolidation_service.dart';
import 'package:another_iptv_player/services/content_preference_service.dart';
import 'package:another_iptv_player/services/hidden_favorites_service.dart';
import 'package:another_iptv_player/services/category_config_service.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:flutter/material.dart';

class M3UHomeController extends ChangeNotifier {
  late PageController _pageController;
  final M3uRepository _repository = AppState.m3uRepository!;
  final ParentalControlService _parentalService = ParentalControlService();
  String? _errorMessage;
  ViewState _viewState = ViewState.idle;

  int _currentIndex = 2; // Default to All items, will be updated from preferences
  bool _isLoading = true;

  final List<CategoryViewModel> _liveCategories = [];
  final List<CategoryViewModel> _vodCategories = [];
  final List<CategoryViewModel> _seriesCategories = [];
  List<M3uItem>? _m3uItems = [];
  List<M3uItem>? _liveChannels;
  List<M3uItem>? _movies;
  List<M3uItem>? _series;

  // Event subscriptions
  StreamSubscription? _configChangedSubscription;

  // Getters
  PageController get pageController => _pageController;

  int get currentIndex => _currentIndex;

  // Visible categories with parental filtering and hidden favorites applied
  List<CategoryViewModel>? get liveCategories {
    final filtered = _applyParentalFiltering(_liveCategories);
    // Add hidden favorites category at the top if available
    if (_hiddenFavoritesLive != null) {
      return [_hiddenFavoritesLive!, ...filtered];
    }
    return filtered;
  }

  List<CategoryViewModel>? get vodCategories {
    final filtered = _applyParentalFiltering(_vodCategories);
    // Add hidden favorites category at the top if available
    if (_hiddenFavoritesVod != null) {
      return [_hiddenFavoritesVod!, ...filtered];
    }
    return filtered;
  }

  List<CategoryViewModel>? get seriesCategories {
    final filtered = _applyParentalFiltering(_seriesCategories);
    // Add hidden favorites category at the top if available
    if (_hiddenFavoritesSeries != null) {
      return [_hiddenFavoritesSeries!, ...filtered];
    }
    return filtered;
  }

  // Consolidation services
  final ContentConsolidationService _consolidationService = ContentConsolidationService();
  final ContentPreferenceService _preferenceService = ContentPreferenceService();
  final HiddenFavoritesService _hiddenFavoritesService = HiddenFavoritesService();
  final ContentFilterService _contentFilterService = ContentFilterService();
  bool _consolidationEnabled = true;

  // Hidden favorites category cache
  CategoryViewModel? _hiddenFavoritesLive;
  CategoryViewModel? _hiddenFavoritesVod;
  CategoryViewModel? _hiddenFavoritesSeries;

  // Hidden category tracking
  Set<String> _hiddenCategoryIds = {};

  // Filter categories and content based on parental controls and content filters, then consolidate
  List<CategoryViewModel> _applyParentalFiltering(List<CategoryViewModel> categories) {
    return categories
        .where((c) => !_parentalService.shouldHideCategory(
            c.category.categoryId, c.category.categoryName))
        .map((category) {
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
                debugPrint('M3U Consolidated ${category.category.categoryName}: '
                    '${filteredItems.length} -> ${consolidated.length} items');
              }

              return category.withConsolidatedItems(consolidated);
            } catch (e) {
              debugPrint('Error consolidating M3U ${category.category.categoryName}: $e');
            }
          }

          return CategoryViewModel(
            category: category.category,
            contentItems: filteredItems,
          );
        })
        .where((category) => category.contentItems.isNotEmpty ||
            (category.consolidatedItems?.isNotEmpty ?? false))
        .toList();
  }

  List<M3uItem>? get m3uItems => _m3uItems;

  List<M3uItem>? get liveChannels => _liveChannels;

  List<M3uItem>? get movies => _movies;

  List<M3uItem>? get series => _series;

  bool get isLoading => _isLoading;

  M3UHomeController() {
    _pageController = PageController();
    _initialize();
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

  Future<void> _initialize() async {
    // Load default panel preference
    await _loadDefaultPanel();
    // Initialize parental controls first
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
    // Load hidden categories
    await _loadHiddenCategories();
    _loadM3uItems();
    await _loadCategories();
    // Build hidden favorites categories
    await _buildHiddenFavoritesCategories();
  }

  Future<void> _loadHiddenCategories() async {
    final hidden = await UserPreferences.getHiddenCategories();
    _hiddenCategoryIds = hidden.toSet();
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
      case 'all':
      case 'live':
        return 2;
      case 'guide':
        return 3;
      case 'settings':
        return 4;
      default:
        return 2; // Default to All/Live
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
        return context.loc.all;
      case 3:
        return 'TV Guide';
      case 4:
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

  Future<void> _loadM3uItems() async {
    try {
      _isLoading = true;
      notifyListeners();

      _m3uItems = await _repository.getM3uItems();
      AppState.m3uItems = _m3uItems;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'M3U items cannot loaded: $e';
      _setViewState(ViewState.error);
      _isLoading = false;
    }
  }

  Future<void> _loadCategories() async {
    try {
      _isLoading = true;
      notifyListeners();

      var categories = await _repository.getCategories();
      for (var category in categories!) {
        if (category.type != CategoryType.series) {
          var m3uItems = await _repository.getM3uItemsByCategoryId(
            categoryId: category.categoryId,
            top: 10,
          );

          late CategoryViewModel categoryViewModel;
          if (m3uItems == null) {
            categoryViewModel = CategoryViewModel(
              category: category,
              contentItems: [],
            );
          } else {
            final playlistId = AppState.currentPlaylist?.id;
            categoryViewModel = CategoryViewModel(
              category: category,
              contentItems: m3uItems.map((x) {
                return ContentItem(
                  x.url,
                  x.name ?? '',
                  x.tvgLogo ?? '',
                  x.contentType,
                  m3uItem: x,
                  sourcePlaylistId: playlistId,
                  sourceType: PlaylistType.m3u,
                );
              }).toList(),
            );
          }

          switch (category.type) {
            case CategoryType.live:
              _liveCategories.add(categoryViewModel);
            case CategoryType.vod:
              _vodCategories.add(categoryViewModel);
            case CategoryType.series:
              _seriesCategories.add(categoryViewModel);
          }
        } else {
          var series = await _repository.getSeriesByCategoryId(
            categoryId: category.categoryId,
            top: 10,
          );

          late CategoryViewModel categoryViewModel;
          if (series == null) {
            categoryViewModel = CategoryViewModel(
              category: category,
              contentItems: [],
            );
          } else {
            final playlistId = AppState.currentPlaylist?.id;
            categoryViewModel = CategoryViewModel(
              category: category,
              contentItems: series.map((x) {
                return ContentItem(
                  x.seriesId,
                  x.name,
                  '',
                  ContentType.series,
                  sourcePlaylistId: playlistId,
                  sourceType: PlaylistType.m3u,
                );
              }).toList(),
            );
          }

          _seriesCategories.add(categoryViewModel);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Kategoriler yüklenemedi: $e';
      _setViewState(ViewState.error);
      _isLoading = false;
    }
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
        allCategories: _vodCategories,
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
