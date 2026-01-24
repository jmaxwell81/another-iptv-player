import 'dart:ui' as ui;
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/content_source_link.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/screens/catch_up/catch_up_screen.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';
import 'package:another_iptv_player/services/source_health_service.dart';
import 'package:another_iptv_player/services/tv_detection_service.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
import 'package:another_iptv_player/utils/renaming_extension.dart';
import 'package:another_iptv_player/widgets/rename_dialog.dart';
import 'package:another_iptv_player/widgets/smart_cached_image.dart';
import 'package:another_iptv_player/widgets/source_selection_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isOffline;
  final String? categoryId;
  final String? categoryName;
  final String? playlistId;
  final String? sourceId;
  final Function(String categoryId, String categoryName)? onHideCategory;
  final EpgProgram? currentProgram;

  /// Quality indicator for consolidated content
  final ContentQuality? quality;

  /// Number of sources available (for multi-source badge)
  final int sourceCount;

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
    this.isOffline = false,
    this.categoryId,
    this.categoryName,
    this.playlistId,
    this.sourceId,
    this.onHideCategory,
    this.currentProgram,
    this.quality,
    this.sourceCount = 1,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _isHovered = false;
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      // When focused on TV, emit hover event for preview
      if (_isFocused && widget.content.contentType == ContentType.liveStream) {
        EventBus().emit('live_stream_hover', widget.content);
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Handle Enter/Select key to activate the card
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

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

    // Combined hover/focus state for TV and desktop
    final bool isHighlighted = _isHovered || _isFocused;

    // Show context menu only when hovered, focused, or selected
    final bool shouldShowContextMenu = widget.showContextMenu && (isHighlighted || widget.isSelected);

    // Check if source is available
    final sourceId = widget.sourceId ?? widget.content.sourcePlaylistId;
    final bool isSourceDown = sourceId != null &&
        !SourceHealthService().isSourceAvailable(sourceId);

    // Combined opacity for hidden items, offline items, and source down state
    final double cardOpacity = widget.isHidden ? 0.4 : (widget.isOffline ? 0.5 : (isSourceDown ? 0.5 : 1.0));

    // Determine if we're on Android TV for focus handling
    final isTV = TvDetectionService().isAndroidTV;

    // Focus border color for TV
    final theme = Theme.of(context);
    final focusBorderColor = _isFocused ? theme.colorScheme.primary : Colors.transparent;

    Widget cardWidget = MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        // Emit hover event for live stream preview
        if (widget.content.contentType == ContentType.liveStream) {
          EventBus().emit('live_stream_hover', widget.content);
        }
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(isHighlighted ? 1.05 : 1.0),
        transformAlignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              // Use accent color border when focused on TV, white border for hover/selected
              color: _isFocused
                  ? focusBorderColor
                  : (isHighlighted || widget.isSelected)
                      ? Colors.white.withOpacity(0.4)
                      : Colors.transparent,
              width: _isFocused ? 3.0 : 2,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: _isFocused
                          ? focusBorderColor.withOpacity(0.4)
                          : Colors.white.withOpacity(0.15),
                      blurRadius: _isFocused ? 12 : 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            color: widget.isSelected
                ? AppThemes.surfaceGreyLight
                : AppThemes.surfaceGrey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
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
                        ? SmartCachedImage(
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
                  // Quality badge for consolidated content (bottom-left, above name)
                  if (widget.quality != null &&
                      widget.quality != ContentQuality.unknown &&
                      !isLiveStream)
                    Positioned(
                      bottom: 40, // Above the name overlay
                      left: 4,
                      child: QualityBadgeSmall(quality: widget.quality!),
                    ),
                  // Multi-source indicator (bottom-right, above name)
                  if (widget.sourceCount > 1)
                    Positioned(
                      bottom: 40, // Above the name overlay
                      right: 4,
                      child: MultiSourceBadge(sourceCount: widget.sourceCount),
                    ),
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
                  // Offline badge for streams marked as offline
                  if (widget.isOffline)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.signal_wifi_off,
                              color: Colors.white,
                              size: 10,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'OFFLINE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Golden corner badge for favorites
                  if (widget.isFavorite)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: CustomPaint(
                        size: const Size(28, 28),
                        painter: _GoldenCornerBadgePainter(),
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
                      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0xCC000000),
                            Color(0xF0000000),
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: Text(
                        widget.content.name.applyRenamingRules(
                          contentType: widget.content.contentType,
                          itemId: widget.content.id,
                          playlistId: widget.playlistId,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.white,
                          letterSpacing: 0.2,
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
      ),
      ),
    );

    // Wrap with Focus widget for TV D-pad navigation
    if (isTV) {
      return Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: cardWidget,
      );
    }

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
          // Catch Up option for live streams
          if (widget.content.contentType == ContentType.liveStream && widget.playlistId != null)
            PopupMenuItem<String>(
              value: 'catch_up',
              onTap: () {
                Future.delayed(Duration.zero, () {
                  if (!mounted) return;
                  // Get channel ID from liveStream or m3uItem
                  final channelId = widget.content.liveStream?.epgChannelId ??
                      widget.content.liveStream?.streamId ??
                      widget.content.m3uItem?.tvgId ??
                      widget.content.id;
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => CatchUpScreen(
                        channelId: channelId,
                        channelName: widget.content.name,
                        playlistId: widget.playlistId!,
                        channelIcon: widget.content.imagePath,
                      ),
                    ),
                  );
                });
              },
              child: const Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text('Catch Up'),
                ],
              ),
            ),
          // Parental block/unblock option (only visible when parental controls are enabled and unlocked)
          if (ParentalControlService().isEnabled && ParentalControlService().isUnlocked)
            PopupMenuItem<String>(
              value: 'parental_block',
              onTap: () {
                Future.delayed(Duration.zero, () async {
                  if (!mounted) return;
                  final service = ParentalControlService();
                  final isBlocked = service.isContentBlocked(widget.content);
                  if (isBlocked) {
                    await service.removeBlockedItem(widget.content.id, widget.content.contentType);
                    if (outerContext.mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(content: Text('Removed from parental controls')),
                      );
                    }
                  } else {
                    await service.addBlockedItem(widget.content);
                    if (outerContext.mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(content: Text('Added to parental controls')),
                      );
                    }
                  }
                });
              },
              child: Builder(
                builder: (context) {
                  final isBlocked = ParentalControlService().isContentBlocked(widget.content);
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
      decoration: BoxDecoration(
        color: widget.isSelected
            ? AppThemes.surfaceGreyLight
            : AppThemes.surfaceGrey,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemes.surfaceGrey,
            AppThemes.surfaceGreyMedium,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            widget.content.name.applyRenamingRules(
              contentType: widget.content.contentType,
              itemId: widget.content.id,
              playlistId: widget.playlistId,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppThemes.textWhite,
              letterSpacing: 0.2,
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

    final formattedRating = rating % 1 == 0
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);

    return Positioned(
      top: 6,
      right: 6,
      child: Semantics(
        label: 'Rating $formattedRating',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xE0000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 12,
                color: AppThemes.accentRed,
              ),
              const SizedBox(width: 3),
              Text(
                formattedRating,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppThemes.textWhite,
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

/// Custom painter for the golden corner favorite badge
class _GoldenCornerBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Create a golden gradient for the corner triangle
    final gradient = ui.Gradient.linear(
      Offset(size.width, 0),
      Offset(size.width * 0.3, size.height * 0.7),
      [
        const Color(0xFFFFD700), // Gold
        const Color(0xFFFFA500), // Orange-gold
        const Color(0xFFFFD700), // Gold
      ],
      [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    // Draw the corner triangle
    final path = Path()
      ..moveTo(size.width * 0.3, 0) // Start from top, slightly left
      ..lineTo(size.width, 0) // Top right
      ..lineTo(size.width, size.height * 0.7) // Down the right side
      ..close();

    canvas.drawPath(path, paint);

    // Add a subtle shine/highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final highlightPath = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.5);

    canvas.drawPath(highlightPath, highlightPaint);

    // Add a subtle edge glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}