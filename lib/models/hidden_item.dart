import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import 'content_type.dart';

class HiddenItem {
  final String id;
  final String playlistId;
  final ContentType contentType;
  final String streamId;
  final String name;
  final String? imagePath;
  final DateTime createdAt;

  HiddenItem({
    String? id,
    required this.playlistId,
    required this.contentType,
    required this.streamId,
    required this.name,
    this.imagePath,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory HiddenItem.fromDrift(HiddenItemsData data) {
    return HiddenItem(
      id: data.id,
      playlistId: data.playlistId,
      contentType: ContentType.values[data.contentType],
      streamId: data.streamId,
      name: data.name,
      imagePath: data.imagePath,
      createdAt: data.createdAt,
    );
  }

  HiddenItemsCompanion toCompanion() {
    return HiddenItemsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      contentType: Value(contentType.index),
      streamId: Value(streamId),
      name: Value(name),
      imagePath: Value(imagePath),
      createdAt: Value(createdAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiddenItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
