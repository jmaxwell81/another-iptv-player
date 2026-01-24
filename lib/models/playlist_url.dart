/// Status of a playlist URL
enum UrlStatus {
  /// URL has not been checked yet
  unknown,

  /// URL is online and working
  online,

  /// URL is offline or unreachable
  offline,

  /// URL connection timed out
  timeout,

  /// URL returned an error (e.g., 401, 403, 500)
  error,
}

/// Represents a single URL for a playlist with health status
class PlaylistUrl {
  final String id;
  final String playlistId;
  final String url;
  final int priority; // Lower = higher priority (0 is primary)
  final UrlStatus status;
  final DateTime? lastChecked;
  final DateTime? lastSuccessful;
  final int failureCount;
  final String? lastError;
  final int responseTimeMs; // Average response time in milliseconds

  const PlaylistUrl({
    required this.id,
    required this.playlistId,
    required this.url,
    this.priority = 0,
    this.status = UrlStatus.unknown,
    this.lastChecked,
    this.lastSuccessful,
    this.failureCount = 0,
    this.lastError,
    this.responseTimeMs = 0,
  });

  /// Whether this URL is considered healthy (online or unknown)
  bool get isHealthy =>
      status == UrlStatus.online || status == UrlStatus.unknown;

  /// Whether this URL should be skipped during failover
  bool get shouldSkip {
    // Skip if offline and checked within the last 5 minutes
    if (status == UrlStatus.offline || status == UrlStatus.timeout) {
      if (lastChecked != null) {
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        if (lastChecked!.isAfter(fiveMinutesAgo)) {
          return true;
        }
      }
    }
    // Skip if too many consecutive failures
    if (failureCount >= 3 && lastSuccessful == null) {
      return true;
    }
    return false;
  }

  /// Human-readable status description
  String get statusDescription {
    switch (status) {
      case UrlStatus.unknown:
        return 'Not checked';
      case UrlStatus.online:
        return 'Online';
      case UrlStatus.offline:
        return 'Offline';
      case UrlStatus.timeout:
        return 'Timeout';
      case UrlStatus.error:
        return 'Error';
    }
  }

  PlaylistUrl copyWith({
    String? id,
    String? playlistId,
    String? url,
    int? priority,
    UrlStatus? status,
    DateTime? lastChecked,
    DateTime? lastSuccessful,
    int? failureCount,
    String? lastError,
    int? responseTimeMs,
  }) {
    return PlaylistUrl(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      url: url ?? this.url,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      lastChecked: lastChecked ?? this.lastChecked,
      lastSuccessful: lastSuccessful ?? this.lastSuccessful,
      failureCount: failureCount ?? this.failureCount,
      lastError: lastError ?? this.lastError,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playlistId': playlistId,
      'url': url,
      'priority': priority,
      'status': status.index,
      'lastChecked': lastChecked?.toIso8601String(),
      'lastSuccessful': lastSuccessful?.toIso8601String(),
      'failureCount': failureCount,
      'lastError': lastError,
      'responseTimeMs': responseTimeMs,
    };
  }

  factory PlaylistUrl.fromJson(Map<String, dynamic> json) {
    return PlaylistUrl(
      id: json['id'] as String,
      playlistId: json['playlistId'] as String,
      url: json['url'] as String,
      priority: json['priority'] as int? ?? 0,
      status: UrlStatus.values[json['status'] as int? ?? 0],
      lastChecked: json['lastChecked'] != null
          ? DateTime.tryParse(json['lastChecked'] as String)
          : null,
      lastSuccessful: json['lastSuccessful'] != null
          ? DateTime.tryParse(json['lastSuccessful'] as String)
          : null,
      failureCount: json['failureCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      responseTimeMs: json['responseTimeMs'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'PlaylistUrl(url: $url, priority: $priority, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaylistUrl && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Result of checking a URL's health
class UrlHealthCheckResult {
  final bool isHealthy;
  final UrlStatus status;
  final int responseTimeMs;
  final String? error;
  final int? httpStatusCode;

  const UrlHealthCheckResult({
    required this.isHealthy,
    required this.status,
    this.responseTimeMs = 0,
    this.error,
    this.httpStatusCode,
  });

  factory UrlHealthCheckResult.online(int responseTimeMs) {
    return UrlHealthCheckResult(
      isHealthy: true,
      status: UrlStatus.online,
      responseTimeMs: responseTimeMs,
    );
  }

  factory UrlHealthCheckResult.offline(String error) {
    return UrlHealthCheckResult(
      isHealthy: false,
      status: UrlStatus.offline,
      error: error,
    );
  }

  factory UrlHealthCheckResult.timeout() {
    return const UrlHealthCheckResult(
      isHealthy: false,
      status: UrlStatus.timeout,
      error: 'Connection timeout',
    );
  }

  factory UrlHealthCheckResult.error(int statusCode, String error) {
    return UrlHealthCheckResult(
      isHealthy: false,
      status: UrlStatus.error,
      httpStatusCode: statusCode,
      error: error,
    );
  }
}

/// Result of a URL failover attempt
class FailoverResult {
  final bool success;
  final PlaylistUrl? workingUrl;
  final List<PlaylistUrl> triedUrls;
  final String? error;

  const FailoverResult({
    required this.success,
    this.workingUrl,
    this.triedUrls = const [],
    this.error,
  });

  factory FailoverResult.foundWorking(
      PlaylistUrl url, List<PlaylistUrl> tried) {
    return FailoverResult(
      success: true,
      workingUrl: url,
      triedUrls: tried,
    );
  }

  factory FailoverResult.allFailed(List<PlaylistUrl> tried) {
    return FailoverResult(
      success: false,
      triedUrls: tried,
      error: 'All URLs failed',
    );
  }

  factory FailoverResult.noUrls() {
    return const FailoverResult(
      success: false,
      error: 'No URLs configured',
    );
  }
}
