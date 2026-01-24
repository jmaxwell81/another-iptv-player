import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
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
  final bool isFavoritesOnly;
  final Function(String categoryId)? onToggleFavoritesOnly;
  final bool isPinned;
  final int? pinnedIndex; // null if not pinned, 0 = at top, >0 = not at top
  final Function(String categoryId, String categoryName)? onTogglePinned;
  final VoidCallback? onMoveToTop; // explicit move-to-top action
  final bool isDemoted;
  final Function(String categoryId, String categoryName)? onToggleDemoted;

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
    this.isFavoritesOnly = false,
    this.onToggleFavoritesOnly,
    this.isPinned = false,
    this.pinnedIndex,
    this.onTogglePinned,
    this.onMoveToTop,
    this.isDemoted = false,
    this.onToggleDemoted,
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

  /// Get filtered content items based on favorites-only mode
  List<ContentItem> _getDisplayItems() {
    // Use displayItems which returns consolidated items when available
    var items = widget.category.displayItems;

    // If favorites-only mode is enabled, filter to only favorites
    if (widget.isFavoritesOnly && widget.favoriteStreamIds != null) {
      items = items.where((item) => widget.favoriteStreamIds!.contains(item.id)).toList();
    }

    return _sortFavoritesFirst(items);
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
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: AppThemes.categoryGrey,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (widget.isPinned) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.push_pin,
                                size: 14,
                                color: AppThemes.accentRed,
                              ),
                            ],
                            if (widget.isFavoritesOnly) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                            ],
                            if (widget.isDemoted) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_downward,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.showContextMenu)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppThemes.iconGrey),
                          padding: EdgeInsets.zero,
                          position: PopupMenuPosition.under,
                          itemBuilder: (popupContext) => [
                            // Move to Top option - shown if NOT pinned OR pinned but not at index 0
                            if ((widget.onMoveToTop != null || widget.onTogglePinned != null) &&
                                !widget.isDemoted &&
                                (!widget.isPinned || (widget.pinnedIndex != null && widget.pinnedIndex! > 0)))
                              PopupMenuItem<String>(
                                value: 'move_to_top',
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    // Use dedicated move-to-top callback if available, otherwise toggle pin
                                    if (widget.onMoveToTop != null) {
                                      widget.onMoveToTop?.call();
                                    } else {
                                      widget.onTogglePinned?.call(
                                        widget.category.category.categoryId,
                                        widget.category.category.categoryName,
                                      );
                                    }
                                  });
                                },
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.push_pin_outlined,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Move to Top'),
                                  ],
                                ),
                              ),
                            // Unpin option - shown only when pinned
                            if (widget.onTogglePinned != null && !widget.isDemoted && widget.isPinned)
                              PopupMenuItem<String>(
                                value: 'unpin',
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    widget.onTogglePinned?.call(
                                      widget.category.category.categoryId,
                                      widget.category.category.categoryName,
                                    );
                                  });
                                },
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.push_pin,
                                      size: 20,
                                      color: AppThemes.accentRed,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Unpin'),
                                  ],
                                ),
                              ),
                            // Move to Bottom / Undemote option
                            if (widget.onToggleDemoted != null && !widget.isPinned)
                              PopupMenuItem<String>(
                                value: 'demote',
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    widget.onToggleDemoted?.call(
                                      widget.category.category.categoryId,
                                      widget.category.category.categoryName,
                                    );
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.isDemoted ? Icons.arrow_upward : Icons.arrow_downward,
                                      size: 20,
                                      color: widget.isDemoted ? Colors.grey : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(widget.isDemoted ? 'Restore Position' : 'Move to Bottom'),
                                  ],
                                ),
                              ),
                            // Only Favorites toggle
                            if (widget.onToggleFavoritesOnly != null)
                              PopupMenuItem<String>(
                                value: 'favorites_only',
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    widget.onToggleFavoritesOnly?.call(
                                      widget.category.category.categoryId,
                                    );
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.isFavoritesOnly ? Icons.star : Icons.star_border,
                                      size: 20,
                                      color: widget.isFavoritesOnly ? Colors.amber : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(widget.isFavoritesOnly ? 'Show All Items' : 'Only Favorites'),
                                  ],
                                ),
                              ),
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
                            // Parental block option for categories (only visible when parental controls are enabled and unlocked)
                            if (ParentalControlService().isEnabled && ParentalControlService().isUnlocked)
                              PopupMenuItem<String>(
                                value: 'parental_block_category',
                                onTap: () {
                                  Future.delayed(Duration.zero, () async {
                                    if (!mounted) return;
                                    final service = ParentalControlService();
                                    final categoryId = widget.category.category.categoryId;
                                    final categoryName = widget.category.category.categoryName;
                                    final isBlocked = service.isCategoryBlocked(categoryId, categoryName);
                                    if (isBlocked) {
                                      await service.removeBlockedCategory(categoryId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Category removed from parental controls')),
                                        );
                                      }
                                    } else {
                                      await service.addBlockedCategory(
                                        categoryId,
                                        categoryName,
                                        ContentType.fromCategoryType(widget.category.category.type),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Category added to parental controls')),
                                        );
                                      }
                                    }
                                  });
                                },
                                child: Builder(
                                  builder: (context) {
                                    final isBlocked = ParentalControlService().isCategoryBlocked(
                                      widget.category.category.categoryId,
                                      widget.category.category.categoryName,
                                    );
                                    return Row(
                                      children: [
                                        Icon(
                                          isBlocked ? Icons.lock_open : Icons.lock,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isBlocked
                                              ? 'Remove from Parental Controls'
                                              : 'Add to Parental Controls',
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onSeeAllTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.loc.see_all,
                        style: const TextStyle(
                          color: AppThemes.categoryGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppThemes.categoryGrey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ContentItemCardWidget(
            cardHeight: widget.cardHeight,
            cardWidth: widget.cardWidth,
            onContentTap: widget.onContentTap,
            contentItems: _getDisplayItems(),
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
