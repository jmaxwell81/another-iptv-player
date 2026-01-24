/// Represents the state of an EPG fetch operation
enum EpgFetchState {
  idle,
  checking,
  downloading,
  parsing,
  storing,
  completed,
  failed,
  skipped,
  cancelled,
}

/// Status of a single EPG source being fetched
class EpgSourceStatus {
  final String playlistId;
  final String playlistName;
  final EpgFetchState state;
  final double progress; // 0.0 - 1.0
  final int bytesDownloaded;
  final int? totalBytes; // null if unknown
  final DateTime? startTime;
  final String? errorMessage;
  final bool wasOffline;

  const EpgSourceStatus({
    required this.playlistId,
    required this.playlistName,
    this.state = EpgFetchState.idle,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes,
    this.startTime,
    this.errorMessage,
    this.wasOffline = false,
  });

  /// Time elapsed since fetch started
  Duration? get elapsed =>
      startTime != null ? DateTime.now().difference(startTime!) : null;

  /// Estimated time remaining based on current progress
  Duration? get estimatedRemaining {
    if (progress <= 0 || elapsed == null) return null;
    final totalEstimate = elapsed!.inMilliseconds / progress;
    return Duration(
        milliseconds: (totalEstimate - elapsed!.inMilliseconds).round());
  }

  /// Progress percentage as string (e.g., "75%")
  String get progressPercentage => '${(progress * 100).toStringAsFixed(0)}%';

  /// Human-readable state description
  String get stateDescription {
    switch (state) {
      case EpgFetchState.idle:
        return 'Waiting';
      case EpgFetchState.checking:
        return 'Checking';
      case EpgFetchState.downloading:
        return 'Downloading';
      case EpgFetchState.parsing:
        return 'Parsing';
      case EpgFetchState.storing:
        return 'Storing';
      case EpgFetchState.completed:
        return 'Completed';
      case EpgFetchState.failed:
        return 'Failed';
      case EpgFetchState.skipped:
        return 'Skipped';
      case EpgFetchState.cancelled:
        return 'Cancelled';
    }
  }

  EpgSourceStatus copyWith({
    String? playlistId,
    String? playlistName,
    EpgFetchState? state,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    DateTime? startTime,
    String? errorMessage,
    bool? wasOffline,
  }) {
    return EpgSourceStatus(
      playlistId: playlistId ?? this.playlistId,
      playlistName: playlistName ?? this.playlistName,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      startTime: startTime ?? this.startTime,
      errorMessage: errorMessage ?? this.errorMessage,
      wasOffline: wasOffline ?? this.wasOffline,
    );
  }

  @override
  String toString() {
    return 'EpgSourceStatus(playlist: $playlistName, state: $state, progress: $progressPercentage)';
  }
}

/// Overall progress of fetching EPG data from multiple sources
class EpgFetchProgress {
  final int currentSourceIndex; // 0-based
  final int totalSources;
  final EpgSourceStatus? currentSource;
  final List<EpgSourceStatus> completedSources;
  final bool isCancelled;

  const EpgFetchProgress({
    required this.currentSourceIndex,
    required this.totalSources,
    this.currentSource,
    this.completedSources = const [],
    this.isCancelled = false,
  });

  /// Human-readable status text (e.g., "Source 1 of 3")
  String get statusText => 'Source ${currentSourceIndex + 1} of $totalSources';

  /// Overall progress across all sources (0.0 - 1.0)
  double get overallProgress {
    if (totalSources == 0) return 0.0;

    // Completed sources count as 1.0 each
    final completedProgress = completedSources.length.toDouble();

    // Current source contributes its fractional progress
    final currentProgress = currentSource?.progress ?? 0.0;

    return (completedProgress + currentProgress) / totalSources;
  }

  /// Count of sources that completed successfully
  int get successCount =>
      completedSources.where((s) => s.state == EpgFetchState.completed).length;

  /// Count of sources that failed
  int get failedCount =>
      completedSources.where((s) => s.state == EpgFetchState.failed).length;

  /// Count of sources that were skipped (fresh data exists)
  int get skippedCount =>
      completedSources.where((s) => s.state == EpgFetchState.skipped).length;

  /// Whether all sources have been processed
  bool get isComplete =>
      completedSources.length == totalSources || isCancelled;

  EpgFetchProgress copyWith({
    int? currentSourceIndex,
    int? totalSources,
    EpgSourceStatus? currentSource,
    List<EpgSourceStatus>? completedSources,
    bool? isCancelled,
  }) {
    return EpgFetchProgress(
      currentSourceIndex: currentSourceIndex ?? this.currentSourceIndex,
      totalSources: totalSources ?? this.totalSources,
      currentSource: currentSource ?? this.currentSource,
      completedSources: completedSources ?? this.completedSources,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  @override
  String toString() {
    return 'EpgFetchProgress($statusText, overall: ${(overallProgress * 100).toStringAsFixed(0)}%)';
  }
}
