import 'dart:io';

/// Represents the state of timeshift buffering for a live stream
class TimeshiftState {
  /// Maximum buffer duration (default 30 minutes)
  static const Duration maxBufferDuration = Duration(minutes: 30);

  /// Current buffer duration (how much content is buffered)
  final Duration bufferDuration;

  /// Current playback position within the buffer
  final Duration currentPosition;

  /// Time when buffering started
  final DateTime? bufferStartTime;

  /// Whether the stream is currently live (at the latest point)
  final bool isLive;

  /// Whether timeshift is actively buffering
  final bool isBuffering;

  /// Path to the temporary buffer file
  final String? bufferFilePath;

  /// Stream URL being buffered
  final String? streamUrl;

  /// Channel/content name
  final String? contentName;

  /// Channel/content ID
  final String? contentId;

  /// Playlist ID
  final String? playlistId;

  const TimeshiftState({
    this.bufferDuration = Duration.zero,
    this.currentPosition = Duration.zero,
    this.bufferStartTime,
    this.isLive = true,
    this.isBuffering = false,
    this.bufferFilePath,
    this.streamUrl,
    this.contentName,
    this.contentId,
    this.playlistId,
  });

  /// How far behind live the current position is
  Duration get behindLive => bufferDuration - currentPosition;

  /// Whether the user is behind live (paused or rewound)
  bool get isBehindLive => behindLive > const Duration(seconds: 5);

  /// Progress through the buffer (0.0 to 1.0)
  double get bufferProgress {
    if (bufferDuration.inSeconds == 0) return 1.0;
    return (currentPosition.inSeconds / bufferDuration.inSeconds).clamp(0.0, 1.0);
  }

  /// How much buffer space is remaining
  Duration get remainingBufferCapacity => maxBufferDuration - bufferDuration;

  /// Whether the buffer is full
  bool get isBufferFull => bufferDuration >= maxBufferDuration;

  /// Format behind live duration for display
  String get behindLiveText {
    final behind = behindLive;
    if (behind.inMinutes >= 1) {
      return '-${behind.inMinutes}:${(behind.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '-${behind.inSeconds}s';
  }

  /// Format buffer duration for display
  String get bufferDurationText {
    final mins = bufferDuration.inMinutes;
    final secs = bufferDuration.inSeconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }

  TimeshiftState copyWith({
    Duration? bufferDuration,
    Duration? currentPosition,
    DateTime? bufferStartTime,
    bool? isLive,
    bool? isBuffering,
    String? bufferFilePath,
    String? streamUrl,
    String? contentName,
    String? contentId,
    String? playlistId,
  }) {
    return TimeshiftState(
      bufferDuration: bufferDuration ?? this.bufferDuration,
      currentPosition: currentPosition ?? this.currentPosition,
      bufferStartTime: bufferStartTime ?? this.bufferStartTime,
      isLive: isLive ?? this.isLive,
      isBuffering: isBuffering ?? this.isBuffering,
      bufferFilePath: bufferFilePath ?? this.bufferFilePath,
      streamUrl: streamUrl ?? this.streamUrl,
      contentName: contentName ?? this.contentName,
      contentId: contentId ?? this.contentId,
      playlistId: playlistId ?? this.playlistId,
    );
  }
}

/// Represents a saved timeshift recording
class TimeshiftRecording {
  final String id;
  final String contentId;
  final String contentName;
  final String playlistId;
  final String filePath;
  final DateTime recordingStartTime;
  final DateTime recordingEndTime;
  final Duration duration;
  final String? thumbnailPath;
  final TimeshiftRecordingStatus status;

  const TimeshiftRecording({
    required this.id,
    required this.contentId,
    required this.contentName,
    required this.playlistId,
    required this.filePath,
    required this.recordingStartTime,
    required this.recordingEndTime,
    required this.duration,
    this.thumbnailPath,
    this.status = TimeshiftRecordingStatus.completed,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'contentId': contentId,
    'contentName': contentName,
    'playlistId': playlistId,
    'filePath': filePath,
    'recordingStartTime': recordingStartTime.toIso8601String(),
    'recordingEndTime': recordingEndTime.toIso8601String(),
    'duration': duration.inSeconds,
    'thumbnailPath': thumbnailPath,
    'status': status.name,
  };

  factory TimeshiftRecording.fromJson(Map<String, dynamic> json) => TimeshiftRecording(
    id: json['id'] as String,
    contentId: json['contentId'] as String,
    contentName: json['contentName'] as String,
    playlistId: json['playlistId'] as String,
    filePath: json['filePath'] as String,
    recordingStartTime: DateTime.parse(json['recordingStartTime'] as String),
    recordingEndTime: DateTime.parse(json['recordingEndTime'] as String),
    duration: Duration(seconds: json['duration'] as int),
    thumbnailPath: json['thumbnailPath'] as String?,
    status: TimeshiftRecordingStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => TimeshiftRecordingStatus.completed,
    ),
  );

  /// Check if the recording file exists
  Future<bool> fileExists() async {
    return File(filePath).exists();
  }
}

enum TimeshiftRecordingStatus {
  recording,
  saving,
  completed,
  failed,
}
