import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';
import 'package:another_iptv_player/widgets/rename_dialog.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';

import 'content_item_card_widget.dart';

class CategorySection extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final displayName = category.category.categoryName.applyRenamingRules(
      isCategory: true,
      itemId: category.category.categoryId,
      playlistId: playlistId,
    );

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
                      if (showContextMenu)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          padding: EdgeInsets.zero,
                          position: PopupMenuPosition.under,
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'rename',
                              onTap: () {
                                // Capture navigator before async gap to avoid context invalidation
                                final navigator = Navigator.of(context);
                                Future.delayed(Duration.zero, () async {
                                  final result = await showDialog<String>(
                                    context: navigator.context,
                                    builder: (dialogContext) => RenameDialog(
                                      currentName: displayName,
                                      itemId: category.category.categoryId,
                                      playlistId: playlistId,
                                      type: CustomRenameType.category,
                                    ),
                                  );
                                  if (result != null) {
                                    onRenameCategory?.call();
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
                            if (onHideCategory != null)
                              PopupMenuItem<String>(
                                value: 'hide',
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    onHideCategory?.call(
                                      category.category.categoryId,
                                      category.category.categoryName,
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
                          ],
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onSeeAllTap,
                  child: Text(
                    context.loc.see_all,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          ContentItemCardWidget(
            cardHeight: cardHeight,
            cardWidth: cardWidth,
            onContentTap: onContentTap,
            contentItems: category.contentItems,
            isSelectionModeEnabled: false,
            favoriteStreamIds: favoriteStreamIds,
            hiddenStreamIds: hiddenStreamIds,
            onToggleFavorite: onToggleFavorite,
            onToggleHidden: onToggleHidden,
            onRename: onRenameContent,
            showContextMenu: showContextMenu,
            categoryId: category.category.categoryId,
            categoryName: category.category.categoryName,
            onHideCategory: onHideCategory,
            playlistId: playlistId,
            key: key,
          ),
        ],
      ),
    );
  }
}
