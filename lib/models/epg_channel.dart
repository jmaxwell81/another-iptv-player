import 'package:drift/drift.dart';
import '../database/database.dart';

class EpgChannel {
  final String channelId;
  final String playlistId;
  final String displayName;
  final String? icon;
  final DateTime lastUpdated;

  EpgChannel({
    required this.channelId,
    required this.playlistId,
    required this.displayName,
    this.icon,
    required this.lastUpdated,
  });

  factory EpgChannel.fromData(EpgChannelData data) {
    return EpgChannel(
      channelId: data.channelId,
      playlistId: data.playlistId,
      displayName: data.displayName,
      icon: data.icon,
      lastUpdated: data.lastUpdated,
    );
  }

  EpgChannelsCompanion toCompanion() {
    return EpgChannelsCompanion(
      channelId: Value(channelId),
      playlistId: Value(playlistId),
      displayName: Value(displayName),
      icon: Value(icon),
      lastUpdated: Value(lastUpdated),
    );
  }

  EpgChannel copyWith({
    String? channelId,
    String? playlistId,
    String? displayName,
    String? icon,
    DateTime? lastUpdated,
  }) {
    return EpgChannel(
      channelId: channelId ?? this.channelId,
      playlistId: playlistId ?? this.playlistId,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'EpgChannel(channelId: $channelId, displayName: $displayName, playlistId: $playlistId)';
  }
}
