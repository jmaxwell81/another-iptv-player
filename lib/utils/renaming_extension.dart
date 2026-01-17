import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/services/renaming_service.dart';

extension RenamingExtension on String {
  /// Apply renaming rules to this string
  /// [contentType] - The type of content (liveStream, vod, series)
  /// [isCategory] - Set to true if this is a category name
  String applyRenamingRules({
    ContentType? contentType,
    bool isCategory = false,
  }) {
    return RenamingService().applyRulesSync(
      this,
      contentType: contentType,
      isCategory: isCategory,
    );
  }
}
