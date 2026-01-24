import 'package:flutter/foundation.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/epg_channel.dart';
import 'package:another_iptv_player/models/epg_fetch_status.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/tv_guide_channel.dart';
import 'package:another_iptv_player/repositories/epg_repository.dart';
import 'package:another_iptv_player/repositories/hidden_items_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/auto_combine_service.dart';
import 'package:another_iptv_player/services/epg_matching_service.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';
import 'package:another_iptv_player/services/name_tag_cleaner_service.dart';
import 'package:another_iptv_player/services/renaming_service.dart';
import 'package:another_iptv_player/services/custom_rename_service.dart';

class TvGuideController extends ChangeNotifier {
  final EpgRepository _epgRepository = EpgRepository();
  final EpgMatchingService _matchingService = EpgMatchingService();
  final HiddenItemsRepository _hiddenItemsRepository = HiddenItemsRepository();
  final AppDatabase _database = getIt<AppDatabase>();

  bool _isLoading = false;
  bool _isDisposed = false;
  String? _errorMessage;
  String? _epgStatus;
  bool _isFetchingEpg = false;

  // Enhanced EPG fetch progress tracking
  EpgFetchProgress? _epgFetchProgress;
  bool _cancelRequested = false;

  // View state
  DateTime _viewStartTime = DateTime.now().subtract(const Duration(minutes: 30));
  int _visibleHours = 3;
  final double _pixelsPerMinute = 4.0;

  // Filters
  bool _showChannelsWithoutEpg = false;
  String _searchQuery = '';

  // Pagination
  int _currentPage = 0;
  int _channelsPerPage = 100;

  // Hidden items/categories for filtering
  Set<String> _hiddenStreamIds = {};
  Set<String> _hiddenCategoryIds = {};
  Set<String> _hiddenCategoryNames = {};

  // Favorites filtering
  Set<String> _favoritesOnlyCategoryIds = {};
  Set<String> _favoriteStreamIds = {};

  // Data
  List<TvGuideChannel> _channels = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isFetchingEpg => _isFetchingEpg;
  String? get errorMessage => _errorMessage;
  String? get epgStatus => _epgStatus;
  EpgFetchProgress? get epgFetchProgress => _epgFetchProgress;
  DateTime get viewStartTime => _viewStartTime;
  int get visibleHours => _visibleHours;
  double get pixelsPerMinute => _pixelsPerMinute;
  bool get showChannelsWithoutEpg => _showChannelsWithoutEpg;
  String get searchQuery => _searchQuery;
  List<TvGuideChannel> get channels => _channels;
  int get currentPage => _currentPage;
  int get channelsPerPage => _channelsPerPage;

  DateTime get viewEndTime => _viewStartTime.add(Duration(hours: _visibleHours));

  double get totalWidth => _visibleHours * 60 * _pixelsPerMinute;

  /// Get all visible channels (after filtering hidden items/categories, before pagination)
  List<TvGuideChannel> get _visibleChannels {
    var result = _channels;

    // Filter out hidden channels (by stream ID)
    result = result.where((c) => !_hiddenStreamIds.contains(c.streamId)).toList();

    // Filter out channels from hidden categories (by ID or name)
    result = result.where((c) {
      final categoryId = c.liveStream?.categoryId ?? c.m3uItem?.categoryId;
      if (categoryId != null && _hiddenCategoryIds.contains(categoryId)) {
        return false;
      }
      // Also check by normalized category name if available
      // Note: We don't have category name on TvGuideChannel, so we check by ID only
      return true;
    }).toList();

    return result;
  }

  /// Get filtered channels based on search query, EPG filter, and pagination
  List<TvGuideChannel> get filteredChannels {
    var result = _visibleChannels;

    // Filter by EPG availability
    if (!_showChannelsWithoutEpg) {
      result = result.where((c) => c.hasEpgData).toList();
    }

    // Filter by search query (use displayName for cleaned names)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((c) {
        return c.displayName.toLowerCase().contains(query) ||
            (c.currentProgram?.title.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return result;
  }

  /// Get paginated channels for display (already loaded for current page)
  List<TvGuideChannel> get paginatedChannels => _channels;

  /// Total number of filtered channels (before pagination)
  int get totalFilteredChannels => _totalFilteredCount;

  /// Total number of pages
  int get totalPages => (_totalFilteredCount / _channelsPerPage).ceil().clamp(1, 9999);

  /// Whether there's a next page
  bool get hasNextPage => _currentPage < totalPages - 1;

  /// Whether there's a previous page
  bool get hasPreviousPage => _currentPage > 0;

  /// Cancel the current EPG fetch operation
  void cancelEpgFetch() {
    _cancelRequested = true;
    _notifyIfNotDisposed();
  }

  /// Fetch EPG data for a playlist if needed
  Future<void> fetchEpgData({bool force = false}) async {
    if (_isFetchingEpg) return;

    try {
      _isFetchingEpg = true;
      _cancelRequested = false;
      _epgStatus = 'Checking EPG data...';
      _notifyIfNotDisposed();

      final completedSources = <EpgSourceStatus>[];

      // Get list of playlists to fetch EPG for
      final playlists = AppState.isCombinedMode
          ? AppState.activePlaylists.values.toList()
          : AppState.currentPlaylist != null
              ? [AppState.currentPlaylist!]
              : <Playlist>[];

      if (playlists.isEmpty) {
        _epgStatus = null;
        _epgFetchProgress = null;
        return;
      }

      for (var i = 0; i < playlists.length; i++) {
        // Check for cancellation
        if (_cancelRequested) {
          _epgFetchProgress = _epgFetchProgress?.copyWith(
            isCancelled: true,
            completedSources: completedSources,
          );
          _notifyIfNotDisposed();
          break;
        }

        final playlist = playlists[i];

        // Initialize progress for this source
        _epgFetchProgress = EpgFetchProgress(
          currentSourceIndex: i,
          totalSources: playlists.length,
          currentSource: EpgSourceStatus(
            playlistId: playlist.id,
            playlistName: playlist.name,
            state: EpgFetchState.checking,
            startTime: DateTime.now(),
          ),
          completedSources: completedSources,
          isCancelled: false,
        );
        _epgStatus = 'EPG: Source ${i + 1} of ${playlists.length}';
        _notifyIfNotDisposed();

        final result = await _epgRepository.fetchAndStoreEpgWithStatus(
          playlist,
          force: force,
          onProgress: (progress) {
            _epgStatus = '${playlist.name}: $progress';
            _notifyIfNotDisposed();
          },
          onStatusUpdate: (status) {
            _epgFetchProgress = _epgFetchProgress?.copyWith(
              currentSource: status,
            );
            _notifyIfNotDisposed();
          },
          isCancelled: () => _cancelRequested,
        );

        // Determine final state for this source
        EpgFetchState finalState;
        if (_cancelRequested || result.message == 'Cancelled') {
          finalState = EpgFetchState.cancelled;
        } else if (result.skipped) {
          finalState = EpgFetchState.skipped;
        } else if (result.success) {
          finalState = EpgFetchState.completed;
        } else {
          finalState = EpgFetchState.failed;
        }

        // Check if the error indicates the source was offline
        final isOffline = result.message.toLowerCase().contains('timeout') ||
            result.message.toLowerCase().contains('connection') ||
            result.message.toLowerCase().contains('socket') ||
            result.message.toLowerCase().contains('offline');

        // Record completion status
        completedSources.add(EpgSourceStatus(
          playlistId: playlist.id,
          playlistName: playlist.name,
          state: finalState,
          wasOffline: isOffline,
          errorMessage: result.success ? null : result.message,
          progress: 1.0,
        ));

        // Update progress with completed source
        _epgFetchProgress = _epgFetchProgress?.copyWith(
          completedSources: completedSources,
        );
        _notifyIfNotDisposed();
      }

      _epgStatus = null;
      _epgFetchProgress = null;
    } catch (e) {
      _epgStatus = 'EPG fetch failed: $e';
    } finally {
      _isFetchingEpg = false;
      _cancelRequested = false;
      _notifyIfNotDisposed();
    }
  }

  /// Load hidden items and categories for filtering
  Future<void> _loadHiddenData() async {
    try {
      // Load hidden stream IDs
      _hiddenStreamIds = {};
      if (AppState.isCombinedMode) {
        for (final playlistId in AppState.activePlaylists.keys) {
          final hiddenIds = await _hiddenItemsRepository.getHiddenStreamIds(playlistId);
          _hiddenStreamIds.addAll(hiddenIds);
        }
      } else if (AppState.currentPlaylist != null) {
        final hiddenIds = await _hiddenItemsRepository.getHiddenStreamIds(AppState.currentPlaylist!.id);
        _hiddenStreamIds.addAll(hiddenIds);
      }

      // Load hidden category IDs and names
      final hiddenCategoryIdsList = await UserPreferences.getHiddenCategories();
      final hiddenCategoryNamesList = await UserPreferences.getHiddenCategoryNames();
      _hiddenCategoryIds = hiddenCategoryIdsList.toSet();
      _hiddenCategoryNames = hiddenCategoryNamesList.toSet();

      // Load favorites-only categories
      final favOnlyCats = await UserPreferences.getFavoritesOnlyCategories();
      _favoritesOnlyCategoryIds = favOnlyCats.toSet();

      // Load favorite stream IDs for filtering
      await _loadFavoriteStreamIds();

      // Also apply auto-combine service filtering for non-English categories
      await _loadAutoCombineHiddenCategories();
    } catch (e) {
      // Hidden data loading failed, continue with empty filters
    }
  }

  /// Load favorite stream IDs for filtering
  Future<void> _loadFavoriteStreamIds() async {
    _favoriteStreamIds = {};
    try {
      final favorites = await _database.getFavoritesByContentType(
        AppState.currentPlaylist?.id ?? '',
        ContentType.liveStream,
      );

      // In combined mode, get favorites from all active playlists
      if (AppState.isCombinedMode) {
        for (final playlistId in AppState.activePlaylists.keys) {
          final playlistFavorites = await _database.getFavoritesByContentType(
            playlistId,
            ContentType.liveStream,
          );
          for (final fav in playlistFavorites) {
            _favoriteStreamIds.add(fav.streamId);
          }
        }
      } else {
        for (final fav in favorites) {
          _favoriteStreamIds.add(fav.streamId);
        }
      }
    } catch (e) {
      // Favorites loading failed, continue without filtering
    }
  }

  /// Load categories that should be hidden based on auto-combine rules (e.g., non-English)
  Future<void> _loadAutoCombineHiddenCategories() async {
    try {
      final autoCombineService = AutoCombineService();
      await autoCombineService.initialize();

      if (AppState.isCombinedMode) {
        for (final playlistId in AppState.activePlaylists.keys) {
          final categories = await _database.getCategoriesByPlaylist(playlistId);
          // Filter for live stream categories only (TV Guide is for live content)
          final liveCategories = categories.where((c) => c.type == CategoryType.live);
          for (final cat in liveCategories) {
            if (autoCombineService.shouldHideCategory(cat.categoryName)) {
              _hiddenCategoryIds.add(cat.categoryId);
              _hiddenCategoryNames.add(cat.categoryName.toUpperCase());
            }
          }
        }
      } else if (AppState.currentPlaylist != null) {
        final playlist = AppState.currentPlaylist!;
        final categories = await _database.getCategoriesByPlaylist(playlist.id);
        // Filter for live stream categories only
        final liveCategories = categories.where((c) => c.type == CategoryType.live);
        for (final cat in liveCategories) {
          if (autoCombineService.shouldHideCategory(cat.categoryName)) {
            _hiddenCategoryIds.add(cat.categoryId);
            _hiddenCategoryNames.add(cat.categoryName.toUpperCase());
          }
        }
      }
    } catch (e) {
      // Auto-combine filtering failed, continue with existing filters
    }
  }

  /// Load channels per page setting from preferences
  Future<void> _loadChannelsPerPageSetting() async {
    _channelsPerPage = await UserPreferences.getTvGuideChannelLimit();
  }

  /// Initialize renaming services for synchronous use
  Future<void> _initializeRenamingServices() async {
    try {
      // Initialize all renaming-related services
      await NameTagCleanerService().initialize();
      await RenamingService().loadRules();
      await CustomRenameService().loadRenames();
    } catch (e) {
      // Services may fail to initialize, but continue anyway
    }
  }

  /// Load channels from active playlists (fetches EPG first if needed)
  /// This is optimized to only load channels for the current page
  Future<void> loadChannels({bool fetchEpgFirst = true, bool resetPage = true}) async {
    try {
      _setLoading(true);
      _setError(null);

      // Initialize renaming services first
      await _initializeRenamingServices();

      // Load settings and hidden data
      await _loadChannelsPerPageSetting();
      await _loadHiddenData();

      // Reset to first page when reloading (unless explicitly disabled)
      if (resetPage) {
        _currentPage = 0;
      }

      // Fetch EPG data first if requested
      if (fetchEpgFirst) {
        await fetchEpgData();
      }

      // Load only visible channels (filtered and paginated at source)
      await _loadVisibleChannels();

      _notifyIfNotDisposed();
    } catch (e) {
      _setError('Failed to load channels: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load only visible channels with filtering and pagination applied at the data source level
  Future<void> _loadVisibleChannels() async {
    final allVisibleChannels = <TvGuideChannel>[];

    // Time range for EPG programs
    final timeRangeStart = _viewStartTime.subtract(const Duration(hours: 1));
    final timeRangeEnd = _viewStartTime.add(Duration(hours: _visibleHours + 1));

    // When not showing channels without EPG, we need to pre-filter by EPG availability
    // Get EPG channel IDs that have programs for each playlist
    final playlistEpgChannelIds = <String, Set<String>>{};

    if (!_showChannelsWithoutEpg) {
      if (AppState.isCombinedMode) {
        for (final playlistId in AppState.activePlaylists.keys) {
          final epgIds = await _database.getEpgChannelIdsWithPrograms(
            playlistId, timeRangeStart, timeRangeEnd);
          playlistEpgChannelIds[playlistId] = epgIds;
        }
      } else if (AppState.currentPlaylist != null) {
        final playlistId = AppState.currentPlaylist!.id;
        final epgIds = await _database.getEpgChannelIdsWithPrograms(
          playlistId, timeRangeStart, timeRangeEnd);
        playlistEpgChannelIds[playlistId] = epgIds;
      }
    }

    // Calculate total count first for pagination UI
    int totalCount = 0;
    final playlistCounts = <String, int>{};

    if (AppState.isCombinedMode) {
      for (final entry in AppState.activePlaylists.entries) {
        final playlistId = entry.key;
        final playlist = entry.value;
        final epgChannelIds = playlistEpgChannelIds[playlistId];

        if (playlist.type == PlaylistType.xtream) {
          final count = await _database.countLiveStreamsFiltered(
            playlistId,
            excludedCategoryIds: _hiddenCategoryIds,
            excludedStreamIds: _hiddenStreamIds,
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
            requireEpgChannelIds: epgChannelIds,
          );
          playlistCounts[playlistId] = count;
          totalCount += count;
        } else {
          final count = await _database.countM3uLiveItemsFiltered(
            playlistId,
            excludedCategoryIds: _hiddenCategoryIds,
            excludedStreamIds: _hiddenStreamIds,
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          );
          playlistCounts[playlistId] = count;
          totalCount += count;
        }
      }
    } else if (AppState.currentPlaylist != null) {
      final playlist = AppState.currentPlaylist!;
      final epgChannelIds = playlistEpgChannelIds[playlist.id];

      if (playlist.type == PlaylistType.xtream) {
        totalCount = await _database.countLiveStreamsFiltered(
          playlist.id,
          excludedCategoryIds: _hiddenCategoryIds,
          excludedStreamIds: _hiddenStreamIds,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          requireEpgChannelIds: epgChannelIds,
        );
        playlistCounts[playlist.id] = totalCount;
      } else {
        totalCount = await _database.countM3uLiveItemsFiltered(
          playlist.id,
          excludedCategoryIds: _hiddenCategoryIds,
          excludedStreamIds: _hiddenStreamIds,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
        playlistCounts[playlist.id] = totalCount;
      }
    }

    _totalVisibleChannels = totalCount;
    _totalFilteredCount = totalCount;

    // Calculate offset for current page
    final pageOffset = _currentPage * _channelsPerPage;

    if (pageOffset >= totalCount) {
      _channels = [];
      return;
    }

    // Track how many items to skip/take across playlists
    int skipRemaining = pageOffset;
    int takeRemaining = _channelsPerPage;

    if (AppState.isCombinedMode) {
      for (final entry in AppState.activePlaylists.entries) {
        if (takeRemaining <= 0) break;

        final playlistId = entry.key;
        final playlist = entry.value;
        final playlistCount = playlistCounts[playlistId] ?? 0;
        final epgChannelIds = playlistEpgChannelIds[playlistId];

        // Skip this playlist if we still need to skip more than its count
        if (skipRemaining >= playlistCount) {
          skipRemaining -= playlistCount;
          continue;
        }

        // Calculate how many to take from this playlist
        final localOffset = skipRemaining;
        final localLimit = (playlistCount - localOffset).clamp(0, takeRemaining);
        skipRemaining = 0;

        if (playlist.type == PlaylistType.xtream) {
          final channels = await _loadXtreamChannelsPage(
            playlistId, localOffset, localLimit, timeRangeStart, timeRangeEnd,
            requireEpgChannelIds: epgChannelIds);
          allVisibleChannels.addAll(channels);
        } else {
          final channels = await _loadM3uChannelsPage(
            playlistId, localOffset, localLimit, timeRangeStart, timeRangeEnd);
          allVisibleChannels.addAll(channels);
        }

        takeRemaining -= localLimit;
      }
    } else if (AppState.currentPlaylist != null) {
      final playlist = AppState.currentPlaylist!;
      final epgChannelIds = playlistEpgChannelIds[playlist.id];

      if (playlist.type == PlaylistType.xtream) {
        final channels = await _loadXtreamChannelsPage(
          playlist.id, pageOffset, _channelsPerPage, timeRangeStart, timeRangeEnd,
          requireEpgChannelIds: epgChannelIds);
        allVisibleChannels.addAll(channels);
      } else {
        final channels = await _loadM3uChannelsPage(
          playlist.id, pageOffset, _channelsPerPage, timeRangeStart, timeRangeEnd);
        allVisibleChannels.addAll(channels);
      }
    }

    // Apply renaming rules to all channels
    final renamedChannels = _applyRenamingRules(allVisibleChannels);

    // Filter channels for favorites-only categories
    final filteredChannels = _filterFavoritesOnlyCategories(renamedChannels);

    // Combine channels with the same display name
    _channels = _combineChannelsByDisplayName(filteredChannels);
  }

  /// Filter out non-favorite channels from categories set to show only favorites
  List<TvGuideChannel> _filterFavoritesOnlyCategories(List<TvGuideChannel> channels) {
    if (_favoritesOnlyCategoryIds.isEmpty) {
      return channels;
    }

    return channels.where((channel) {
      // Get the category ID for this channel
      final categoryId = channel.liveStream?.categoryId ?? channel.m3uItem?.categoryId;

      // If not in a favorites-only category, keep it
      if (categoryId == null || !_favoritesOnlyCategoryIds.contains(categoryId)) {
        return true;
      }

      // In a favorites-only category - only keep if it's a favorite
      return _favoriteStreamIds.contains(channel.streamId);
    }).toList();
  }

  /// Apply renaming rules (tag cleaning, etc.) to channel names
  /// Falls back to built-in prefix removal if no renaming occurs
  List<TvGuideChannel> _applyRenamingRules(List<TvGuideChannel> channels) {
    return channels.map((channel) {
      // First try the renaming extension (custom renames, rules, tag cleaner)
      var displayName = channel.name.applyRenamingRules(
        contentType: ContentType.liveStream,
        itemId: channel.streamId,
        playlistId: channel.playlistId,
      );

      // If the name wasn't changed by renaming rules, apply built-in cleaning
      // This ensures prefixes like "US:", "HU:", "UK |" are always removed in TV Guide
      if (displayName == channel.name) {
        displayName = _cleanChannelName(channel.name);
      }

      return channel.copyWith(displayName: displayName);
    }).toList();
  }

  /// Clean channel name by removing common prefixes, suffixes, and quality indicators
  /// This is a fallback when the NameTagCleanerService isn't enabled
  String _cleanChannelName(String name) {
    var result = name.trim();

    // Quality indicators to remove
    const qualityPatterns = [
      'UHD', '4K', 'FHD', 'HD', 'SD',
      '2160P', '1080P', '720P', '480P',
      'HEVC', 'H264', 'H265', 'H.264', 'H.265',
      'HDR', 'HDR10', 'DOLBY', 'ATMOS',
    ];

    // Language/country codes to remove
    const langCountryCodes = [
      'US', 'USA', 'UK', 'GB', 'CA', 'AU', 'NZ', 'IE',
      'EN', 'ENGLISH', 'AMERICAN', 'BRITISH',
      'FR', 'FRENCH', 'ES', 'SPANISH', 'DE', 'GERMAN',
      'IT', 'ITALIAN', 'PT', 'PORTUGUESE', 'NL', 'DUTCH',
      'PL', 'POLISH', 'RU', 'RUSSIAN', 'AR', 'ARABIC',
      'TR', 'TURKISH', 'HU', 'HUNGARIAN',
    ];

    // Remove bracket tags: [EN], [US], [HD], [4K], [MULTI-SUB], etc.
    result = result.replaceAll(RegExp(r'\[[^\]]+\]'), '');

    // Remove parenthesis tags: (US), (HD), (EN), (MULTI-SUB), etc.
    result = result.replaceAll(RegExp(r'\([^)]+\)'), '');

    // Remove common provider/region prefixes (e.g., "SLING:", "US:", "HU:", "UK |", "EN|", "EN -")
    result = result.replaceAll(RegExp(r'^[A-Za-z]{2,10}\s*[:\|\-]\s*', caseSensitive: false), '');

    // Remove quality indicators anywhere in the name (with word boundaries)
    for (final quality in qualityPatterns) {
      // Match quality word with optional surrounding spaces, handling start/end of string
      result = result.replaceAll(
        RegExp('\\b$quality\\b', caseSensitive: false),
        ' ',
      );
    }

    // Remove language/country codes at start with separator
    for (final code in langCountryCodes) {
      result = result.replaceAll(
        RegExp('^$code\\s*[:\\|\\-]\\s*', caseSensitive: false),
        '',
      );
    }

    // Remove language/country codes at end with separator
    for (final code in langCountryCodes) {
      result = result.replaceAll(
        RegExp('\\s*[:\\|\\-]\\s*$code\$', caseSensitive: false),
        '',
      );
    }

    // Remove standalone quality/lang codes at start or end (with space separator)
    final allCodes = [...qualityPatterns, ...langCountryCodes];
    for (final code in allCodes) {
      // At start: "HD Channel Name" -> "Channel Name"
      result = result.replaceAll(
        RegExp('^$code\\s+', caseSensitive: false),
        '',
      );
      // At end: "Channel Name HD" -> "Channel Name"
      result = result.replaceAll(
        RegExp('\\s+$code\$', caseSensitive: false),
        '',
      );
    }

    // Remove superscript markers like ᴿᴬᵂ
    result = result.replaceAll(RegExp(r'[ᴬᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᴿˢᵀᵁⱽᵂˣʸᶻ]+'), '');

    // Clean up separators and whitespace
    result = result.replaceAll(RegExp(r'\s*[:\|\-]\s*[:\|\-]\s*'), ' '); // Double separators
    result = result.replaceAll(RegExp(r'^[\s:\|\-]+'), ''); // Leading separators
    result = result.replaceAll(RegExp(r'[\s:\|\-]+$'), ''); // Trailing separators
    result = result.replaceAll(RegExp(r'\s{2,}'), ' '); // Multiple spaces

    return result.trim();
  }

  /// Combine channels that have the same display name into a single entry
  /// This merges EPG programs and keeps the channel with the most EPG data as primary
  List<TvGuideChannel> _combineChannelsByDisplayName(List<TvGuideChannel> channels) {
    // Group channels by lowercase display name for case-insensitive matching
    final groupedByName = <String, List<TvGuideChannel>>{};

    for (final channel in channels) {
      final key = channel.displayName.toLowerCase().trim();
      groupedByName.putIfAbsent(key, () => []).add(channel);
    }

    // Combine groups into single channels
    final combinedChannels = <TvGuideChannel>[];

    for (final group in groupedByName.values) {
      if (group.length == 1) {
        // No duplicates, keep as-is
        combinedChannels.add(group.first);
      } else {
        // Combine multiple channels with the same name
        combinedChannels.add(_mergeChannelGroup(group));
      }
    }

    // Sort by display name to maintain consistent order
    combinedChannels.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return combinedChannels;
  }

  /// Merge a group of channels with the same display name into one
  TvGuideChannel _mergeChannelGroup(List<TvGuideChannel> group) {
    // Sort by EPG program count (descending) to pick the best primary
    group.sort((a, b) => b.programs.length.compareTo(a.programs.length));

    final primary = group.first;

    // Collect all unique programs from all channels
    final allPrograms = <EpgProgram>[];
    final seenProgramKeys = <String>{};

    for (final channel in group) {
      for (final program in channel.programs) {
        // Use start time + title as unique key to deduplicate
        final key = '${program.startTime.toIso8601String()}_${program.title}';
        if (!seenProgramKeys.contains(key)) {
          seenProgramKeys.add(key);
          allPrograms.add(program);
        }
      }
    }

    // Sort programs by start time
    allPrograms.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Pick the best icon (prefer non-null, non-empty)
    String? bestIcon = primary.icon;
    if (bestIcon == null || bestIcon.isEmpty) {
      for (final channel in group) {
        if (channel.icon != null && channel.icon!.isNotEmpty) {
          bestIcon = channel.icon;
          break;
        }
      }
    }

    // Create combined channel with all sources stored
    return primary.copyWith(
      programs: allPrograms,
      icon: bestIcon,
      combinedSources: group,
    );
  }

  /// Load a page of Xtream channels with EPG data
  Future<List<TvGuideChannel>> _loadXtreamChannelsPage(
    String playlistId,
    int offset,
    int limit,
    DateTime timeRangeStart,
    DateTime timeRangeEnd, {
    Set<String>? requireEpgChannelIds,
  }) async {
    final liveStreams = await _database.getLiveStreamsPaginated(
      playlistId,
      offset: offset,
      limit: limit,
      excludedCategoryIds: _hiddenCategoryIds,
      excludedStreamIds: _hiddenStreamIds,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      requireEpgChannelIds: requireEpgChannelIds,
    );

    if (liveStreams.isEmpty) return [];

    // Get EPG channel mapping
    final epgChannels = await _epgRepository.getEpgChannels(playlistId);
    final mapping = _matchingService.buildChannelEpgMapping(liveStreams, epgChannels);

    // Collect EPG channel IDs for batch query
    // Use direct epgChannelId from stream if no mapping (EPG channels might not be stored separately)
    final epgChannelIds = <String>[];
    final streamToEpgMap = <String, String>{};
    for (final stream in liveStreams) {
      // Try mapping first, then direct epgChannelId from stream
      String? epgId = mapping[stream.streamId];
      if (epgId == null || epgId.isEmpty) {
        epgId = stream.epgChannelId.isNotEmpty ? stream.epgChannelId : null;
      }
      if (epgId != null && epgId.isNotEmpty) {
        epgChannelIds.add(epgId);
        streamToEpgMap[stream.streamId] = epgId;
      }
    }

    // Batch load EPG programs
    final epgProgramsMap = await _database.getEpgProgramsForChannelsBatch(
      epgChannelIds,
      playlistId,
      timeRangeStart,
      timeRangeEnd,
    );

    // If no EPG data found, try fallback search by normalized channel name
    if (epgProgramsMap.isEmpty) {
      // Try to find EPG programs by searching for channel names in the EPG data
      for (final stream in liveStreams) {
        if (streamToEpgMap.containsKey(stream.streamId)) continue; // Already has EPG

        // Extract potential channel name (remove prefix)
        final channelName = _extractChannelName(stream.name);
        if (channelName.isEmpty) continue;

        // Search EPG channels for a match
        final matchingChannel = epgChannels.firstWhere(
          (c) => _extractChannelName(c.displayName).toLowerCase() == channelName.toLowerCase(),
          orElse: () => EpgChannel(channelId: '', playlistId: '', displayName: '', lastUpdated: DateTime.now()),
        );

        if (matchingChannel.channelId.isNotEmpty) {
          epgChannelIds.add(matchingChannel.channelId);
          streamToEpgMap[stream.streamId] = matchingChannel.channelId;
        }
      }

      // Re-query if we found new matches
      if (epgChannelIds.isNotEmpty) {
        final fallbackProgramsMap = await _database.getEpgProgramsForChannelsBatch(
          epgChannelIds,
          playlistId,
          timeRangeStart,
          timeRangeEnd,
        );
        epgProgramsMap.addAll(fallbackProgramsMap);
      }
    }

    // Build TvGuideChannel list
    return liveStreams.map((stream) {
      final epgId = streamToEpgMap[stream.streamId];
      final programsData = epgId != null ? epgProgramsMap[epgId] ?? [] : <EpgProgramData>[];
      final programs = programsData.map((p) => EpgProgram.fromData(p)).toList();
      return TvGuideChannel.fromLiveStream(stream, programs: programs);
    }).toList();
  }

  /// Load a page of M3U channels with EPG data
  Future<List<TvGuideChannel>> _loadM3uChannelsPage(
    String playlistId,
    int offset,
    int limit,
    DateTime timeRangeStart,
    DateTime timeRangeEnd,
  ) async {
    final m3uItems = await _database.getM3uLiveItemsPaginated(
      playlistId,
      offset: offset,
      limit: limit,
      excludedCategoryIds: _hiddenCategoryIds,
      excludedStreamIds: _hiddenStreamIds,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    if (m3uItems.isEmpty) return [];

    // Get EPG channel mapping
    final epgChannels = await _epgRepository.getEpgChannels(playlistId);
    final mapping = _matchingService.buildChannelEpgMapping(m3uItems, epgChannels);

    // Collect EPG channel IDs for batch query
    final epgChannelIds = <String>[];
    final itemToEpgMap = <String, String>{};
    for (final item in m3uItems) {
      final epgId = mapping[item.id] ?? item.tvgId;
      if (epgId != null && epgId.isNotEmpty) {
        epgChannelIds.add(epgId);
        itemToEpgMap[item.id] = epgId;
      }
    }

    // Batch load EPG programs
    final epgProgramsMap = await _database.getEpgProgramsForChannelsBatch(
      epgChannelIds,
      playlistId,
      timeRangeStart,
      timeRangeEnd,
    );

    // Build TvGuideChannel list
    return m3uItems.map((item) {
      final epgId = itemToEpgMap[item.id];
      final programsData = epgId != null ? epgProgramsMap[epgId] ?? [] : <EpgProgramData>[];
      final programs = programsData.map((p) => EpgProgram.fromData(p)).toList();
      return TvGuideChannel.fromM3uItem(item, programs: programs);
    }).toList();
  }

  // Store counts for pagination UI
  int _totalVisibleChannels = 0;
  int _totalFilteredCount = 0;

  /// Refresh channel data (re-fetches EPG)
  Future<void> refresh() async {
    await loadChannels(fetchEpgFirst: true);
  }

  /// Force refresh EPG data from server
  Future<void> forceRefreshEpg() async {
    await fetchEpgData(force: true);
    await loadChannels(fetchEpgFirst: false);
  }

  /// Scroll timeline by a duration
  void scrollTimelineBy(Duration duration) {
    _viewStartTime = _viewStartTime.add(duration);
    _notifyIfNotDisposed();
    // Reload programs for new time range (don't re-fetch EPG, preserve page)
    loadChannels(fetchEpgFirst: false, resetPage: false);
  }

  /// Jump to current time
  void jumpToNow() {
    _viewStartTime = DateTime.now().subtract(const Duration(minutes: 30));
    _notifyIfNotDisposed();
    loadChannels(fetchEpgFirst: false, resetPage: false);
  }

  /// Set the visible hours
  void setVisibleHours(int hours) {
    _visibleHours = hours.clamp(2, 12);
    _notifyIfNotDisposed();
    loadChannels(fetchEpgFirst: false);
  }

  /// Set view start time
  void setViewStartTime(DateTime time) {
    _viewStartTime = time;
    _notifyIfNotDisposed();
    loadChannels(fetchEpgFirst: false);
  }

  /// Toggle showing channels without EPG data
  void setShowChannelsWithoutEpg(bool show) {
    _showChannelsWithoutEpg = show;
    _currentPage = 0;
    loadChannels(fetchEpgFirst: false, resetPage: false);
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 0; // Reset to first page on search
    loadChannels(fetchEpgFirst: false, resetPage: false);
  }

  /// Clear search query
  void clearSearch() {
    _searchQuery = '';
    _currentPage = 0; // Reset to first page on search clear
    loadChannels(fetchEpgFirst: false, resetPage: false);
  }

  /// Go to next page
  Future<void> nextPage() async {
    if (hasNextPage) {
      _currentPage++;
      await loadChannels(fetchEpgFirst: false, resetPage: false);
    }
  }

  /// Go to previous page
  Future<void> previousPage() async {
    if (hasPreviousPage) {
      _currentPage--;
      await loadChannels(fetchEpgFirst: false, resetPage: false);
    }
  }

  /// Go to specific page
  Future<void> goToPage(int page) async {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      await loadChannels(fetchEpgFirst: false, resetPage: false);
    }
  }

  /// Set channels per page and save to preferences
  Future<void> setChannelsPerPage(int count) async {
    _channelsPerPage = count.clamp(10, 500);
    _currentPage = 0; // Reset to first page
    await UserPreferences.setTvGuideChannelLimit(_channelsPerPage);
    await loadChannels(fetchEpgFirst: false, resetPage: false);
  }

  /// Get the X position for a given time
  double getXPositionForTime(DateTime time) {
    final diff = time.difference(_viewStartTime).inMinutes;
    return diff * _pixelsPerMinute;
  }

  /// Get the time for a given X position
  DateTime getTimeForXPosition(double x) {
    final minutes = (x / _pixelsPerMinute).round();
    return _viewStartTime.add(Duration(minutes: minutes));
  }

  /// Get current time indicator position
  double get currentTimePosition {
    return getXPositionForTime(DateTime.now());
  }

  /// Calculate width for a program cell
  double getProgramWidth(EpgProgram program) {
    // Clamp to visible range
    final effectiveStart = program.startTime.isBefore(_viewStartTime)
        ? _viewStartTime
        : program.startTime;
    final effectiveEnd = program.endTime.isAfter(viewEndTime)
        ? viewEndTime
        : program.endTime;

    final duration = effectiveEnd.difference(effectiveStart).inMinutes;
    return duration * _pixelsPerMinute;
  }

  /// Calculate X offset for a program cell
  double getProgramOffset(EpgProgram program) {
    final effectiveStart = program.startTime.isBefore(_viewStartTime)
        ? _viewStartTime
        : program.startTime;
    return getXPositionForTime(effectiveStart);
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return;
    _isLoading = loading;
    _notifyIfNotDisposed();
  }

  void _setError(String? error) {
    if (_isDisposed) return;
    _errorMessage = error;
    _notifyIfNotDisposed();
  }

  void _notifyIfNotDisposed() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void clearError() {
    _setError(null);
  }

  /// Extract channel name by removing common prefixes like "SLING:", "US:", "HU:", etc.
  String _extractChannelName(String name) {
    var result = name.trim();

    // Remove common provider/region prefixes (e.g., "SLING:", "US:", "HU:", "UK |")
    result = result.replaceAll(RegExp(r'^[A-Za-z0-9\s]+[\s]*[:\|][\s]*'), '');

    // Remove superscript markers like ᴿᴬᵂ
    result = result.replaceAll(RegExp(r'[ᴬᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᴿˢᵀᵁⱽᵂˣʸᶻ]+'), '');

    // Remove quality indicators
    result = result.replaceAll(RegExp(r'\s*(HD|FHD|UHD|4K|SD)\s*', caseSensitive: false), ' ');

    // Trim and normalize whitespace
    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');

    return result;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
