import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';
import 'package:another_iptv_player/widgets/rename_dialog.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';

import 'content_item_card_widget.dart';

class CategorySection extends StatefulWidget {
  final CategoryViewModel category;
  final double cardWidth;
  final double cardHeight;
  final VoidCallback? onSeeAllTap;
  final Function(ContentItem)? onContentTap;
  final Set<String>? favoriteStreamIds;
  final Set<String>? hiddenStreamIds;
  final Function(ContentItem)? onToggleFavorite;
  final Function(ContentItem)? onToggleHidden;
  final Function(ContentItem)? onRenameContent;
  final VoidCallback? onRenameCategory;
  final bool showContextMenu;
  final Function(String categoryId, String categoryName)? onHideCategory;
  final String? playlistId;
  final Map<String, EpgProgram>? currentPrograms;

  const CategorySection({
    super.key,
    required this.category,
    required this.cardWidth,
    required this.cardHeight,
    this.onSeeAllTap,
    this.onContentTap,
    this.favoriteStreamIds,
    this.hiddenStreamIds,
    this.onToggleFavorite,
    this.onToggleHidden,
    this.onRenameContent,
    this.onRenameCategory,
    this.showContextMenu = true,
    this.onHideCategory,
    this.playlistId,
    this.currentPrograms,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  /// Sort content items with favorites at the beginning
  List<ContentItem> _sortFavoritesFirst(List<ContentItem> items) {
    if (widget.favoriteStreamIds == null || widget.favoriteStreamIds!.isEmpty) {
      return items;
    }

    final sorted = List<ContentItem>.from(items);
    sorted.sort((a, b) {
      final aIsFavorite = widget.favoriteStreamIds!.contains(a.id);
      final bIsFavorite = widget.favoriteStreamIds!.contains(b.id);
      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;
      return 0; // Keep original order for items with same favorite status
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.category.category.categoryName.applyRenamingRules(
      isCategory: true,
      itemId: widget.category.category.categoryId,
      playlistId: widget.playlistId,
    );

    // Capture navigator from outer context before popup menu
    final navigator = Navigator.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: SelectableText(
                          displayName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.showContextMenu)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          padding: EdgeInsets.zero,
                          position: PopupMenuPosition.under,
                          itemBuilder: (popupContext) => [
                            PopupMenuItem<String>(
                              value: 'rename',
                              onTap: () {
                                Future.delayed(Duration.zero, () async {
                                  final result = await showDialog<String>(
                                    context: navigator.context,
                                    builder: (dialogContext) => RenameDialog(
                                      currentName: displayName,
                                      itemId: widget.category.category.categoryId,
                                      playlistId: widget.playlistId,
                                      type: CustomRenameType.category,
                                    ),
                                  );
                                  if (result != null && mounted) {
                                    widget.onRenameCategory?.call();
                                    setState(() {}); // Trigger rebuild to show new name
                                  }
                                });
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Rename'),
                                ],
                              ),
                            ),
                            if (widget.onHideCategory != null)
                              PopupMenuItem<String>(
                                value: 'hide',
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    widget.onHideCategory?.call(
                                      widget.category.category.categoryId,
                                      widget.category.category.categoryName,
                                    );
                                  });
                                },
                                child: const Row(
                                  children: [
                                    Icon(Icons.visibility_off, size: 20),
                                    SizedBox(width: 8),
                                    Text('Hide Category'),
                                  ],
                                ),
                              ),
                            // Parental lock option for categories (only visible in parent mode)
                            if (ParentalControlService().parentModeActive)
                              PopupMenuItem<String>(
                                value: 'parental_lock_category',
                                onTap: () {
                                  Future.delayed(Duration.zero, () async {
                                    if (!mounted) return;
                                    final service = ParentalControlService();
                                    final categoryId = widget.category.category.categoryId;
                                    final isLocked = service.isCategoryLocked(categoryId);
                                    if (isLocked) {
                                      await service.unlockCategory(categoryId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Category unlocked for kids')),
                                        );
                                      }
                                    } else {
                                      await service.lockCategory(categoryId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Category locked for kids')),
                                        );
                                      }
                                    }
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      ParentalControlService().isCategoryLocked(widget.category.category.categoryId)
                                          ? Icons.lock_open
                                          : Icons.lock,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ParentalControlService().isCategoryLocked(widget.category.category.categoryId)
                                          ? 'Unlock for Kids'
                                          : 'Lock for Kids',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onSeeAllTap,
                  child: Text(
                    context.loc.see_all,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          ContentItemCardWidget(
            cardHeight: widget.cardHeight,
            cardWidth: widget.cardWidth,
            onContentTap: widget.onContentTap,
            contentItems: _sortFavoritesFirst(widget.category.contentItems),
            isSelectionModeEnabled: false,
            favoriteStreamIds: widget.favoriteStreamIds,
            hiddenStreamIds: widget.hiddenStreamIds,
            onToggleFavorite: widget.onToggleFavorite,
            onToggleHidden: widget.onToggleHidden,
            onRename: widget.onRenameContent,
            showContextMenu: widget.showContextMenu,
            categoryId: widget.category.category.categoryId,
            categoryName: widget.category.category.categoryName,
            onHideCategory: widget.onHideCategory,
            playlistId: widget.playlistId,
            currentPrograms: widget.currentPrograms,
            key: widget.key,
          ),
        ],
      ),
    );
  }
}
