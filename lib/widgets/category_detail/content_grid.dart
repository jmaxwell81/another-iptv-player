import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/utils/responsive_helper.dart';
import 'package:another_iptv_player/widgets/tv/tv_focus_scope.dart';

import '../content_card.dart';

class ContentGrid extends StatelessWidget {
  final List<ContentItem> items;
  final Function(ContentItem) onItemTap;
  final Set<String>? favoriteStreamIds;
  final Set<String>? hiddenStreamIds;
  final Set<String>? offlineStreamIds;
  final Function(ContentItem)? onToggleFavorite;
  final Function(ContentItem)? onToggleHidden;
  final bool showContextMenu;
  final Map<String, EpgProgram>? currentPrograms;

  const ContentGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.favoriteStreamIds,
    this.hiddenStreamIds,
    this.offlineStreamIds,
    this.onToggleFavorite,
    this.onToggleHidden,
    this.showContextMenu = true,
    this.currentPrograms,
  });

  EpgProgram? _getCurrentProgram(ContentItem item) {
    if (currentPrograms == null) return null;
    return currentPrograms![item.id] ??
        (item.liveStream?.epgChannelId != null
            ? currentPrograms![item.liveStream!.epgChannelId]
            : null);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with TvFocusScope for TV D-pad grid navigation
    return TvFocusScope(
      horizontal: false, // Grid uses both horizontal and vertical, but vertical primary
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveHelper.getCrossAxisCount(context),
          childAspectRatio: 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ContentCard(
            content: item,
            width: 150,
            onTap: () => onItemTap(item),
            isFavorite: favoriteStreamIds?.contains(item.id) ?? false,
            isHidden: hiddenStreamIds?.contains(item.id) ?? false,
            isOffline: offlineStreamIds?.contains(item.id) ?? false,
            showContextMenu: showContextMenu,
            onToggleFavorite: onToggleFavorite,
            onToggleHidden: onToggleHidden,
            currentProgram: _getCurrentProgram(item),
          );
        },
      ),
    );
  }
}