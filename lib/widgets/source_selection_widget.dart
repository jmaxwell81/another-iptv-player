import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/content_source_link.dart';
import 'package:another_iptv_player/services/content_preference_service.dart';

/// Widget for displaying and selecting from multiple content sources.
/// Shows quality badges, source names, and language indicators.
class SourceSelectionWidget extends StatelessWidget {
  final List<ContentSourceLink> sources;
  final ContentSourceLink? selectedSource;
  final ValueChanged<ContentSourceLink> onSourceSelected;
  final bool showHeader;
  final bool compact;

  const SourceSelectionWidget({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.onSourceSelected,
    this.showHeader = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    if (sources.length == 1) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Icon(
                Icons.source,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.loc.available_sources,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${sources.length}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (compact)
          _buildCompactList(context)
        else
          _buildExpandedList(context),
      ],
    );
  }

  Widget _buildCompactList(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sources.map((source) {
        final isSelected = source == selectedSource;
        return _SourceChip(
          source: source,
          isSelected: isSelected,
          onTap: () => onSourceSelected(source),
        );
      }).toList(),
    );
  }

  Widget _buildExpandedList(BuildContext context) {
    // Rank sources by preference score
    final rankedSources = ContentPreferenceService().getRankedSources(sources);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rankedSources.asMap().entries.map((entry) {
        final index = entry.key;
        final source = entry.value;
        final isSelected = source == selectedSource;
        final isRecommended = index == 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SourceCard(
            source: source,
            isSelected: isSelected,
            isRecommended: isRecommended,
            onTap: () => onSourceSelected(source),
          ),
        );
      }).toList(),
    );
  }
}

/// Compact chip for source selection
class _SourceChip extends StatelessWidget {
  final ContentSourceLink source;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceChip({
    required this.source,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (source.quality != ContentQuality.unknown) ...[
                _QualityBadge(quality: source.quality, small: true),
                const SizedBox(width: 6),
              ],
              Text(
                source.sourceName,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (source.language != null) ...[
                const SizedBox(width: 6),
                Text(
                  source.language!.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Expanded card for source selection with full details
class _SourceCard extends StatelessWidget {
  final ContentSourceLink source;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  const _SourceCard({
    required this.source,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.grey.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Quality badge
              _QualityBadge(quality: source.quality),
              const SizedBox(width: 12),

              // Source info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            source.sourceName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.thumb_up,
                                  size: 12,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  context.loc.recommended,
                                  style: TextStyle(
                                    color: theme.colorScheme.onTertiaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (source.language != null) ...[
                          Icon(
                            Icons.language,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            source.language!.toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (source.containerExtension != null) ...[
                          Icon(
                            Icons.video_file,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            source.containerExtension!.toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Selection indicator
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quality badge widget with color coding
class _QualityBadge extends StatelessWidget {
  final ContentQuality quality;
  final bool small;

  const _QualityBadge({
    required this.quality,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    if (quality == ContentQuality.unknown) {
      return const SizedBox.shrink();
    }

    final color = _getQualityColor();
    final label = quality.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(small ? 6 : 8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getQualityColor() {
    switch (quality) {
      case ContentQuality.uhd4k:
        return Colors.purple;
      case ContentQuality.hd1080p:
        return Colors.blue;
      case ContentQuality.hd720p:
        return Colors.green;
      case ContentQuality.sd:
        return Colors.orange;
      case ContentQuality.unknown:
        return Colors.grey;
    }
  }
}

/// Static quality badge for use in content cards
class QualityBadgeSmall extends StatelessWidget {
  final ContentQuality quality;

  const QualityBadgeSmall({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    if (quality == ContentQuality.unknown) {
      return const SizedBox.shrink();
    }

    return _QualityBadge(quality: quality, small: true);
  }
}

/// Badge showing number of available sources
class MultiSourceBadge extends StatelessWidget {
  final int sourceCount;

  const MultiSourceBadge({super.key, required this.sourceCount});

  @override
  Widget build(BuildContext context) {
    if (sourceCount <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers,
            size: 12,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            '$sourceCount',
            style: TextStyle(
              color: theme.colorScheme.onSecondaryContainer,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
