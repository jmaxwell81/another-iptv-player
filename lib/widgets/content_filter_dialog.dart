import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/content_filter.dart';

/// Dialog for filtering movies and series content
class ContentFilterDialog extends StatefulWidget {
  final ContentFilter initialFilter;
  final Set<String> availableGenres;
  final bool showBoxOffice; // Only show for movies

  const ContentFilterDialog({
    super.key,
    required this.initialFilter,
    required this.availableGenres,
    this.showBoxOffice = true,
  });

  static Future<ContentFilter?> show(
    BuildContext context, {
    required ContentFilter initialFilter,
    required Set<String> availableGenres,
    bool showBoxOffice = true,
  }) {
    return showModalBottomSheet<ContentFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ContentFilterDialog(
        initialFilter: initialFilter,
        availableGenres: availableGenres,
        showBoxOffice: showBoxOffice,
      ),
    );
  }

  @override
  State<ContentFilterDialog> createState() => _ContentFilterDialogState();
}

class _ContentFilterDialogState extends State<ContentFilterDialog> {
  late ContentFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 50),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter & Sort',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_filter.hasActiveFilters || _filter.hasCustomSort)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filter = _filter.reset();
                      });
                    },
                    child: const Text('Reset'),
                  ),
              ],
            ),
          ),

          const Divider(),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort Section
                  _buildSectionTitle('Sort By'),
                  _buildSortOptions(),
                  const SizedBox(height: 20),

                  // Rating Section
                  _buildSectionTitle('Rating'),
                  _buildRatingFilter(),
                  const SizedBox(height: 20),

                  // Year Section
                  _buildSectionTitle('Year'),
                  _buildYearFilter(),
                  const SizedBox(height: 20),

                  // Genre Section
                  if (widget.availableGenres.isNotEmpty) ...[
                    _buildSectionTitle('Genres'),
                    _buildGenreFilter(),
                    const SizedBox(height: 20),
                  ],

                  // Box Office Section (movies only)
                  if (widget.showBoxOffice) ...[
                    _buildSectionTitle('Box Office'),
                    _buildBoxOfficeFilter(),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // Apply button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_filter),
                      child: Text(
                        _filter.hasActiveFilters
                            ? 'Apply (${_filter.activeFilterCount})'
                            : 'Apply',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildSortOptions() {
    return Column(
      children: [
        // Sort by dropdown
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ContentSortOption.values.map((option) {
            // Hide box office sort if not showing box office filter
            if (option == ContentSortOption.revenue && !widget.showBoxOffice) {
              return const SizedBox.shrink();
            }

            final isSelected = _filter.sortBy == option;
            return ChoiceChip(
              label: Text(option.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = _filter.copyWith(sortBy: option);
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Sort direction
        Row(
          children: [
            const Text('Order: '),
            ChoiceChip(
              label: Text(_getSortDirectionLabel(false)),
              selected: !_filter.sortDescending,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = _filter.copyWith(sortDescending: false);
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(_getSortDirectionLabel(true)),
              selected: _filter.sortDescending,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = _filter.copyWith(sortDescending: true);
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  String _getSortDirectionLabel(bool descending) {
    switch (_filter.sortBy) {
      case ContentSortOption.name:
        return descending ? 'Z to A' : 'A to Z';
      case ContentSortOption.rating:
        return descending ? 'Highest first' : 'Lowest first';
      case ContentSortOption.year:
        return descending ? 'Newest first' : 'Oldest first';
      case ContentSortOption.revenue:
        return descending ? 'Highest first' : 'Lowest first';
      case ContentSortOption.dateAdded:
        return descending ? 'Newest first' : 'Oldest first';
    }
  }

  Widget _buildRatingFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RatingPresets.presets.map((preset) {
        final isSelected = _filter.minRating == preset.min &&
            _filter.maxRating == preset.max;
        return ChoiceChip(
          label: Text(preset.label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _filter = _filter.copyWith(
                  minRating: preset.min,
                  maxRating: preset.max,
                  clearMinRating: preset.min == null,
                  clearMaxRating: preset.max == null,
                );
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildYearFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: YearPresets.presets.map((preset) {
        final isSelected =
            _filter.minYear == preset.min && _filter.maxYear == preset.max;
        return ChoiceChip(
          label: Text(preset.label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _filter = _filter.copyWith(
                  minYear: preset.min,
                  maxYear: preset.max,
                  clearMinYear: preset.min == null,
                  clearMaxYear: preset.max == null,
                );
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildGenreFilter() {
    final sortedGenres = widget.availableGenres.toList()..sort();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedGenres.map((genre) {
        final isSelected = _filter.genres.contains(genre);
        return FilterChip(
          label: Text(genre),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              final newGenres = Set<String>.from(_filter.genres);
              if (selected) {
                newGenres.add(genre);
              } else {
                newGenres.remove(genre);
              }
              _filter = _filter.copyWith(genres: newGenres);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildBoxOfficeFilter() {
    final presets = [
      ('Any', null),
      ('\$100M+', 100000000),
      ('\$500M+', 500000000),
      ('\$1B+', 1000000000),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((preset) {
        final isSelected = _filter.minRevenue == preset.$2;
        return ChoiceChip(
          label: Text(preset.$1),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _filter = _filter.copyWith(
                  minRevenue: preset.$2,
                  clearMinRevenue: preset.$2 == null,
                );
              }
            });
          },
        );
      }).toList(),
    );
  }
}
