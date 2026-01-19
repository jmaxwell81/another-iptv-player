import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/services/source_health_service.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';
import 'package:another_iptv_player/widgets/rename_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/content_type.dart';

class ContentCard extends StatefulWidget {
  final ContentItem content;
  final double width;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isFavorite;
  final bool showContextMenu;
  final Function(ContentItem)? onToggleFavorite;
  final Function(ContentItem)? onToggleHidden;
  final Function(ContentItem)? onRename;
  final bool isHidden;
  final String? categoryId;
  final String? categoryName;
  final String? playlistId;
  final String? sourceId;
  final Function(String categoryId, String categoryName)? onHideCategory;
  final EpgProgram? currentProgram;

  const ContentCard({
    super.key,
    required this.content,
    required this.width,
    this.onTap,
    this.isSelected = false,
    this.isFavorite = false,
    this.showContextMenu = false,
    this.onToggleFavorite,
    this.onToggleHidden,
    this.onRename,
    this.isHidden = false,
    this.categoryId,
    this.categoryName,
    this.playlistId,
    this.sourceId,
    this.onHideCategory,
    this.currentProgram,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    bool isRecent = false;
    String? releaseDateStr;
    DateTime? releaseDate;

    if (widget.content.contentType == ContentType.series) {
      releaseDateStr = widget.content.seriesStream?.releaseDate;
    }

    if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
      try {
        releaseDate = DateTime.parse(releaseDateStr);
      } catch (e) {
        releaseDate = null;
      }
    }

    if (releaseDate != null) {
      final diff = DateTime.now().difference(releaseDate).inDays;
      isRecent = diff <= 15;
    }

    final bool isLiveStream = widget.content.contentType == ContentType.liveStream;
    final Widget? ratingBadge =
    isLiveStream ? null : _buildRatingBadge(context);

    // Show context menu only when hovered or selected
    final bool shouldShowContextMenu = widget.showContextMenu && (_isHovered || widget.isSelected);

    // Check if source is available
    final sourceId = widget.sourceId ?? widget.content.sourcePlaylistId;
    final bool isSourceDown = sourceId != null &&
        !SourceHealthService().isSourceAvailable(sourceId);

    // Combined opacity for hidden items and source down state
    final double cardOpacity = widget.isHidden ? 0.4 : (isSourceDown ? 0.5 : 1.0);

    Widget cardWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
        color: widget.isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: ColorFiltered(
          colorFilter: isSourceDown
              ? const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
          child: Opacity(
            opacity: cardOpacity,
            child: InkWell(
              onTap: widget.onTap,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: widget.content.imagePath.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: widget.content.imagePath,
                      fit: _getFitForContentType(),
                      placeholder: (context, url) => Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildTitleCard(context),
                    )
                        : _buildTitleCard(context),
                  ),
                  if (ratingBadge != null) ratingBadge,
                  if (isRecent)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.loc.new_ep,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (widget.isFavorite)
                    Positioned(
                      top: 4,
                      left: isRecent ? null : 4,
                      right: isRecent ? 4 : null,
                      child: Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                      ),
                    ),
                  // EPG overlay for live streams
                  if (isLiveStream && widget.currentProgram != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32, // Position above the name overlay
                      child: _buildEpgOverlay(context),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      color: Colors.black.withOpacity(0.7),
                      child: Text(
                        widget.content.name.applyRenamingRules(
                          contentType: widget.content.contentType,
                          itemId: widget.content.id,
                          playlistId: widget.playlistId,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (shouldShowContextMenu)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildContextMenu(context),
                    ),
                  // Source down indicator
                  if (isSourceDown)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Tooltip(
                        message: 'Source unavailable',
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.block,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
        ),
      ),
      ),
    );
    return cardWidget;
  }

  Widget _buildContextMenu(BuildContext outerContext) {
    // Capture navigator from outer context (the widget's context, not popup menu's)
    final navigator = Navigator.of(outerContext);

    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.more_vert,
          color: Colors.white,
          size: 18,
        ),
      ),
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        // onSelected is not called when onTap is used on PopupMenuItem
        // Keeping for fallback but actual logic is in onTap
        switch (value) {
          case 'favorite':
            widget.onToggleFavorite?.call(widget.content);
            break;
          case 'hidden':
            widget.onToggleHidden?.call(widget.content);
            break;
        }
      },
      itemBuilder: (popupContext) {
        return [
          PopupMenuItem<String>(
            value: 'favorite',
            onTap: () {
              Future.delayed(Duration.zero, () {
                widget.onToggleFavorite?.call(widget.content);
              });
            },
            child: Row(
              children: [
                Icon(
                  widget.isFavorite ? Icons.star : Icons.star_border,
                  color: widget.isFavorite ? Colors.amber : null,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isFavorite
                      ? popupContext.loc.remove_from_favorites
                      : popupContext.loc.add_to_favorites,
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'hidden',
            onTap: () {
              Future.delayed(Duration.zero, () {
                widget.onToggleHidden?.call(widget.content);
              });
            },
            child: Row(
              children: [
                Icon(
                  widget.isHidden ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isHidden
                      ? popupContext.loc.unhide_item
                      : popupContext.loc.hide_item,
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'rename',
            onTap: () {
              final customRenameType = _getCustomRenameType(widget.content.contentType);
              final currentDisplayName = widget.content.name.applyRenamingRules(
                contentType: widget.content.contentType,
                itemId: widget.content.id,
                playlistId: widget.playlistId,
              );
              Future.delayed(Duration.zero, () async {
                if (!mounted) return;
                final result = await showDialog<String>(
                  context: navigator.context,
                  builder: (dialogContext) => RenameDialog(
                    currentName: currentDisplayName,
                    itemId: widget.content.id,
                    playlistId: widget.playlistId,
                    type: customRenameType,
                  ),
                );
                if (result != null && mounted) {
                  widget.onRename?.call(widget.content);
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
          if (widget.categoryId != null && widget.categoryName != null && widget.onHideCategory != null)
            PopupMenuItem<String>(
              value: 'hide_category',
              onTap: () {
                Future.delayed(Duration.zero, () {
                  widget.onHideCategory?.call(widget.categoryId!, widget.categoryName!);
                });
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_off,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Hide "${widget.categoryName}"',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }

  BoxFit _getFitForContentType() {
    if (widget.content.contentType == ContentType.liveStream) {
      return BoxFit.contain;
    }
    return BoxFit.cover;
  }

  Widget _buildTitleCard(BuildContext context) {
    return Container(
      color: widget.isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            widget.content.name.applyRenamingRules(
              contentType: widget.content.contentType,
              itemId: widget.content.id,
              playlistId: widget.playlistId,
            ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  CustomRenameType _getCustomRenameType(ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return CustomRenameType.liveStream;
      case ContentType.vod:
        return CustomRenameType.vod;
      case ContentType.series:
        return CustomRenameType.series;
    }
  }

  Widget? _buildRatingBadge(BuildContext context) {
    final dynamic rawRating = widget.content.contentType == ContentType.series
        ? widget.content.seriesStream?.rating
        : widget.content.vodStream?.rating;

    final double? rating = _parseRating(rawRating);
    if (rating == null || rating <= 0) {
      return null;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final formattedRating = rating % 1 == 0
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);

    return Positioned(
      top: 6,
      right: 6,
      child: Semantics(
        label: 'Rating $formattedRating',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.secondaryContainer.withOpacity(0.93),
                colorScheme.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.onSecondaryContainer.withOpacity(0.16),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.22),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 14,
                color: colorScheme.onSecondaryContainer.withOpacity(0.9),
              ),
              const SizedBox(width: 3),
              Text(
                formattedRating,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: colorScheme.onSecondaryContainer,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _parseRating(dynamic rating) {
    if (rating == null) return null;
    if (rating is num) return rating.toDouble();
    if (rating is String && rating.isNotEmpty) {
      final normalized = rating.replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  Widget _buildEpgOverlay(BuildContext context) {
    final program = widget.currentProgram!;
    final progress = program.progress;
    final remainingMinutes = program.remainingTime.inMinutes;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Program title
          Text(
            program.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Progress bar with remaining time
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                remainingMinutes > 0 ? '${remainingMinutes}m' : '<1m',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}