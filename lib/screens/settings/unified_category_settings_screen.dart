import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/repositories/unified_content_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';

/// Category settings screen for combined/unified mode
class UnifiedCategorySettingsScreen extends StatefulWidget {
  const UnifiedCategorySettingsScreen({super.key});

  @override
  State<UnifiedCategorySettingsScreen> createState() =>
      _UnifiedCategorySettingsScreenState();
}

class _UnifiedCategorySettingsScreenState
    extends State<UnifiedCategorySettingsScreen> {
  final UnifiedContentRepository _repository = UnifiedContentRepository();

  Set<String> _hiddenCategoryIds = {};
  Set<String> _hiddenCategoryNames = {};
  bool _hasChanges = false;
  bool _isLoading = true;

  List<CategoryViewModel> _liveCategories = [];
  List<CategoryViewModel> _movieCategories = [];
  List<CategoryViewModel> _seriesCategories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load hidden categories (both IDs and names for cross-source matching)
      final hiddenIds = await UserPreferences.getHiddenCategories();
      final hiddenNames = await UserPreferences.getHiddenCategoryNames();
      _hiddenCategoryIds = hiddenIds.toSet();
      _hiddenCategoryNames = hiddenNames.toSet();

      // Load categories from all active sources
      final results = await Future.wait([
        _repository.getUnifiedCategories(type: CategoryType.live),
        _repository.getUnifiedCategories(type: CategoryType.vod),
        _repository.getUnifiedCategories(type: CategoryType.series),
      ]);

      _liveCategories = results[0];
      _movieCategories = results[1];
      _seriesCategories = results[2];
    } catch (e) {
      debugPrint('UnifiedCategorySettingsScreen: Error loading data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHidden(bool isVisible, String categoryId, String categoryName) async {
    final normalizedName = categoryName.toLowerCase().trim();
    setState(() {
      _hasChanges = true;
      if (isVisible) {
        _hiddenCategoryIds.remove(categoryId);
        _hiddenCategoryNames.remove(normalizedName);
      } else {
        _hiddenCategoryIds.add(categoryId);
        _hiddenCategoryNames.add(normalizedName);
      }
    });
    // Save both ID and name for cross-source matching
    if (isVisible) {
      await UserPreferences.unhideCategoryWithName(categoryId, categoryName);
    } else {
      await UserPreferences.hideCategoryWithName(categoryId, categoryName);
    }
  }

  Future<void> _setAllCategoriesVisible(
      List<CategoryViewModel> categories, bool visible) async {
    setState(() {
      _hasChanges = true;
      if (visible) {
        _hiddenCategoryIds.removeAll(categories.map((c) => c.category.categoryId));
        _hiddenCategoryNames.removeAll(categories.map((c) => c.category.categoryName.toLowerCase().trim()));
      } else {
        _hiddenCategoryIds.addAll(categories.map((c) => c.category.categoryId));
        _hiddenCategoryNames.addAll(categories.map((c) => c.category.categoryName.toLowerCase().trim()));
      }
    });
    // Save both IDs and names for cross-source matching
    for (final cat in categories) {
      if (visible) {
        await UserPreferences.unhideCategoryWithName(cat.category.categoryId, cat.category.categoryName);
      } else {
        await UserPreferences.hideCategoryWithName(cat.category.categoryId, cat.category.categoryName);
      }
    }
  }

  /// Check if a category is hidden (by ID or by normalized name)
  bool _isCategoryHidden(CategoryViewModel category) {
    if (_hiddenCategoryIds.contains(category.category.categoryId)) {
      return true;
    }
    final normalizedName = category.category.categoryName.toLowerCase().trim();
    return _hiddenCategoryNames.contains(normalizedName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.hide_category),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCategoryList(),
    );
  }

  Widget _buildCategoryList() {
    if (_liveCategories.isEmpty &&
        _movieCategories.isEmpty &&
        _seriesCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text('No categories found'),
            const SizedBox(height: 8),
            const Text('Make sure you have active sources selected'),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Live categories
        if (_liveCategories.isNotEmpty) ...[
          ListTile(
            title: Text(context.loc.live),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _setAllCategoriesVisible(
                  _liveCategories,
                  true,
                ),
                child: Text(context.loc.select_all),
              ),
              TextButton(
                onPressed: () => _setAllCategoriesVisible(
                  _liveCategories,
                  false,
                ),
                child: Text(context.loc.deselect_all),
              ),
            ],
          ),
          ..._liveCategories.map((cat) => _buildCategoryTile(cat)),
        ],

        // Movie categories
        if (_movieCategories.isNotEmpty) ...[
          const Divider(),
          ListTile(
            title: Text(context.loc.movies),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _setAllCategoriesVisible(
                  _movieCategories,
                  true,
                ),
                child: Text(context.loc.select_all),
              ),
              TextButton(
                onPressed: () => _setAllCategoriesVisible(
                  _movieCategories,
                  false,
                ),
                child: Text(context.loc.deselect_all),
              ),
            ],
          ),
          ..._movieCategories.map((cat) => _buildCategoryTile(cat)),
        ],

        // Series categories
        if (_seriesCategories.isNotEmpty) ...[
          const Divider(),
          ListTile(
            title: Text(context.loc.series_plural),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _setAllCategoriesVisible(
                  _seriesCategories,
                  true,
                ),
                child: Text(context.loc.select_all),
              ),
              TextButton(
                onPressed: () => _setAllCategoriesVisible(
                  _seriesCategories,
                  false,
                ),
                child: Text(context.loc.deselect_all),
              ),
            ],
          ),
          ..._seriesCategories.map((cat) => _buildCategoryTile(cat)),
        ],
      ],
    );
  }

  Widget _buildCategoryTile(CategoryViewModel cat) {
    final isHidden = _isCategoryHidden(cat);
    final isMerged = cat.category.categoryId.startsWith('merged_');
    final playlistName = _getPlaylistName(cat.category.playlistId);

    return SwitchListTile(
      title: Text(cat.category.categoryName),
      subtitle: isMerged
          ? Text(
              'Merged from multiple sources',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : playlistName != null
              ? Text(
                  'From: $playlistName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                )
              : null,
      value: !isHidden,
      onChanged: (val) => _toggleHidden(val, cat.category.categoryId, cat.category.categoryName),
    );
  }

  String? _getPlaylistName(String? playlistId) {
    if (playlistId == null || playlistId == 'unified') return null;
    final playlist = AppState.activePlaylists[playlistId];
    return playlist?.name;
  }
}
