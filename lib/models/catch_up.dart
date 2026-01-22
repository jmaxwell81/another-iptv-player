/// Represents a Catch Up program that can be watched later
class CatchUpProgram {
  final String id;
  final String channelId;
  final String channelName;
  final String playlistId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? icon;
  final String catchUpUrl;

  CatchUpProgram({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.playlistId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.icon,
    required this.catchUpUrl,
  });

  Duration get duration => endTime.difference(startTime);

  bool get isAvailable {
    final now = DateTime.now();
    // Catch up is available for content that has already aired
    return endTime.isBefore(now);
  }

  /// Format time range for display
  String get timeRangeText {
    final startHour = startTime.hour.toString().padLeft(2, '0');
    final startMin = startTime.minute.toString().padLeft(2, '0');
    final endHour = endTime.hour.toString().padLeft(2, '0');
    final endMin = endTime.minute.toString().padLeft(2, '0');
    return '$startHour:$startMin - $endHour:$endMin';
  }

  /// Format date for display
  String get dateText {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final programDate = DateTime(startTime.year, startTime.month, startTime.day);

    if (programDate == today) {
      return 'Today';
    } else if (programDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${startTime.day}/${startTime.month}/${startTime.year}';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'channelName': channelName,
    'playlistId': playlistId,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'icon': icon,
    'catchUpUrl': catchUpUrl,
  };

  factory CatchUpProgram.fromJson(Map<String, dynamic> json) => CatchUpProgram(
    id: json['id'] as String,
    channelId: json['channelId'] as String,
    channelName: json['channelName'] as String,
    playlistId: json['playlistId'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    icon: json['icon'] as String?,
    catchUpUrl: json['catchUpUrl'] as String,
  );
}

/// Configuration for Catch Up feature per channel
class CatchUpConfig {
  final String channelId;
  final String playlistId;
  final bool enabled;
  final int catchUpDays; // How many days back catch up is available
  final String? catchUpSource; // Custom catch up source/URL pattern

  CatchUpConfig({
    required this.channelId,
    required this.playlistId,
    this.enabled = true,
    this.catchUpDays = 7,
    this.catchUpSource,
  });

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'playlistId': playlistId,
    'enabled': enabled,
    'catchUpDays': catchUpDays,
    'catchUpSource': catchUpSource,
  };

  factory CatchUpConfig.fromJson(Map<String, dynamic> json) => CatchUpConfig(
    channelId: json['channelId'] as String,
    playlistId: json['playlistId'] as String,
    enabled: json['enabled'] as bool? ?? true,
    catchUpDays: json['catchUpDays'] as int? ?? 7,
    catchUpSource: json['catchUpSource'] as String?,
  );
}
