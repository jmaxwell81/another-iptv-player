import 'dart:io';

/// Status of a recording job
enum RecordingStatus {
  pending,      // Waiting to start
  recording,    // Actively recording
  paused,       // Temporarily paused (future feature)
  completing,   // Finishing up the recording
  completed,    // Successfully completed
  failed,       // Failed with error
  cancelled,    // Cancelled by user
}

/// Represents an active or completed recording job
class RecordingJob {
  final String id;
  final String contentId;
  final String contentName;
  final String playlistId;
  final String streamUrl;
  final String filePath;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration targetDuration;
  final Duration recordedDuration;
  final RecordingStatus status;
  final String? errorMessage;
  final int? processId;  // FFmpeg process ID for management

  const RecordingJob({
    required this.id,
    required this.contentId,
    required this.contentName,
    required this.playlistId,
    required this.streamUrl,
    required this.filePath,
    required this.startTime,
    this.endTime,
    required this.targetDuration,
    this.recordedDuration = Duration.zero,
    this.status = RecordingStatus.pending,
    this.errorMessage,
    this.processId,
  });

  /// Progress as a value from 0.0 to 1.0
  double get progress {
    if (targetDuration.inSeconds == 0) return 0.0;
    return (recordedDuration.inSeconds / targetDuration.inSeconds).clamp(0.0, 1.0);
  }

  /// Remaining duration
  Duration get remainingDuration {
    final remaining = targetDuration - recordedDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether the job is still active
  bool get isActive => status == RecordingStatus.recording || status == RecordingStatus.pending;

  /// Whether the job can be cancelled
  bool get canCancel => status == RecordingStatus.recording || status == RecordingStatus.pending;

  /// Whether the recording can be extended
  bool get canExtend => status == RecordingStatus.recording;

  /// Format duration for display (e.g., "15:30")
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Recorded duration text
  String get recordedDurationText => formatDuration(recordedDuration);

  /// Target duration text
  String get targetDurationText => formatDuration(targetDuration);

  /// Remaining duration text
  String get remainingDurationText => formatDuration(remainingDuration);

  /// Status display text
  String get statusText {
    switch (status) {
      case RecordingStatus.pending:
        return 'Starting...';
      case RecordingStatus.recording:
        return 'Recording';
      case RecordingStatus.paused:
        return 'Paused';
      case RecordingStatus.completing:
        return 'Completing...';
      case RecordingStatus.completed:
        return 'Completed';
      case RecordingStatus.failed:
        return 'Failed';
      case RecordingStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Check if the recording file exists
  Future<bool> fileExists() async {
    return File(filePath).exists();
  }

  /// Get file size in bytes
  Future<int> getFileSize() async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      // Ignore
    }
    return 0;
  }

  RecordingJob copyWith({
    String? id,
    String? contentId,
    String? contentName,
    String? playlistId,
    String? streamUrl,
    String? filePath,
    DateTime? startTime,
    DateTime? endTime,
    Duration? targetDuration,
    Duration? recordedDuration,
    RecordingStatus? status,
    String? errorMessage,
    int? processId,
  }) {
    return RecordingJob(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      contentName: contentName ?? this.contentName,
      playlistId: playlistId ?? this.playlistId,
      streamUrl: streamUrl ?? this.streamUrl,
      filePath: filePath ?? this.filePath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      targetDuration: targetDuration ?? this.targetDuration,
      recordedDuration: recordedDuration ?? this.recordedDuration,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      processId: processId ?? this.processId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'contentId': contentId,
    'contentName': contentName,
    'playlistId': playlistId,
    'streamUrl': streamUrl,
    'filePath': filePath,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'targetDuration': targetDuration.inSeconds,
    'recordedDuration': recordedDuration.inSeconds,
    'status': status.name,
    'errorMessage': errorMessage,
    'processId': processId,
  };

  factory RecordingJob.fromJson(Map<String, dynamic> json) => RecordingJob(
    id: json['id'] as String,
    contentId: json['contentId'] as String,
    contentName: json['contentName'] as String,
    playlistId: json['playlistId'] as String,
    streamUrl: json['streamUrl'] as String,
    filePath: json['filePath'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
    targetDuration: Duration(seconds: json['targetDuration'] as int),
    recordedDuration: Duration(seconds: json['recordedDuration'] as int? ?? 0),
    status: RecordingStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => RecordingStatus.failed,
    ),
    errorMessage: json['errorMessage'] as String?,
    processId: json['processId'] as int?,
  );
}
