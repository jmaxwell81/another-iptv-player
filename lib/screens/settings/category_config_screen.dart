import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_configuration.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/category_config_service.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';

/// Item representing either a category or a merged group for display
class CategoryListItem {
  final String id;
  final String displayName;
  final bool isMerged;
  final List<String>? mergedCategoryIds;
  final List<String>? mergedCategoryNames;

  CategoryListItem({
    required this.id,
    required this.displayName,
    this.isMerged = false,
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

  // Categories loaded from repository
  List<Category> _liveCategories = [];
  List<Category> _vodCategories = [];
  List<Category> _seriesCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load hidden categories
    final hiddenCategoryIds = (await UserPreferences.getHiddenCategories()).toSet();

    // Load categories from repository
    final repository = AppState.xtreamCodeRepository;
    if (repository != null) {
      final liveCategories = await repository.getLiveCategories();
      final vodCategories = await repository.getVodCategories();
      final seriesCategories = await repository.getSeriesCategories();

      // Filter out hidden categories
      _liveCategories = (liveCategories ?? [])
          .where((c) => !hiddenCategoryIds.contains(c.categoryId))
          .toList();
      _vodCategories = (vodCategories ?? [])
          .where((c) => !hiddenCategoryIds.contains(c.categoryId))
          .toList();
      _seriesCategories = (seriesCategories ?? [])
          .where((c) => !hiddenCategoryIds.contains(c.categoryId))
          .toList();
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
        return _liveCategories;
      case CategoryType.vod:
        return _vodCategories;
      case CategoryType.series:
        return _seriesCategories;
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

    if (typeConfig == null) {
      return categories.map((c) => CategoryListItem(
        id: c.categoryId,
        displayName: c.categoryName.applyRenamingRules(isCategory: true, itemId: c.categoryId, playlistId: widget.playlistId),
      )).toList();
    }

    final categoryMap = <String, Category>{};
    for (final cat in categories) {
      categoryMap[cat.categoryId] = cat;
    }

    final result = <CategoryListItem>[];
    final processedIds = <String>{};

    // Process ordered items first
    for (final itemId in typeConfig.order) {
      final mergeGroup = typeConfig.getMergeGroup(itemId);
      if (mergeGroup != null) {
        final mergedNames = mergeGroup.categoryIds
            .map((id) => categoryMap[id]?.categoryName ?? id)
            .toList();
        result.add(CategoryListItem(
          id: mergeGroup.id,
          displayName: mergeGroup.displayName,
          isMerged: true,
          mergedCategoryIds: mergeGroup.categoryIds,
          mergedCategoryNames: mergedNames,
        ));
        processedIds.addAll(mergeGroup.categoryIds);
        processedIds.add(mergeGroup.id);
      } else if (categoryMap.containsKey(itemId) && !typeConfig.isCategoryMerged(itemId)) {
        final cat = categoryMap[itemId]!;
        result.add(CategoryListItem(
          id: cat.categoryId,
          displayName: cat.categoryName.applyRenamingRules(isCategory: true, itemId: cat.categoryId, playlistId: widget.playlistId),
        ));
        processedIds.add(itemId);
      }
    }

    // Add unordered categories at the end
    for (final cat in categories) {
      if (!processedIds.contains(cat.categoryId) && !typeConfig.isCategoryMerged(cat.categoryId)) {
        result.add(CategoryListItem(
          id: cat.categoryId,
          displayName: cat.categoryName.applyRenamingRules(isCategory: true, itemId: cat.categoryId, playlistId: widget.playlistId),
        ));
      }
    }

    return result;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(CategoryType.live),
                _buildCategoryList(CategoryType.vod),
                _buildCategoryList(CategoryType.series),
              ],
            ),
      floatingActionButton: _isSelectionMode && _selectedIds.length >= 2
          ? FloatingActionButton.extended(
              onPressed: _mergeSelected,
              icon: const Icon(Icons.merge),
              label: Text('Merge ${_selectedIds.length}'),
            )
          : null,
    );
  }

  Widget _buildCategoryList(CategoryType type) {
    final items = _buildOrderedList(type);

    if (items.isEmpty) {
      return const Center(
        child: Text('No categories available'),
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
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
            title: Text(
              item.displayName,
              style: TextStyle(
                fontWeight: item.isMerged ? FontWeight.bold : FontWeight.normal,
              ),
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
