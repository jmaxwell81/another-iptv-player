import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/custom_category_service.dart';

/// Sort options for the bulk add dialog
enum BulkSortOption {
  nameAsc,
  nameDesc,
  ratingAsc,
  ratingDesc,
  genreAsc,
  genreDesc,
}

/// Dialog for searching and bulk moving items into custom categories.
/// Features pagination, search, sorting, filtering, and multi-category selection.
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
  double? _minRatingFilter;
  String? _genreFilter;

  // Sorting
  BulkSortOption _sortOption = BulkSortOption.nameAsc;

  // Results
  List<ContentItem> _filteredItems = [];
  Set<String> _selectedItems = {};

  // Multi-category selection
  Set<String> _selectedTargetCategoryIds = {};
  bool _isCreatingCategory = false;
  final _newCategoryController = TextEditingController();

  // Available genres (extracted from items)
  List<String> _availableGenres = [];

  @override
  void initState() {
    super.initState();
    _categoryService.initialize();

    // Pre-select category if provided
    if (widget.preSelectedCategoryId != null) {
      _selectedTargetCategoryIds.add(widget.preSelectedCategoryId!);
    }

    // Set initial type filter from widget
    _selectedTypeFilter = widget.contentType;

    // Extract available genres
    _extractGenres();

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

  void _extractGenres() {
    final genres = <String>{};
    for (final item in widget.allItems) {
      final genre = _getItemGenre(item);
      if (genre != null && genre.isNotEmpty) {
        // Split genres by comma and add each one
        for (final g in genre.split(',')) {
          final trimmed = g.trim();
          if (trimmed.isNotEmpty) {
            genres.add(trimmed);
          }
        }
      }
    }
    _availableGenres = genres.toList()..sort();
  }

  String? _getItemGenre(ContentItem item) {
    if (item.vodStream != null) {
      return item.vodStream!.genre;
    } else if (item.seriesStream != null) {
      return item.seriesStream!.genre;
    }
    return null;
  }

  double? _getItemRating(ContentItem item) {
    if (item.vodStream != null) {
      return item.vodStream!.rating5based;
    } else if (item.seriesStream != null) {
      return item.seriesStream!.rating5based;
    }
    return null;
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
        // Search in genre
        final genre = _getItemGenre(item);
        if (genre != null && genre.toLowerCase().contains(searchPattern)) {
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

    // Filter by minimum rating
    if (_minRatingFilter != null) {
      items = items.where((item) {
        final rating = _getItemRating(item);
        return rating != null && rating >= _minRatingFilter!;
      }).toList();
    }

    // Filter by genre
    if (_genreFilter != null && _genreFilter!.isNotEmpty) {
      items = items.where((item) {
        final genre = _getItemGenre(item);
        if (genre == null) return false;
        return genre.toLowerCase().contains(_genreFilter!.toLowerCase());
      }).toList();
    }

    // Remove duplicates
    final uniqueItems = <String, ContentItem>{};
    for (final item in items) {
      uniqueItems[item.id] = item;
    }

    // Sort items
    var sortedItems = uniqueItems.values.toList();
    switch (_sortOption) {
      case BulkSortOption.nameAsc:
        sortedItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case BulkSortOption.nameDesc:
        sortedItems.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case BulkSortOption.ratingAsc:
        sortedItems.sort((a, b) {
          final ratingA = _getItemRating(a) ?? 0;
          final ratingB = _getItemRating(b) ?? 0;
          return ratingA.compareTo(ratingB);
        });
        break;
      case BulkSortOption.ratingDesc:
        sortedItems.sort((a, b) {
          final ratingA = _getItemRating(a) ?? 0;
          final ratingB = _getItemRating(b) ?? 0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case BulkSortOption.genreAsc:
        sortedItems.sort((a, b) {
          final genreA = _getItemGenre(a) ?? '';
          final genreB = _getItemGenre(b) ?? '';
          return genreA.toLowerCase().compareTo(genreB.toLowerCase());
        });
        break;
      case BulkSortOption.genreDesc:
        sortedItems.sort((a, b) {
          final genreA = _getItemGenre(a) ?? '';
          final genreB = _getItemGenre(b) ?? '';
          return genreB.toLowerCase().compareTo(genreA.toLowerCase());
        });
        break;
    }

    setState(() {
      _filteredItems = sortedItems;
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
    if (_selectedItems.isEmpty || _selectedTargetCategoryIds.isEmpty) return;

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

    // Add items to all selected categories
    final categoryNames = <String>[];
    for (final categoryId in _selectedTargetCategoryIds) {
      await _categoryService.addItemsToCategory(
        categoryId,
        itemsToAdd,
        originalCategoryName: originalCategoryName,
      );
      final category = _categoryService.getCategoryById(categoryId);
      if (category != null) {
        categoryNames.add(category.name);
      }
    }

    if (mounted) {
      final categoriesText = categoryNames.length == 1
          ? '"${categoryNames.first}"'
          : '${categoryNames.length} categories';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${_selectedItems.length} items to $categoriesText'),
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
      _selectedTargetCategoryIds.add(category.id);
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

  String _getSortLabel(BulkSortOption option) {
    switch (option) {
      case BulkSortOption.nameAsc:
        return 'Name (A-Z)';
      case BulkSortOption.nameDesc:
        return 'Name (Z-A)';
      case BulkSortOption.ratingAsc:
        return 'Rating (Low-High)';
      case BulkSortOption.ratingDesc:
        return 'Rating (High-Low)';
      case BulkSortOption.genreAsc:
        return 'Genre (A-Z)';
      case BulkSortOption.genreDesc:
        return 'Genre (Z-A)';
    }
  }

  String _buildItemSubtitle(ContentItem item) {
    final parts = <String>[];

    // Add content type
    parts.add(_getTypeLabel(item.contentType));

    // Add rating if available
    final rating = _getItemRating(item);
    if (rating != null && rating > 0) {
      parts.add('${rating.toStringAsFixed(1)}/5');
    }

    // Add genre if available
    final genre = _getItemGenre(item);
    if (genre != null && genre.isNotEmpty) {
      // Truncate long genre strings
      final displayGenre = genre.length > 30 ? '${genre.substring(0, 27)}...' : genre;
      parts.add(displayGenre);
    }

    return parts.join(' • ');
  }

  String _buildItemTitle(ContentItem item) {
    final rating = _getItemRating(item);
    if (rating != null && rating > 0) {
      return '${item.name} (${rating.toStringAsFixed(1)})';
    }
    return item.name;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categoryService.getCategoriesForType(_selectedTypeFilter ?? widget.contentType);
    final theme = Theme.of(context);
    final visibleItems = _filteredItems.take(_visibleCount).toList();
    final hasMore = _visibleCount < _filteredItems.length;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        constraints: const BoxConstraints(maxWidth: 900),
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

              // Search and filters row
              Row(
                children: [
                  // Search field
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search',
                        hintText: 'Search by name, genre, or category...',
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
                  ),
                  const SizedBox(width: 8),
                  // Sort dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<BulkSortOption>(
                      value: _sortOption,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.sort),
                      ),
                      items: BulkSortOption.values.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(_getSortLabel(option), style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortOption = value);
                          _applyFilters();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Advanced filters row
              Row(
                children: [
                  // Rating filter
                  Expanded(
                    child: DropdownButtonFormField<double?>(
                      value: _minRatingFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Min Rating',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.star),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Any'),
                        ),
                        ...[1.0, 2.0, 3.0, 3.5, 4.0, 4.5].map((rating) {
                          return DropdownMenuItem(
                            value: rating,
                            child: Text('$rating+'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _minRatingFilter = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Genre filter
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      value: _genreFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Genre',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Any Genre'),
                        ),
                        ..._availableGenres.map((genre) {
                          return DropdownMenuItem(
                            value: genre,
                            child: Text(
                              genre.length > 25 ? '${genre.substring(0, 22)}...' : genre,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _genreFilter = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Clear filters button
                  if (_minRatingFilter != null || _genreFilter != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _minRatingFilter = null;
                          _genreFilter = null;
                        });
                        _applyFilters();
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                    ),
                ],
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
                          _searchController.text.isEmpty && _minRatingFilter == null && _genreFilter == null
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
                          final rating = _getItemRating(item);

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
                              _buildItemTitle(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _buildItemSubtitle(item),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondary: Stack(
                              children: [
                                _buildItemIcon(item),
                                if (rating != null && rating > 0)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _getRatingColor(rating),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            dense: true,
                          );
                        },
                      ),
              ),

              const Divider(),

              // Target categories (multi-select)
              Text(
                'Add to Categories (select multiple)',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          context.loc.no_custom_categories,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final isSelected = _selectedTargetCategoryIds.contains(category.id);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: isSelected
                                    ? const Icon(Icons.check, size: 18)
                                    : (category.icon != null
                                        ? Text(category.icon!, style: const TextStyle(fontSize: 16))
                                        : const Icon(Icons.folder, size: 18)),
                                label: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : null,
                                      ),
                                    ),
                                    Text(
                                      '${category.itemCount} items',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTargetCategoryIds.add(category.id);
                                    } else {
                                      _selectedTargetCategoryIds.remove(category.id);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_selectedTargetCategoryIds.isNotEmpty)
                    Text(
                      '${_selectedTargetCategoryIds.length} ${_selectedTargetCategoryIds.length == 1 ? 'category' : 'categories'} selected',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.loc.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _selectedItems.isEmpty || _selectedTargetCategoryIds.isEmpty
                            ? null
                            : _addItems,
                        icon: const Icon(Icons.playlist_add),
                        label: Text('Add ${_selectedItems.length} to ${_selectedTargetCategoryIds.length} ${_selectedTargetCategoryIds.length == 1 ? 'Category' : 'Categories'}'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.0) return Colors.orange;
    if (rating >= 2.0) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildItemIcon(ContentItem item) {
    if (item.imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          item.imagePath,
          width: 48,
          height: 48,
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}
