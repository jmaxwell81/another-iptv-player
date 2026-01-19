import 'package:drift/drift.dart';
import '../database/database.dart';

class EpgProgram {
  final String id;
  final String channelId;
  final String playlistId;
  final String title;
  final String? description;
  final String? category;
  final String? icon;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? createdAt;

  EpgProgram({
    required this.id,
    required this.channelId,
    required this.playlistId,
    required this.title,
    this.description,
    this.category,
    this.icon,
    required this.startTime,
    required this.endTime,
    this.createdAt,
  });

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  bool get isPast => DateTime.now().isAfter(endTime);

  bool get isFuture => DateTime.now().isBefore(startTime);

  Duration get duration => endTime.difference(startTime);

  double get progress {
    if (!isLive) return isPast ? 1.0 : 0.0;
    final now = DateTime.now();
    final elapsed = now.difference(startTime).inSeconds;
    final total = duration.inSeconds;
    if (total <= 0) return 0.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Duration get remainingTime {
    if (isPast) return Duration.zero;
    if (isFuture) return duration;
    return endTime.difference(DateTime.now());
  }

  factory EpgProgram.fromData(EpgProgramData data) {
    return EpgProgram(
      id: data.id,
      channelId: data.channelId,
      playlistId: data.playlistId,
      title: data.title,
      description: data.description,
      category: data.category,
      icon: data.icon,
      startTime: data.startTime,
      endTime: data.endTime,
      createdAt: data.createdAt,
    );
  }

  EpgProgramsCompanion toCompanion() {
    return EpgProgramsCompanion(
      id: Value(id),
      channelId: Value(channelId),
      playlistId: Value(playlistId),
      title: Value(title),
      description: Value(description),
      category: Value(category),
      icon: Value(icon),
      startTime: Value(startTime),
      endTime: Value(endTime),
    );
  }

  static String generateId(String channelId, DateTime startTime, String playlistId) {
    return '${channelId}_${startTime.millisecondsSinceEpoch}_$playlistId';
  }

  EpgProgram copyWith({
    String? id,
    String? channelId,
    String? playlistId,
    String? title,
    String? description,
    String? category,
    String? icon,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
  }) {
    return EpgProgram(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      playlistId: playlistId ?? this.playlistId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'EpgProgram(title: $title, channelId: $channelId, startTime: $startTime, endTime: $endTime)';
  }
}
