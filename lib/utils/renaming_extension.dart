import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/services/custom_rename_service.dart';
import 'package:another_iptv_player/services/renaming_service.dart';

extension RenamingExtension on String {
  /// Apply renaming rules to this string
  /// [contentType] - The type of content (liveStream, vod, series)
  /// [isCategory] - Set to true if this is a category name
  /// [itemId] - Optional item ID for custom rename lookup
  /// [playlistId] - Optional playlist ID for scoping custom renames
  String applyRenamingRules({
    ContentType? contentType,
    bool isCategory = false,
    String? itemId,
    String? playlistId,
  }) {
    // Check for custom rename first if itemId is provided
    if (itemId != null) {
      final customRenameType = isCategory
          ? CustomRenameType.category
          : _contentTypeToCustomRenameType(contentType);

      final customName = CustomRenameService().getCustomNameSync(
        customRenameType,
        itemId,
        playlistId,
      );

      if (customName != null) {
        return customName;
      }
    }

    // Fall back to renaming rules
    return RenamingService().applyRulesSync(
      this,
      contentType: contentType,
      isCategory: isCategory,
    );
  }

  /// Convert ContentType to CustomRenameType
  CustomRenameType _contentTypeToCustomRenameType(ContentType? contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return CustomRenameType.liveStream;
      case ContentType.vod:
        return CustomRenameType.vod;
      case ContentType.series:
        return CustomRenameType.series;
      default:
        return CustomRenameType.liveStream;
    }
  }
}
