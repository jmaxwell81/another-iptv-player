import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/custom_category_service.dart';

/// Dialog for searching and bulk moving items into custom categories.
/// Features pagination, search, and content type filtering.
class BulkMoveDialog extends StatefulWidget {
  /// All available content items to search from
  final List<ContentItem> allItems;

  /// Items grouped by their original category
  final Map<String, List<ContentItem>> itemsByCategory;

  /// Content type filter (optional)
  final ContentType? contentType;

  /// Pre-selected target category ID (optional)
  final String? preSelectedCategoryId;

  const BulkMoveDialog({
    super.key,
    required this.allItems,
    required this.itemsByCategory,
    this.contentType,
    this.preSelectedCategoryId,
  });

  @override
  State<BulkMoveDialog> createState() => _BulkMoveDialogState();

  /// Show the dialog
  static Future<void> show(
    BuildContext context, {
    required List<ContentItem> allItems,
    required Map<String, List<ContentItem>> itemsByCategory,
    ContentType? contentType,
    String? preSelectedCategoryId,
  }) {
    return showDialog(
      context: context,
      builder: (context) => BulkMoveDialog(
        allItems: allItems,
        itemsByCategory: itemsByCategory,
        contentType: contentType,
        preSelectedCategoryId: preSelectedCategoryId,
      ),
    );
  }
}

class _BulkMoveDialogState extends State<BulkMoveDialog> {
  final _searchController = TextEditingController();
  final _categoryService = CustomCategoryService();
  final _scrollController = ScrollController();

  // Pagination
  static const int _pageSize = 100;
  int _visibleCount = _pageSize;

  // Filtering
  ContentType? _selectedTypeFilter;

  // Results
  List<ContentItem> _filteredItems = [];
  Set<String> _selectedItems = {};

  // Category selection
  String? _selectedTargetCategoryId;
  bool _isCreatingCategory = false;
  final _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categoryService.initialize();

    // Pre-select category if provided
    if (widget.preSelectedCategoryId != null) {
      _selectedTargetCategoryId = widget.preSelectedCategoryId;
    }

    // Set initial type filter from widget
    _selectedTypeFilter = widget.contentType;

    // Load initial items
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newCategoryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final searchPattern = _searchController.text.trim().toLowerCase();

    // Start with all items
    List<ContentItem> items = widget.allItems;

    // Filter by content type
    if (_selectedTypeFilter != null) {
      items = items.where((item) => item.contentType == _selectedTypeFilter).toList();
    }

    // Filter by search pattern
    if (searchPattern.isNotEmpty) {
      items = items.where((item) {
        // Search in item name
        if (item.name.toLowerCase().contains(searchPattern)) {
          return true;
        }
        // Search in category names
        for (final entry in widget.itemsByCategory.entries) {
          if (entry.key.toLowerCase().contains(searchPattern) &&
              entry.value.any((i) => i.id == item.id)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    // Remove duplicates and sort
    final uniqueItems = <String, ContentItem>{};
    for (final item in items) {
      uniqueItems[item.id] = item;
    }

    setState(() {
      _filteredItems = uniqueItems.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _visibleCount = _pageSize;
    });
  }

  void _loadMore() {
    setState(() {
      _visibleCount += _pageSize;
    });
  }

  void _toggleSelectAll() {
    final visibleItems = _filteredItems.take(_visibleCount).toList();
    final allSelected = visibleItems.every((i) => _selectedItems.contains(i.id));

    setState(() {
      if (allSelected) {
        for (final item in visibleItems) {
          _selectedItems.remove(item.id);
        }
      } else {
        for (final item in visibleItems) {
          _selectedItems.add(item.id);
        }
      }
    });
  }

  Future<void> _addItems() async {
    if (_selectedItems.isEmpty || _selectedTargetCategoryId == null) return;

    final itemsToAdd = widget.allItems
        .where((item) => _selectedItems.contains(item.id))
        .toList();

    String? originalCategoryName;
    for (final entry in widget.itemsByCategory.entries) {
      if (entry.value.any((item) => _selectedItems.contains(item.id))) {
        originalCategoryName = entry.key;
        break;
      }
    }

    await _categoryService.addItemsToCategory(
      _selectedTargetCategoryId!,
      itemsToAdd,
      originalCategoryName: originalCategoryName,
    );

    if (mounted) {
      final category = _categoryService.getCategoryById(_selectedTargetCategoryId!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${_selectedItems.length} items to "${category?.name ?? 'category'}"'),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _createAndSelectCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;

    final category = await _categoryService.createCategory(
      name: name,
      contentType: _selectedTypeFilter ?? widget.contentType,
    );

    setState(() {
      _selectedTargetCategoryId = category.id;
      _isCreatingCategory = false;
      _newCategoryController.clear();
    });
  }

  String _getTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.liveStream:
        return 'Live';
      case ContentType.vod:
        return 'Movies';
      case ContentType.series:
        return 'Series';
    }
  }

  int _getCountForType(ContentType? type) {
    if (type == null) return widget.allItems.length;
    return widget.allItems.where((i) => i.contentType == type).length;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categoryService.getCategoriesForType(_selectedTypeFilter ?? widget.contentType);
    final theme = Theme.of(context);
    final visibleItems = _filteredItems.take(_visibleCount).toList();
    final hasMore = _visibleCount < _filteredItems.length;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.playlist_add),
                  const SizedBox(width: 8),
                  Text(
                    context.loc.bulk_add_items,
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Type filter chips
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text('All (${_getCountForType(null)})'),
                    selected: _selectedTypeFilter == null,
                    onSelected: (_) {
                      setState(() => _selectedTypeFilter = null);
                      _applyFilters();
                    },
                  ),
                  FilterChip(
                    label: Text('Live (${_getCountForType(ContentType.liveStream)})'),
                    selected: _selectedTypeFilter == ContentType.liveStream,
                    onSelected: (_) {
                      setState(() => _selectedTypeFilter = ContentType.liveStream);
                      _applyFilters();
                    },
                  ),
                  FilterChip(
                    label: Text('Movies (${_getCountForType(ContentType.vod)})'),
                    selected: _selectedTypeFilter == ContentType.vod,
                    onSelected: (_) {
                      setState(() => _selectedTypeFilter = ContentType.vod);
                      _applyFilters();
                    },
                  ),
                  FilterChip(
                    label: Text('Series (${_getCountForType(ContentType.series)})'),
                    selected: _selectedTypeFilter == ContentType.series,
                    onSelected: (_) {
                      setState(() => _selectedTypeFilter = ContentType.series);
                      _applyFilters();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  hintText: 'Search by name or category...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (_) => _applyFilters(),
              ),
              const SizedBox(height: 8),

              // Stats row
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Showing ${visibleItems.length} of ${_filteredItems.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_selectedItems.isNotEmpty)
                    Chip(
                      label: Text('${_selectedItems.length} selected'),
                      deleteIcon: const Icon(Icons.clear, size: 16),
                      onDeleted: () => setState(() => _selectedItems.clear()),
                    ),
                  TextButton.icon(
                    onPressed: visibleItems.isEmpty ? null : _toggleSelectAll,
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Select All Visible'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items list
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No items available'
                              : 'No matches found',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: visibleItems.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= visibleItems.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: ElevatedButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.expand_more),
                                  label: Text('Load More (${_filteredItems.length - visibleItems.length} more)'),
                                ),
                              ),
                            );
                          }

                          final item = visibleItems[index];
                          final isSelected = _selectedItems.contains(item.id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedItems.add(item.id);
                                } else {
                                  _selectedItems.remove(item.id);
                                }
                              });
                            },
                            title: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _getTypeLabel(item.contentType),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                            secondary: _buildItemIcon(item),
                            dense: true,
                          );
                        },
                      ),
              ),

              const Divider(),

              // Target category
              Text(
                context.loc.move_to_category,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              if (_isCreatingCategory)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: context.loc.new_category_name,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _createAndSelectCategory(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _createAndSelectCategory,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isCreatingCategory = false;
                          _newCategoryController.clear();
                        });
                      },
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: categories.isEmpty
                          ? Text(
                              context.loc.no_custom_categories,
                              style: const TextStyle(color: Colors.grey),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedTargetCategoryId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                isDense: true,
                                hintText: context.loc.select_category,
                              ),
                              items: categories.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.icon != null ? '${c.icon} ${c.name} (${c.itemCount})' : '${c.name} (${c.itemCount})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedTargetCategoryId = value);
                              },
                            ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isCreatingCategory = true),
                      icon: const Icon(Icons.add),
                      label: Text(context.loc.new_category),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.loc.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedItems.isEmpty || _selectedTargetCategoryId == null
                        ? null
                        : _addItems,
                    icon: const Icon(Icons.playlist_add),
                    label: Text('Add ${_selectedItems.length} Items'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildItemIcon(ContentItem item) {
    if (item.imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          item.imagePath,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildTypeIcon(item.contentType),
        ),
      );
    }
    return _buildTypeIcon(item.contentType);
  }

  Widget _buildTypeIcon(ContentType type) {
    IconData icon;
    Color color;
    switch (type) {
      case ContentType.liveStream:
        icon = Icons.live_tv;
        color = Colors.red;
      case ContentType.vod:
        icon = Icons.movie;
        color = Colors.blue;
      case ContentType.series:
        icon = Icons.tv;
        color = Colors.purple;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}
