import 'package:another_iptv_player/models/content_type.dart';

/// Represents an item marked as offline (temporarily or permanently unavailable)
class OfflineItem {
  final String id;
  final String playlistId;
  final ContentType contentType;
  final String streamId;
  final String name;
  final String? imagePath;
  final DateTime markedAt;
  final bool autoDetected;
  final DateTime? temporaryUntil; // null = permanent

  const OfflineItem({
    required this.id,
    required this.playlistId,
    required this.contentType,
    required this.streamId,
    required this.name,
    this.imagePath,
    required this.markedAt,
    this.autoDetected = false,
    this.temporaryUntil,
  });

  /// Whether this is a temporary offline marking
  bool get isTemporary => temporaryUntil != null;

  /// Whether this temporary offline marking has expired
  bool get isExpired =>
      temporaryUntil != null && DateTime.now().isAfter(temporaryUntil!);

  /// Create a copy with modified fields
  OfflineItem copyWith({
    String? id,
    String? playlistId,
    ContentType? contentType,
    String? streamId,
    String? name,
    String? imagePath,
    DateTime? markedAt,
    bool? autoDetected,
    DateTime? temporaryUntil,
    bool clearTemporaryUntil = false,
  }) {
    return OfflineItem(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      contentType: contentType ?? this.contentType,
      streamId: streamId ?? this.streamId,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      markedAt: markedAt ?? this.markedAt,
      autoDetected: autoDetected ?? this.autoDetected,
      temporaryUntil:
          clearTemporaryUntil ? null : (temporaryUntil ?? this.temporaryUntil),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineItem &&
        other.id == id &&
        other.playlistId == playlistId &&
        other.streamId == streamId;
  }

  @override
  int get hashCode => Object.hash(id, playlistId, streamId);

  @override
  String toString() {
    return 'OfflineItem(id: $id, streamId: $streamId, name: $name, '
        'isTemporary: $isTemporary, isExpired: $isExpired)';
  }
}
