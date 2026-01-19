import 'package:another_iptv_player/models/content_type.dart';

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

enum DownloadType {
  vod,        // Single VOD movie
  episode,    // Single series episode
  series,     // Entire series (multiple episodes)
  season,     // Single season
}

class Download {
  final String id;
  final String playlistId;
  final String contentId;      // vodId, episodeId, or seriesId
  final String name;
  final String? description;
  final String sourceUrl;
  final String? thumbnailUrl;
  final ContentType contentType;
  final DownloadType downloadType;
  final DownloadStatus status;
  final String? filePath;
  final int? fileSize;
  final int? downloadedBytes;
  final double progress;
  final String? errorMessage;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? seriesId;
  final String? seriesName;
  final int priority;         // Lower = higher priority
  final DateTime createdAt;
  final DateTime updatedAt;

  Download({
    required this.id,
    required this.playlistId,
    required this.contentId,
    required this.name,
    this.description,
    required this.sourceUrl,
    this.thumbnailUrl,
    required this.contentType,
    required this.downloadType,
    required this.status,
    this.filePath,
    this.fileSize,
    this.downloadedBytes,
    this.progress = 0.0,
    this.errorMessage,
    this.seasonNumber,
    this.episodeNumber,
    this.seriesId,
    this.seriesName,
    this.priority = 100,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == DownloadStatus.pending;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isCancelled => status == DownloadStatus.cancelled;

  bool get isVod => downloadType == DownloadType.vod;
  bool get isEpisode => downloadType == DownloadType.episode;
  bool get isSeries => downloadType == DownloadType.series;
  bool get isSeason => downloadType == DownloadType.season;

  String get displayName {
    if (isEpisode && seriesName != null) {
      return '$seriesName - S${seasonNumber ?? 0}E${episodeNumber ?? 0}: $name';
    }
    return name;
  }

  String get progressText {
    if (fileSize != null && fileSize! > 0) {
      final downloaded = downloadedBytes ?? 0;
      return '${_formatBytes(downloaded)} / ${_formatBytes(fileSize!)}';
    }
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Download copyWith({
    String? id,
    String? playlistId,
    String? contentId,
    String? name,
    String? description,
    String? sourceUrl,
    String? thumbnailUrl,
    ContentType? contentType,
    DownloadType? downloadType,
    DownloadStatus? status,
    String? filePath,
    int? fileSize,
    int? downloadedBytes,
    double? progress,
    String? errorMessage,
    int? seasonNumber,
    int? episodeNumber,
    String? seriesId,
    String? seriesName,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Download(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      contentId: contentId ?? this.contentId,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      contentType: contentType ?? this.contentType,
      downloadType: downloadType ?? this.downloadType,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      seriesId: seriesId ?? this.seriesId,
      seriesName: seriesName ?? this.seriesName,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'playlistId': playlistId,
    'contentId': contentId,
    'name': name,
    'description': description,
    'sourceUrl': sourceUrl,
    'thumbnailUrl': thumbnailUrl,
    'contentType': contentType.name,
    'downloadType': downloadType.name,
    'status': status.name,
    'filePath': filePath,
    'fileSize': fileSize,
    'downloadedBytes': downloadedBytes,
    'progress': progress,
    'errorMessage': errorMessage,
    'seasonNumber': seasonNumber,
    'episodeNumber': episodeNumber,
    'seriesId': seriesId,
    'seriesName': seriesName,
    'priority': priority,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Download.fromJson(Map<String, dynamic> json) => Download(
    id: json['id'] as String,
    playlistId: json['playlistId'] as String,
    contentId: json['contentId'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    sourceUrl: json['sourceUrl'] as String,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    contentType: ContentType.values.firstWhere(
          (e) => e.name == json['contentType'],
      orElse: () => ContentType.vod,
    ),
    downloadType: DownloadType.values.firstWhere(
          (e) => e.name == json['downloadType'],
      orElse: () => DownloadType.vod,
    ),
    status: DownloadStatus.values.firstWhere(
          (e) => e.name == json['status'],
      orElse: () => DownloadStatus.pending,
    ),
    filePath: json['filePath'] as String?,
    fileSize: json['fileSize'] as int?,
    downloadedBytes: json['downloadedBytes'] as int?,
    progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    errorMessage: json['errorMessage'] as String?,
    seasonNumber: json['seasonNumber'] as int?,
    episodeNumber: json['episodeNumber'] as int?,
    seriesId: json['seriesId'] as String?,
    seriesName: json['seriesName'] as String?,
    priority: json['priority'] as int? ?? 100,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
