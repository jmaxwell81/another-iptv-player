import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/consolidated_content_item.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';

class CategoryViewModel {
  final Category category;
  final List<ContentItem> contentItems;

  /// Consolidated items (if consolidation is enabled).
  /// When populated, these should be used instead of contentItems for display.
  final List<ConsolidatedContentItem>? consolidatedItems;

  CategoryViewModel({
    required this.category,
    required this.contentItems,
    this.consolidatedItems,
  });

  /// Whether this category has consolidated content
  bool get hasConsolidatedContent =>
      consolidatedItems != null && consolidatedItems!.isNotEmpty;

  /// Get the effective item count (consolidated if available, otherwise raw)
  int get effectiveItemCount =>
      hasConsolidatedContent ? consolidatedItems!.length : contentItems.length;

  /// Get ContentItems for display (from consolidated items if available)
  List<ContentItem> get displayItems {
    if (hasConsolidatedContent) {
      return consolidatedItems!.map((c) => c.toContentItem()).toList();
    }
    return contentItems;
  }

  /// Create a copy with consolidated items
  CategoryViewModel withConsolidatedItems(
    List<ConsolidatedContentItem> consolidated,
  ) {
    return CategoryViewModel(
      category: category,
      contentItems: contentItems,
      consolidatedItems: consolidated,
    );
  }
}