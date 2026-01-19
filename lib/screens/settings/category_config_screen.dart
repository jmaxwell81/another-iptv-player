import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_configuration.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/category_config_service.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';

/// Item representing either a category or a merged group for display
class CategoryListItem {
  final String id;
  final String displayName;
  final String originalName;
  final bool isMerged;
  final bool isHidden;
  final List<String>? mergedCategoryIds;
  final List<String>? mergedCategoryNames;

  CategoryListItem({
    required this.id,
    required this.displayName,
    required this.originalName,
    this.isMerged = false,
    this.isHidden = false,
    this.mergedCategoryIds,
    this.mergedCategoryNames,
  });
}

class CategoryConfigScreen extends StatefulWidget {
  final String playlistId;

  const CategoryConfigScreen({
    super.key,
    required this.playlistId,
  });

  @override
  State<CategoryConfigScreen> createState() => _CategoryConfigScreenState();
}

class _CategoryConfigScreenState extends State<CategoryConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CategoryConfig? _config;
  bool _isLoading = true;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _hasHiddenCategoryChanges = false; // Track if hidden categories changed

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showHiddenOnly = false;
  bool _showVisibleOnly = true; // Default to showing visible only

  // Hidden category IDs
  Set<String> _hiddenCategoryIds = {};

  // Categories loaded from repository (ALL categories)
  List<Category> _allLiveCategories = [];
  List<Category> _allVodCategories = [];
  List<Category> _allSeriesCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load hidden categories
    _hiddenCategoryIds = (await UserPreferences.getHiddenCategories()).toSet();

    // Load ALL categories from repository
    // Try Xtream repository first, then M3U repository
    final xtreamRepository = AppState.xtreamRepositories[widget.playlistId] ?? AppState.xtreamCodeRepository;
    final m3uRepository = AppState.m3uRepositories[widget.playlistId] ?? AppState.m3uRepository;

    if (xtreamRepository != null && (AppState.xtreamRepositories.containsKey(widget.playlistId) ||
        (AppState.currentPlaylist?.id == widget.playlistId && AppState.currentPlaylist?.type == PlaylistType.xtream))) {
      // Load from Xtream API
      final liveCategories = await xtreamRepository.getLiveCategories();
      final vodCategories = await xtreamRepository.getVodCategories();
      final seriesCategories = await xtreamRepository.getSeriesCategories();

      _allLiveCategories = liveCategories ?? [];
      _allVodCategories = vodCategories ?? [];
      _allSeriesCategories = seriesCategories ?? [];
    } else if (m3uRepository != null) {
      // Load from M3U database (all categories are stored together)
      final allCategories = await m3uRepository.getCategories();
      if (allCategories != null) {
        // M3U categories are typed, separate them
        _allLiveCategories = allCategories.where((c) => c.type == CategoryType.live).toList();
        _allVodCategories = allCategories.where((c) => c.type == CategoryType.vod).toList();
        _allSeriesCategories = allCategories.where((c) => c.type == CategoryType.series).toList();
      }
    }

    // Load config
    final config = await CategoryConfigService().getConfig(widget.playlistId);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  List<Category> _getCategoriesForType(CategoryType type) {
    switch (type) {
      case CategoryType.live:
        return _allLiveCategories;
      case CategoryType.vod:
        return _allVodCategories;
      case CategoryType.series:
        return _allSeriesCategories;
    }
  }

  CategoryType _getCurrentType() {
    switch (_tabController.index) {
      case 0:
        return CategoryType.live;
      case 1:
        return CategoryType.vod;
      case 2:
        return CategoryType.series;
      default:
        return CategoryType.live;
    }
  }

  List<CategoryListItem> _buildOrderedList(CategoryType type) {
    final categories = _getCategoriesForType(type);
    final typeConfig = _config?.getConfigForType(type);

    List<CategoryListItem> allItems = [];

    if (typeConfig == null) {
      allItems = categories.map((c) => CategoryListItem(
        id: c.categoryId,
        displayName: c.categoryName.applyRenamingRules(isCategory: true, itemId: c.categoryId, playlistId: widget.playlistId),
        originalName: c.categoryName,
        isHidden: _hiddenCategoryIds.contains(c.categoryId),
      )).toList();
    } else {
      final categoryMap = <String, Category>{};
      for (final cat in categories) {
        categoryMap[cat.categoryId] = cat;
      }

      final processedIds = <String>{};

      // Process ordered items first
      for (final itemId in typeConfig.order) {
        final mergeGroup = typeConfig.getMergeGroup(itemId);
        if (mergeGroup != null) {
          final mergedNames = mergeGroup.categoryIds
              .map((id) => categoryMap[id]?.categoryName ?? id)
              .toList();
          allItems.add(CategoryListItem(
            id: mergeGroup.id,
            displayName: mergeGroup.displayName,
            originalName: mergeGroup.displayName,
            isMerged: true,
            isHidden: false, // Merged groups can't be hidden individually
            mergedCategoryIds: mergeGroup.categoryIds,
            mergedCategoryNames: mergedNames,
          ));
          processedIds.addAll(mergeGroup.categoryIds);
          processedIds.add(mergeGroup.id);
        } else if (categoryMap.containsKey(itemId) && !typeConfig.isCategoryMerged(itemId)) {
          final cat = categoryMap[itemId]!;
          allItems.add(CategoryListItem(
            id: cat.categoryId,
            displayName: cat.categoryName.applyRenamingRules(isCategory: true, itemId: cat.categoryId, playlistId: widget.playlistId),
            originalName: cat.categoryName,
            isHidden: _hiddenCategoryIds.contains(cat.categoryId),
          ));
          processedIds.add(itemId);
        }
      }

      // Add unordered categories at the end
      for (final cat in categories) {
        if (!processedIds.contains(cat.categoryId) && !typeConfig.isCategoryMerged(cat.categoryId)) {
          allItems.add(CategoryListItem(
            id: cat.categoryId,
            displayName: cat.categoryName.applyRenamingRules(isCategory: true, itemId: cat.categoryId, playlistId: widget.playlistId),
            originalName: cat.categoryName,
            isHidden: _hiddenCategoryIds.contains(cat.categoryId),
          ));
        }
      }
    }

    // Apply filters
    return allItems.where((item) {
      // Filter by hidden/visible
      if (_showHiddenOnly && !item.isHidden) return false;
      if (_showVisibleOnly && item.isHidden) return false;

      // Filter by search
      if (_searchQuery.isNotEmpty) {
        final matchesDisplay = item.displayName.toLowerCase().contains(_searchQuery);
        final matchesOriginal = item.originalName.toLowerCase().contains(_searchQuery);
        final matchesMerged = item.mergedCategoryNames?.any(
          (name) => name.toLowerCase().contains(_searchQuery)
        ) ?? false;
        return matchesDisplay || matchesOriginal || matchesMerged;
      }

      return true;
    }).toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _selectAllVisible() {
    final type = _getCurrentType();
    final items = _buildOrderedList(type);
    setState(() {
      for (final item in items) {
        if (!item.isMerged) {
          _selectedIds.add(item.id);
        }
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _selectBySearch() {
    if (_searchQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a search term first')),
      );
      return;
    }

    final type = _getCurrentType();
    final items = _buildOrderedList(type);
    setState(() {
      for (final item in items) {
        if (!item.isMerged) {
          _selectedIds.add(item.id);
        }
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected ${_selectedIds.length} categories matching "$_searchQuery"')),
    );
  }

  /// Get category name by ID
  String? _getCategoryName(String categoryId) {
    for (final cat in _allLiveCategories) {
      if (cat.categoryId == categoryId) return cat.categoryName;
    }
    for (final cat in _allVodCategories) {
      if (cat.categoryId == categoryId) return cat.categoryName;
    }
    for (final cat in _allSeriesCategories) {
      if (cat.categoryId == categoryId) return cat.categoryName;
    }
    return null;
  }

  Future<void> _bulkHide() async {
    if (_selectedIds.isEmpty) return;

    for (final id in _selectedIds) {
      if (!_hiddenCategoryIds.contains(id)) {
        final name = _getCategoryName(id);
        if (name != null) {
          await UserPreferences.hideCategoryWithName(id, name);
        } else {
          await UserPreferences.hideCategory(id);
        }
        _hasHiddenCategoryChanges = true;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hidden ${_selectedIds.length} categories')),
    );

    _clearSelection();
    await _loadData();
  }

  Future<void> _bulkShow() async {
    if (_selectedIds.isEmpty) return;

    for (final id in _selectedIds) {
      if (_hiddenCategoryIds.contains(id)) {
        final name = _getCategoryName(id);
        if (name != null) {
          await UserPreferences.unhideCategoryWithName(id, name);
        } else {
          await UserPreferences.unhideCategory(id);
        }
        _hasHiddenCategoryChanges = true;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unhidden ${_selectedIds.length} categories')),
    );

    _clearSelection();
    await _loadData();
  }

  Future<void> _mergeSelected() async {
    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 categories to merge')),
      );
      return;
    }

    // Check if any selected item is already a merged group
    final type = _getCurrentType();
    final typeConfig = _config?.getConfigForType(type);
    final hasExistingMerge = _selectedIds.any((id) => typeConfig?.getMergeGroup(id) != null);
    if (hasExistingMerge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot merge already merged groups. Unmerge first.')),
      );
      return;
    }

    final navigator = Navigator.of(context);
    final name = await showDialog<String>(
      context: navigator.context,
      builder: (context) => _MergeNameDialog(selectedCount: _selectedIds.length),
    );

    if (name != null && name.isNotEmpty) {
      await CategoryConfigService().mergeCategories(
        playlistId: widget.playlistId,
        type: type,
        categoryIds: _selectedIds.toList(),
        displayName: name,
      );
      _clearSelection();
      await _loadData();
    }
  }

  Future<void> _unmergeGroup(String mergeGroupId) async {
    final type = _getCurrentType();
    await CategoryConfigService().unmergeCategoryGroup(
      playlistId: widget.playlistId,
      type: type,
      mergeGroupId: mergeGroupId,
    );
    await _loadData();
  }

  Future<void> _moveToPosition(String itemId, int currentIndex) async {
    final navigator = Navigator.of(context);
    final type = _getCurrentType();
    final items = _buildOrderedList(type);

    final newPosition = await showDialog<int>(
      context: navigator.context,
      builder: (context) => _MoveToPositionDialog(
        currentPosition: currentIndex + 1,
        totalItems: items.length,
      ),
    );

    if (newPosition != null && newPosition != currentIndex + 1) {
      await CategoryConfigService().moveCategory(
        playlistId: widget.playlistId,
        type: type,
        itemId: itemId,
        newIndex: newPosition - 1,
      );
      await _loadData();
    }
  }

  Future<void> _renameMergeGroup(String mergeGroupId, String currentName) async {
    final navigator = Navigator.of(context);
    final newName = await showDialog<String>(
      context: navigator.context,
      builder: (context) => _RenameDialog(currentName: currentName),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final type = _getCurrentType();
      await CategoryConfigService().updateMergeGroupName(
        playlistId: widget.playlistId,
        type: type,
        mergeGroupId: mergeGroupId,
        newName: newName,
      );
      await _loadData();
    }
  }

  Future<void> _toggleHideCategory(String categoryId, bool isCurrentlyHidden) async {
    final name = _getCategoryName(categoryId);
    if (isCurrentlyHidden) {
      if (name != null) {
        await UserPreferences.unhideCategoryWithName(categoryId, name);
      } else {
        await UserPreferences.unhideCategory(categoryId);
      }
    } else {
      if (name != null) {
        await UserPreferences.hideCategoryWithName(categoryId, name);
      } else {
        await UserPreferences.hideCategory(categoryId);
      }
    }
    _hasHiddenCategoryChanges = true;
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasHiddenCategoryChanges);
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasHiddenCategoryChanges),
        ),
        title: const Text('Category Configuration'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => _clearSelection(),
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Movies'),
            Tab(text: 'Series'),
          ],
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.visibility_off),
              onPressed: _bulkHide,
              tooltip: 'Hide selected',
            ),
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: _bulkShow,
              tooltip: 'Show selected',
            ),
            IconButton(
              icon: const Icon(Icons.merge),
              onPressed: _selectedIds.length >= 2 ? _mergeSelected : null,
              tooltip: 'Merge selected',
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndFilterBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryList(CategoryType.live),
                      _buildCategoryList(CategoryType.vod),
                      _buildCategoryList(CategoryType.series),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _isSelectionMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _selectedIds.length >= 2 ? _mergeSelected : _bulkHide,
              icon: Icon(_selectedIds.length >= 2 ? Icons.merge : Icons.visibility_off),
              label: Text(_selectedIds.length >= 2
                  ? 'Merge ${_selectedIds.length}'
                  : 'Hide ${_selectedIds.length}'),
            )
          : null,
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Search bar with select button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _searchQuery.isNotEmpty ? _selectBySearch : _selectAllVisible,
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(_searchQuery.isNotEmpty ? 'Select Matches' : 'Select All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Filter chips
          Row(
            children: [
              FilterChip(
                label: const Text('Visible'),
                selected: _showVisibleOnly,
                onSelected: (selected) {
                  setState(() {
                    _showVisibleOnly = selected;
                    if (selected) _showHiddenOnly = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Hidden'),
                selected: _showHiddenOnly,
                onSelected: (selected) {
                  setState(() {
                    _showHiddenOnly = selected;
                    if (selected) _showVisibleOnly = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('All'),
                selected: !_showVisibleOnly && !_showHiddenOnly,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _showVisibleOnly = false;
                      _showHiddenOnly = false;
                    });
                  }
                },
              ),
              const Spacer(),
              if (_selectedIds.isNotEmpty)
                Text(
                  '${_selectedIds.length} selected',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(CategoryType type) {
    final items = _buildOrderedList(type);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No categories match "$_searchQuery"'
                  : 'No categories available',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex--;
        final item = items[oldIndex];
        await CategoryConfigService().moveCategory(
          playlistId: widget.playlistId,
          type: type,
          itemId: item.id,
          newIndex: newIndex,
        );
        await _loadData();
      },
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedIds.contains(item.id);

        return Card(
          key: ValueKey(item.id),
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : item.isHidden
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : null,
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: item.isHidden ? Colors.grey : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!item.isMerged)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(item.id),
                  ),
                if (item.isMerged)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.merge, size: 24),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    style: TextStyle(
                      fontWeight: item.isMerged ? FontWeight.bold : FontWeight.normal,
                      color: item.isHidden ? Colors.grey : null,
                      decoration: item.isHidden ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (item.isHidden)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Hidden',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            subtitle: item.isMerged && item.mergedCategoryNames != null
                ? Text(
                    'Contains: ${item.mergedCategoryNames!.join(", ")}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.isMerged)
                  IconButton(
                    icon: Icon(
                      item.isHidden ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () => _toggleHideCategory(item.id, item.isHidden),
                    tooltip: item.isHidden ? 'Show' : 'Hide',
                  ),
                IconButton(
                  icon: const Icon(Icons.swap_vert, size: 20),
                  onPressed: () => _moveToPosition(item.id, index),
                  tooltip: 'Move to position',
                ),
                if (item.isMerged) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _renameMergeGroup(item.id, item.displayName),
                    tooltip: 'Rename group',
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_split, size: 20),
                    onPressed: () => _unmergeGroup(item.id),
                    tooltip: 'Unmerge',
                  ),
                ],
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            ),
            onTap: item.isMerged ? null : () => _toggleSelection(item.id),
          ),
        );
      },
    );
  }
}

/// Dialog for entering merge group name
class _MergeNameDialog extends StatefulWidget {
  final int selectedCount;

  const _MergeNameDialog({required this.selectedCount});

  @override
  State<_MergeNameDialog> createState() => _MergeNameDialogState();
}

class _MergeNameDialogState extends State<_MergeNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Merge ${widget.selectedCount} Categories'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Merged category name',
          hintText: 'Enter name for merged group',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Merge'),
        ),
      ],
    );
  }
}

/// Dialog for moving to a specific position
class _MoveToPositionDialog extends StatefulWidget {
  final int currentPosition;
  final int totalItems;

  const _MoveToPositionDialog({
    required this.currentPosition,
    required this.totalItems,
  });

  @override
  State<_MoveToPositionDialog> createState() => _MoveToPositionDialogState();
}

class _MoveToPositionDialogState extends State<_MoveToPositionDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPosition.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final newPosition = int.tryParse(_controller.text);
    if (newPosition != null && newPosition >= 1 && newPosition <= widget.totalItems) {
      Navigator.pop(context, newPosition);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a number between 1 and ${widget.totalItems}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move to Position'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current position: ${widget.currentPosition} of ${widget.totalItems}'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'New position',
              hintText: '1 - ${widget.totalItems}',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Move'),
        ),
      ],
    );
  }
}

/// Dialog for renaming a merge group
class _RenameDialog extends StatefulWidget {
  final String currentName;

  const _RenameDialog({required this.currentName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Merged Category'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
