import 'dart:async';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import '../../models/playlist_content_model.dart';
import '../../services/event_bus.dart';
import '../../utils/helpers.dart';
import 'content_card.dart';

class ContentItemCardWidget extends StatefulWidget {
  final double cardWidth;
  final double cardHeight;
  final Function(ContentItem)? onContentTap;
  final List<ContentItem> contentItems;
  int initialSelectedIndex;
  final bool isSelectionModeEnabled;
  final Set<String>? favoriteStreamIds;
  final Set<String>? hiddenStreamIds;
  final Function(ContentItem)? onToggleFavorite;
  final Function(ContentItem)? onToggleHidden;
  final Function(ContentItem)? onRename;
  final bool showContextMenu;
  final String? categoryId;
  final String? categoryName;
  final String? playlistId;
  final Function(String categoryId, String categoryName)? onHideCategory;
  final Map<String, EpgProgram>? currentPrograms;

  ContentItemCardWidget({
    super.key,
    required this.cardHeight,
    required this.cardWidth,
    required this.contentItems,
    this.onContentTap,
    this.initialSelectedIndex = -1,
    this.isSelectionModeEnabled = false,
    this.favoriteStreamIds,
    this.hiddenStreamIds,
    this.onToggleFavorite,
    this.onToggleHidden,
    this.onRename,
    this.showContextMenu = true,
    this.categoryId,
    this.categoryName,
    this.playlistId,
    this.onHideCategory,
    this.currentPrograms,
  });

  @override
  State<ContentItemCardWidget> createState() => _ContentItemCardWidgetState();
}

class _ContentItemCardWidgetState extends State<ContentItemCardWidget> {
  late StreamSubscription contentItemIndexChangedSubscription;
  late StreamSubscription contentItemIndexSubscription;
  int selectedIndex = -1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    selectedIndex = widget.initialSelectedIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSelectedIndex >= 0) {
        _scrollToIndex(widget.initialSelectedIndex);
      }
    });

    contentItemIndexSubscription = EventBus()
        .on<int>('player_content_item_index')
        .listen((int index) {
          if (!mounted) return;
          selectAndScrollToIndex(index);
        });

    contentItemIndexChangedSubscription = EventBus()
        .on<int>('player_content_item_index_changed')
        .listen((int index) {
          if (!mounted) return;
          selectAndScrollToIndex(index);
        });
  }

  @override
  void dispose() {
    contentItemIndexSubscription.cancel();
    contentItemIndexChangedSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (index < 0 || index >= widget.contentItems.length) return;

    if (!_scrollController.hasClients) return;

    double screenWidth = MediaQuery.of(context).size.width;

    double cardTotalWidth = widget.cardWidth + 8;
    double targetPosition = (cardTotalWidth * index) + (widget.cardWidth / 2) - (screenWidth / 2);

    double maxScrollExtent = _scrollController.position.maxScrollExtent;
    double minScrollExtent = _scrollController.position.minScrollExtent;

    if (targetPosition < minScrollExtent) {
      targetPosition = minScrollExtent;
    } else if (targetPosition > maxScrollExtent) {
      targetPosition = maxScrollExtent;
    }

    _scrollController.animateTo(
      targetPosition,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void selectAndScrollToIndex(int index) {
    if (index < 0 || index >= widget.contentItems.length || !widget.isSelectionModeEnabled) return;

    setState(() {
      selectedIndex = index;
    });

    // _scrollToIndex(index);
  }

  bool _isFavorite(ContentItem item) {
    if (widget.favoriteStreamIds == null) return false;
    return widget.favoriteStreamIds!.contains(item.id);
  }

  bool _isHidden(ContentItem item) {
    if (widget.hiddenStreamIds == null) return false;
    return widget.hiddenStreamIds!.contains(item.id);
  }

  EpgProgram? _getCurrentProgram(ContentItem item) {
    if (widget.currentPrograms == null) return null;
    // Try item ID first, then epgChannelId from liveStream
    return widget.currentPrograms![item.id] ??
        (item.liveStream?.epgChannelId != null
            ? widget.currentPrograms![item.liveStream!.epgChannelId]
            : null);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.cardHeight,
      child: isDesktop
          ? Scrollbar(
              controller: _scrollController,
              thumbVisibility: false,
              trackVisibility: false,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.contentItems.length,
                itemBuilder: (context, index) {
                  final item = widget.contentItems[index];
                  return Container(
                    width: widget.cardWidth,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    child: ContentCard(
                      content: item,
                      width: widget.cardWidth,
                      onTap: () {
                        selectAndScrollToIndex(index);
                        widget.onContentTap?.call(item);
                      },
                      isSelected: selectedIndex == index,
                      isFavorite: _isFavorite(item),
                      isHidden: _isHidden(item),
                      showContextMenu: widget.showContextMenu,
                      onToggleFavorite: widget.onToggleFavorite,
                      onToggleHidden: widget.onToggleHidden,
                      onRename: widget.onRename,
                      categoryId: widget.categoryId,
                      categoryName: widget.categoryName,
                      playlistId: widget.playlistId,
                      onHideCategory: widget.onHideCategory,
                      currentProgram: _getCurrentProgram(item),
                      key: widget.key,
                    ),
                  );
                },
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.contentItems.length,
              itemBuilder: (context, index) {
                final item = widget.contentItems[index];
                return Container(
                  width: widget.cardWidth,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: ContentCard(
                    content: item,
                    width: widget.cardWidth,
                    onTap: () {
                      selectAndScrollToIndex(index);
                      widget.onContentTap?.call(item);
                    },
                    isSelected: selectedIndex == index,
                    isFavorite: _isFavorite(item),
                    isHidden: _isHidden(item),
                    showContextMenu: widget.showContextMenu,
                    onToggleFavorite: widget.onToggleFavorite,
                    onToggleHidden: widget.onToggleHidden,
                    onRename: widget.onRename,
                    categoryId: widget.categoryId,
                    categoryName: widget.categoryName,
                    playlistId: widget.playlistId,
                    onHideCategory: widget.onHideCategory,
                    currentProgram: _getCurrentProgram(item),
                    key: widget.key,
                  ),
                );
              },
            ),
    );
  }
}
