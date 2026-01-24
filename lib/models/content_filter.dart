/// Filter options for movies and series content
class ContentFilter {
  /// Sort options
  final ContentSortOption sortBy;
  final bool sortDescending;

  /// Rating filter (0-10 scale)
  final double? minRating;
  final double? maxRating;

  /// Year filter
  final int? minYear;
  final int? maxYear;

  /// Genre filter (list of genre names to include)
  final Set<String> genres;

  /// Box office filter (revenue in USD)
  final int? minRevenue;
  final int? maxRevenue;

  const ContentFilter({
    this.sortBy = ContentSortOption.name,
    this.sortDescending = false,
    this.minRating,
    this.maxRating,
    this.minYear,
    this.maxYear,
    this.genres = const {},
    this.minRevenue,
    this.maxRevenue,
  });

  /// Check if any filter is active
  bool get hasActiveFilters =>
      minRating != null ||
      maxRating != null ||
      minYear != null ||
      maxYear != null ||
      genres.isNotEmpty ||
      minRevenue != null ||
      maxRevenue != null;

  /// Check if sorting is non-default
  bool get hasCustomSort => sortBy != ContentSortOption.name || sortDescending;

  /// Count of active filters
  int get activeFilterCount {
    int count = 0;
    if (minRating != null || maxRating != null) count++;
    if (minYear != null || maxYear != null) count++;
    if (genres.isNotEmpty) count++;
    if (minRevenue != null || maxRevenue != null) count++;
    return count;
  }

  ContentFilter copyWith({
    ContentSortOption? sortBy,
    bool? sortDescending,
    double? minRating,
    double? maxRating,
    int? minYear,
    int? maxYear,
    Set<String>? genres,
    int? minRevenue,
    int? maxRevenue,
    bool clearMinRating = false,
    bool clearMaxRating = false,
    bool clearMinYear = false,
    bool clearMaxYear = false,
    bool clearMinRevenue = false,
    bool clearMaxRevenue = false,
  }) {
    return ContentFilter(
      sortBy: sortBy ?? this.sortBy,
      sortDescending: sortDescending ?? this.sortDescending,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxRating: clearMaxRating ? null : (maxRating ?? this.maxRating),
      minYear: clearMinYear ? null : (minYear ?? this.minYear),
      maxYear: clearMaxYear ? null : (maxYear ?? this.maxYear),
      genres: genres ?? this.genres,
      minRevenue: clearMinRevenue ? null : (minRevenue ?? this.minRevenue),
      maxRevenue: clearMaxRevenue ? null : (maxRevenue ?? this.maxRevenue),
    );
  }

  /// Reset all filters to defaults
  ContentFilter reset() {
    return const ContentFilter();
  }

  @override
  String toString() {
    return 'ContentFilter(sortBy: $sortBy, sortDescending: $sortDescending, '
        'minRating: $minRating, maxRating: $maxRating, '
        'minYear: $minYear, maxYear: $maxYear, '
        'genres: $genres, minRevenue: $minRevenue, maxRevenue: $maxRevenue)';
  }
}

/// Sort options for content
enum ContentSortOption {
  name('Name'),
  rating('Rating'),
  year('Year'),
  revenue('Box Office'),
  dateAdded('Date Added');

  final String displayName;
  const ContentSortOption(this.displayName);
}

/// Preset rating filters
class RatingPresets {
  static const List<RatingPreset> presets = [
    RatingPreset('Any', null, null),
    RatingPreset('9+', 9.0, null),
    RatingPreset('8+', 8.0, null),
    RatingPreset('7+', 7.0, null),
    RatingPreset('6+', 6.0, null),
    RatingPreset('5+', 5.0, null),
  ];
}

class RatingPreset {
  final String label;
  final double? min;
  final double? max;

  const RatingPreset(this.label, this.min, this.max);
}

/// Preset year filters
class YearPresets {
  static List<YearPreset> get presets {
    final currentYear = DateTime.now().year;
    return [
      const YearPreset('Any', null, null),
      YearPreset('$currentYear', currentYear, currentYear),
      YearPreset('${currentYear - 1}', currentYear - 1, currentYear - 1),
      YearPreset('Last 5 years', currentYear - 4, currentYear),
      YearPreset('Last 10 years', currentYear - 9, currentYear),
      const YearPreset('2010s', 2010, 2019),
      const YearPreset('2000s', 2000, 2009),
      const YearPreset('1990s', 1990, 1999),
      const YearPreset('Classic (pre-1990)', null, 1989),
    ];
  }
}

class YearPreset {
  final String label;
  final int? min;
  final int? max;

  const YearPreset(this.label, this.min, this.max);
}
