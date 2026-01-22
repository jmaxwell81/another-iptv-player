import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/custom_category.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/custom_category_service.dart';
import 'package:another_iptv_player/widgets/bulk_move_dialog.dart';

/// Settings screen for managing custom categories.
class CustomCategorySettingsScreen extends StatefulWidget {
  const CustomCategorySettingsScreen({super.key});

  @override
  State<CustomCategorySettingsScreen> createState() =>
      _CustomCategorySettingsScreenState();
}

class _CustomCategorySettingsScreenState
    extends State<CustomCategorySettingsScreen> {
  final _categoryService = CustomCategoryService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _categoryService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.custom_categories),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.loc.create_category,
            onPressed: () => _showCreateCategoryDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final categories = _categoryService.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_special, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              context.loc.no_custom_categories,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.loc.custom_categories_desc,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateCategoryDialog(context),
              icon: const Icon(Icons.add),
              label: Text(context.loc.create_category),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final categoryIds = categories.map((c) => c.id).toList();
        final item = categoryIds.removeAt(oldIndex);
        categoryIds.insert(newIndex, item);
        await _categoryService.reorderCategories(categoryIds);
        setState(() {});
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          key: ValueKey(category.id),
          category: category,
          onEdit: () => _showEditCategoryDialog(context, category),
          onDelete: () => _confirmDeleteCategory(context, category),
          onToggleVisibility: () async {
            await _categoryService.toggleCategoryVisibility(category.id);
            setState(() {});
          },
          onViewItems: () => _showCategoryItems(context, category),
          onBulkAdd: () => _showBulkAddDialog(context, category),
        );
      },
    );
  }

  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CategoryEditDialog(),
    );

    if (result != null) {
      await _categoryService.createCategory(
        name: result['name'] as String,
        icon: result['icon'] as String?,
        contentType: result['contentType'] as ContentType?,
      );
      setState(() {});
    }
  }

  Future<void> _showEditCategoryDialog(
      BuildContext context, CustomCategory category) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CategoryEditDialog(category: category),
    );

    if (result != null) {
      await _categoryService.updateCategory(
        category.copyWith(
          name: result['name'] as String,
          icon: result['icon'] as String?,
          contentType: result['contentType'] as ContentType?,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _confirmDeleteCategory(
      BuildContext context, CustomCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.delete_category),
        content: Text(
          context.loc.delete_category_confirm(category.name, category.itemCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.loc.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _categoryService.deleteCategory(category.id);
      setState(() {});
    }
  }

  Future<void> _showBulkAddDialog(BuildContext context, CustomCategory category) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Load content items from current playlist only (much faster)
      final allItems = <ContentItem>[];
      final itemsByCategory = <String, List<ContentItem>>{};
      final playlistId = AppState.currentPlaylist?.id ?? '';

      // Load from current Xtream repository
      if (AppState.xtreamCodeRepository != null) {
        await _loadXtreamContent(
          AppState.xtreamCodeRepository!,
          playlistId,
          allItems,
          itemsByCategory,
          category.contentType,
        );
      }

      // Load from current M3U repository
      if (AppState.m3uRepository != null) {
        await _loadM3uContent(
          AppState.m3uRepository!,
          playlistId,
          allItems,
          itemsByCategory,
          category.contentType,
        );
      }

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (allItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.no_content_loaded)),
          );
        }
        return;
      }

      // Show bulk move dialog with pre-selected category
      if (mounted) {
        await BulkMoveDialog.show(
          context,
          allItems: allItems,
          itemsByCategory: itemsByCategory,
          contentType: category.contentType,
          preSelectedCategoryId: category.id,
        );
        // Refresh the screen after dialog closes
        setState(() {});
      }
    } catch (e) {
      // Close loading indicator
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading content: $e')),
        );
      }
    }
  }

  Future<void> _loadXtreamContent(
    dynamic repo,
    String playlistId,
    List<ContentItem> allItems,
    Map<String, List<ContentItem>> itemsByCategory,
    ContentType? filterType,
  ) async {
    // Load Live streams if no filter or filter is live
    if (filterType == null || filterType == ContentType.liveStream) {
      final categories = await repo.getLiveCategories();
      if (categories != null) {
        for (final cat in categories) {
          // Limit to 50 items per category for faster loading
          final streams = await repo.getLiveChannelsByCategoryId(
            categoryId: cat.categoryId,
            top: 50,
          );
          if (streams != null) {
            final items = streams.map<ContentItem>((x) => ContentItem(
              x.streamId,
              x.name,
              x.streamIcon,
              ContentType.liveStream,
              liveStream: x,
              sourcePlaylistId: playlistId,
              sourceType: PlaylistType.xtream,
            )).toList();
            allItems.addAll(items);
            itemsByCategory[cat.categoryName] = [
              ...(itemsByCategory[cat.categoryName] ?? []),
              ...items,
            ];
          }
        }
      }
    }

    // Load VOD if no filter or filter is vod
    if (filterType == null || filterType == ContentType.vod) {
      final categories = await repo.getVodCategories();
      if (categories != null) {
        for (final cat in categories) {
          // Limit to 50 items per category for faster loading
          final movies = await repo.getMovies(
            categoryId: cat.categoryId,
            top: 50,
          );
          if (movies != null) {
            final items = movies.map<ContentItem>((x) => ContentItem(
              x.streamId,
              x.name,
              x.streamIcon,
              ContentType.vod,
              vodStream: x,
              containerExtension: x.containerExtension,
              sourcePlaylistId: playlistId,
              sourceType: PlaylistType.xtream,
            )).toList();
            allItems.addAll(items);
            itemsByCategory[cat.categoryName] = [
              ...(itemsByCategory[cat.categoryName] ?? []),
              ...items,
            ];
          }
        }
      }
    }

    // Load Series if no filter or filter is series
    if (filterType == null || filterType == ContentType.series) {
      final categories = await repo.getSeriesCategories();
      if (categories != null) {
        for (final cat in categories) {
          // Limit to 50 items per category for faster loading
          final series = await repo.getSeries(
            categoryId: cat.categoryId,
            top: 50,
          );
          if (series != null) {
            final items = series.map<ContentItem>((x) => ContentItem(
              x.seriesId,
              x.name,
              x.cover ?? '',
              ContentType.series,
              seriesStream: x,
              sourcePlaylistId: playlistId,
              sourceType: PlaylistType.xtream,
            )).toList();
            allItems.addAll(items);
            itemsByCategory[cat.categoryName] = [
              ...(itemsByCategory[cat.categoryName] ?? []),
              ...items,
            ];
          }
        }
      }
    }
  }

  Future<void> _loadM3uContent(
    dynamic repo,
    String playlistId,
    List<ContentItem> allItems,
    Map<String, List<ContentItem>> itemsByCategory,
    ContentType? filterType,
  ) async {
    // M3U items are typically live streams
    if (filterType != null && filterType != ContentType.liveStream) return;

    final groups = await repo.getGroups();
    if (groups != null) {
      for (final group in groups) {
        final m3uItems = await repo.getM3uItemsByGroup(group: group.groupTitle);
        if (m3uItems != null) {
          // Limit to 50 items per category for faster loading
          final limitedItems = m3uItems.take(50).toList();
          final items = limitedItems.map<ContentItem>((x) => ContentItem(
            x.url,
            x.name ?? '',
            x.tvgLogo ?? '',
            ContentType.liveStream,
            m3uItem: x,
            sourcePlaylistId: playlistId,
            sourceType: PlaylistType.m3u,
          )).toList();
          allItems.addAll(items);
          itemsByCategory[group.groupTitle] = [
            ...(itemsByCategory[group.groupTitle] ?? []),
            ...items,
          ];
        }
      }
    }
  }

  void _showCategoryItems(BuildContext context, CustomCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (category.icon != null) ...[
                    Text(category.icon!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${category.itemCount} ${context.loc.items}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: category.itemIds.isEmpty
                  ? Center(
                      child: Text(
                        context.loc.no_items_in_category,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: category.itemIds.length,
                      itemBuilder: (context, index) {
                        final itemId = category.itemIds.elementAt(index);
                        return ListTile(
                          leading: const Icon(Icons.movie),
                          title: Text(itemId),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () async {
                              await _categoryService.removeItemsFromCategory(
                                category.id,
                                {itemId},
                              );
                              Navigator.pop(context);
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CustomCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleVisibility;
  final VoidCallback onViewItems;
  final VoidCallback onBulkAdd;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleVisibility,
    required this.onViewItems,
    required this.onBulkAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            if (category.icon != null)
              Text(category.icon!, style: const TextStyle(fontSize: 24))
            else
              const Icon(Icons.folder),
          ],
        ),
        title: Text(
          category.name,
          style: TextStyle(
            color: category.isVisible ? null : Colors.grey,
          ),
        ),
        subtitle: Row(
          children: [
            Text('${category.itemCount} items'),
            if (category.contentType != null) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  _getContentTypeLabel(category.contentType!),
                  style: const TextStyle(fontSize: 10),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                category.isVisible ? Icons.visibility : Icons.visibility_off,
                color: category.isVisible ? null : Colors.grey,
              ),
              onPressed: onToggleVisibility,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'items':
                    onViewItems();
                    break;
                  case 'bulk_add':
                    onBulkAdd();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 8),
                      Text(context.loc.edit),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'items',
                  child: Row(
                    children: [
                      const Icon(Icons.list, size: 20),
                      const SizedBox(width: 8),
                      Text(context.loc.view_items),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'bulk_add',
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_add, size: 20),
                      const SizedBox(width: 8),
                      Text(context.loc.bulk_add_items),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(context.loc.delete,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getContentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.liveStream:
        return 'Live';
      case ContentType.vod:
        return 'Movies';
      case ContentType.series:
        return 'Series';
    }
  }
}

class _CategoryEditDialog extends StatefulWidget {
  final CustomCategory? category;

  const _CategoryEditDialog({this.category});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late TextEditingController _nameController;
  String? _selectedIcon;
  ContentType? _selectedContentType;

  static const List<String> _availableIcons = [
    '📁', '⭐', '❤️', '🎬', '📺', '🎵', '🎮', '📰', '🏈', '⚽',
    '🏀', '🎾', '🏎️', '🎭', '🎪', '🌍', '🇺🇸', '🇬🇧', '🇪🇸', '🇫🇷',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.icon;
    _selectedContentType = widget.category?.contentType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      title: Text(isEditing
          ? context.loc.edit_category
          : context.loc.create_category),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.loc.category_name,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            Text(
              context.loc.icon,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // No icon option
                GestureDetector(
                  onTap: () => setState(() => _selectedIcon = null),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedIcon == null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        width: _selectedIcon == null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Icon(Icons.folder, size: 20)),
                  ),
                ),
                ..._availableIcons.map((icon) {
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              context.loc.content_type_filter,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.loc.all),
                  selected: _selectedContentType == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedContentType = null);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Live'),
                  selected: _selectedContentType == ContentType.liveStream,
                  onSelected: (selected) {
                    setState(() => _selectedContentType =
                        selected ? ContentType.liveStream : null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Movies'),
                  selected: _selectedContentType == ContentType.vod,
                  onSelected: (selected) {
                    setState(() => _selectedContentType =
                        selected ? ContentType.vod : null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Series'),
                  selected: _selectedContentType == ContentType.series,
                  onSelected: (selected) {
                    setState(() => _selectedContentType =
                        selected ? ContentType.series : null);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            Navigator.pop(context, {
              'name': name,
              'icon': _selectedIcon,
              'contentType': _selectedContentType,
            });
          },
          child: Text(isEditing ? context.loc.save : context.loc.create),
        ),
      ],
    );
  }
}
