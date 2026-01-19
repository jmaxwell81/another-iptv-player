import 'package:drift/drift.dart';
import '../database/database.dart';

class EpgSource {
  final String playlistId;
  final String? epgUrl;
  final bool useDefaultUrl;
  final DateTime? lastFetched;
  final int programCount;

  EpgSource({
    required this.playlistId,
    this.epgUrl,
    this.useDefaultUrl = true,
    this.lastFetched,
    this.programCount = 0,
  });

  bool get hasData => programCount > 0;

  bool get needsRefresh {
    if (lastFetched == null) return true;
    // Refresh if data is older than 6 hours
    final sixHoursAgo = DateTime.now().subtract(const Duration(hours: 6));
    return lastFetched!.isBefore(sixHoursAgo);
  }

  factory EpgSource.fromData(EpgSourceData data) {
    return EpgSource(
      playlistId: data.playlistId,
      epgUrl: data.epgUrl,
      useDefaultUrl: data.useDefaultUrl,
      lastFetched: data.lastFetched,
      programCount: data.programCount,
    );
  }

  EpgSourcesCompanion toCompanion() {
    return EpgSourcesCompanion(
      playlistId: Value(playlistId),
      epgUrl: Value(epgUrl),
      useDefaultUrl: Value(useDefaultUrl),
      lastFetched: Value(lastFetched),
      programCount: Value(programCount),
    );
  }

  EpgSource copyWith({
    String? playlistId,
    String? epgUrl,
    bool? useDefaultUrl,
    DateTime? lastFetched,
    int? programCount,
  }) {
    return EpgSource(
      playlistId: playlistId ?? this.playlistId,
      epgUrl: epgUrl ?? this.epgUrl,
      useDefaultUrl: useDefaultUrl ?? this.useDefaultUrl,
      lastFetched: lastFetched ?? this.lastFetched,
      programCount: programCount ?? this.programCount,
    );
  }

  @override
  String toString() {
    return 'EpgSource(playlistId: $playlistId, epgUrl: $epgUrl, useDefaultUrl: $useDefaultUrl, programCount: $programCount)';
  }
}
