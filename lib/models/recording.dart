import 'package:another_iptv_player/models/content_type.dart';

enum RecordingStatus {
  scheduled,
  recording,
  completed,
  failed,
  cancelled,
}

class Recording {
  final String id;
  final String playlistId;
  final String streamId;
  final String channelName;
  final String? programTitle;
  final String? programDescription;
  final String streamUrl;
  final String? channelIcon;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final RecordingStatus status;
  final String? filePath;
  final int? fileSize;
  final String? errorMessage;
  final ContentType contentType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recording({
    required this.id,
    required this.playlistId,
    required this.streamId,
    required this.channelName,
    this.programTitle,
    this.programDescription,
    required this.streamUrl,
    this.channelIcon,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    required this.status,
    this.filePath,
    this.fileSize,
    this.errorMessage,
    required this.contentType,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isScheduled => status == RecordingStatus.scheduled;
  bool get isRecording => status == RecordingStatus.recording;
  bool get isCompleted => status == RecordingStatus.completed;
  bool get isFailed => status == RecordingStatus.failed;
  bool get isCancelled => status == RecordingStatus.cancelled;

  Duration get scheduledDuration => scheduledEnd.difference(scheduledStart);
  Duration? get actualDuration => actualStart != null && actualEnd != null
      ? actualEnd!.difference(actualStart!)
      : null;

  double get progress {
    if (!isRecording || actualStart == null) return 0;
    final elapsed = DateTime.now().difference(actualStart!);
    final total = scheduledEnd.difference(actualStart!);
    return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }

  Recording copyWith({
    String? id,
    String? playlistId,
    String? streamId,
    String? channelName,
    String? programTitle,
    String? programDescription,
    String? streamUrl,
    String? channelIcon,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? actualStart,
    DateTime? actualEnd,
    RecordingStatus? status,
    String? filePath,
    int? fileSize,
    String? errorMessage,
    ContentType? contentType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recording(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      streamId: streamId ?? this.streamId,
      channelName: channelName ?? this.channelName,
      programTitle: programTitle ?? this.programTitle,
      programDescription: programDescription ?? this.programDescription,
      streamUrl: streamUrl ?? this.streamUrl,
      channelIcon: channelIcon ?? this.channelIcon,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      errorMessage: errorMessage ?? this.errorMessage,
      contentType: contentType ?? this.contentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'playlistId': playlistId,
    'streamId': streamId,
    'channelName': channelName,
    'programTitle': programTitle,
    'programDescription': programDescription,
    'streamUrl': streamUrl,
    'channelIcon': channelIcon,
    'scheduledStart': scheduledStart.toIso8601String(),
    'scheduledEnd': scheduledEnd.toIso8601String(),
    'actualStart': actualStart?.toIso8601String(),
    'actualEnd': actualEnd?.toIso8601String(),
    'status': status.name,
    'filePath': filePath,
    'fileSize': fileSize,
    'errorMessage': errorMessage,
    'contentType': contentType.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
    id: json['id'] as String,
    playlistId: json['playlistId'] as String,
    streamId: json['streamId'] as String,
    channelName: json['channelName'] as String,
    programTitle: json['programTitle'] as String?,
    programDescription: json['programDescription'] as String?,
    streamUrl: json['streamUrl'] as String,
    channelIcon: json['channelIcon'] as String?,
    scheduledStart: DateTime.parse(json['scheduledStart'] as String),
    scheduledEnd: DateTime.parse(json['scheduledEnd'] as String),
    actualStart: json['actualStart'] != null
        ? DateTime.parse(json['actualStart'] as String)
        : null,
    actualEnd: json['actualEnd'] != null
        ? DateTime.parse(json['actualEnd'] as String)
        : null,
    status: RecordingStatus.values.firstWhere(
          (e) => e.name == json['status'],
      orElse: () => RecordingStatus.scheduled,
    ),
    filePath: json['filePath'] as String?,
    fileSize: json['fileSize'] as int?,
    errorMessage: json['errorMessage'] as String?,
    contentType: ContentType.values.firstWhere(
          (e) => e.name == json['contentType'],
      orElse: () => ContentType.liveStream,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
