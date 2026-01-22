import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/language_country_mapping.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/content_filter_service.dart';

/// Dialog for bulk hiding/showing content items based on pattern matching.
/// Allows users to preview matching items before applying the filter.
class BulkHideDialog extends StatefulWidget {
  /// All available content items to filter from
  final List<ContentItem> allItems;

  /// Optional category ID to scope the filter
  final String? categoryId;

  /// Optional category name for display
  final String? categoryName;

  const BulkHideDialog({
    super.key,
    required this.allItems,
    this.categoryId,
    this.categoryName,
  });

  @override
  State<BulkHideDialog> createState() => _BulkHideDialogState();

  /// Show the dialog and return the created filter rule (if any)
  static Future<ContentFilterRule?> show(
    BuildContext context, {
    required List<ContentItem> allItems,
    String? categoryId,
    String? categoryName,
  }) {
    return showDialog<ContentFilterRule>(
      context: context,
      builder: (context) => BulkHideDialog(
        allItems: allItems,
        categoryId: categoryId,
        categoryName: categoryName,
      ),
    );
  }
}

class _BulkHideDialogState extends State<BulkHideDialog> {
  final _patternController = TextEditingController();
  final _filterService = ContentFilterService();
  bool _isRegex = false;
  bool _hideMatching = true;
  bool _applyToAllCategories = false;
  List<ContentItem> _matchingItems = [];
  Set<String> _selectedItems = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _filterService.initialize();
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  void _updateMatches() {
    final pattern = _patternController.text.trim();
    if (pattern.isEmpty) {
      setState(() {
        _matchingItems = [];
        _selectedItems.clear();
      });
      return;
    }

    final matches = _filterService.getMatchingItems(
      pattern,
      widget.allItems,
      isRegex: _isRegex,
    );

    setState(() {
      _matchingItems = matches;
      if (_selectAll) {
        _selectedItems = matches.map((item) => item.id).toSet();
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedItems = _matchingItems.map((item) => item.id).toSet();
      } else {
        _selectedItems.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.loc.bulk_hide_content,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (widget.categoryName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Category: ${widget.categoryName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(),

            // Pattern input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _patternController,
                    decoration: InputDecoration(
                      labelText: context.loc.pattern,
                      hintText: _isRegex ? '.*spanish.*' : '*spanish*',
                      helperText: _isRegex
                          ? 'Regular expression'
                          : 'Use * as wildcard',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _updateMatches,
                      ),
                    ),
                    onChanged: (_) => _updateMatches(),
                    onSubmitted: (_) => _updateMatches(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Options row
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _isRegex,
                      onChanged: (value) {
                        setState(() => _isRegex = value ?? false);
                        _updateMatches();
                      },
                    ),
                    Text(context.loc.use_regex),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _hideMatching,
                      onChanged: (value) {
                        setState(() => _hideMatching = value ?? true);
                      },
                    ),
                    Text(_hideMatching ? context.loc.hide_selected : context.loc.show_only_selected),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _applyToAllCategories,
                      onChanged: (value) {
                        setState(() => _applyToAllCategories = value ?? false);
                      },
                    ),
                    Text(context.loc.apply_to_all_categories),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Match count and select all
            Row(
              children: [
                Text(
                  '${_matchingItems.length} ${context.loc.items_matching}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (_matchingItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: _toggleSelectAll,
                    icon: Icon(_selectAll ? Icons.deselect : Icons.select_all),
                    label: Text(_selectAll ? context.loc.deselect_all : context.loc.select_all),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Matching items list
            Expanded(
              child: _matchingItems.isEmpty
                  ? Center(
                      child: Text(
                        _patternController.text.isEmpty
                            ? context.loc.enter_pattern_to_search
                            : context.loc.no_matches_found,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _matchingItems.length,
                      itemBuilder: (context, index) {
                        final item = _matchingItems[index];
                        final isSelected = _selectedItems.contains(item.id);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedItems.add(item.id);
                              } else {
                                _selectedItems.remove(item.id);
                              }
                              _selectAll = _selectedItems.length == _matchingItems.length;
                            });
                          },
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'ID: ${item.id}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          secondary: item.imagePath.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    item.imagePath,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image, size: 40),
                                  ),
                                )
                              : const Icon(Icons.tv, size: 40),
                        );
                      },
                    ),
            ),

            // Actions
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.loc.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _matchingItems.isEmpty ? null : _applyFilter,
                  icon: Icon(_hideMatching ? Icons.visibility_off : Icons.visibility),
                  label: Text(_hideMatching
                      ? context.loc.hide_count(_selectedItems.isEmpty
                          ? _matchingItems.length
                          : _selectedItems.length)
                      : context.loc.create_filter),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyFilter() async {
    final pattern = _patternController.text.trim();
    if (pattern.isEmpty) return;

    // Create the filter rule
    final rule = await _filterService.addFilterRule(
      pattern: pattern,
      isRegex: _isRegex,
      hideMatching: _hideMatching,
      appliesToContent: true,
      appliesToCategories: false,
      categoryIds: _applyToAllCategories ? null : (widget.categoryId != null ? {widget.categoryId!} : null),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hideMatching
                ? 'Hidden ${_matchingItems.length} items'
                : 'Created filter for ${_matchingItems.length} items',
          ),
        ),
      );
      Navigator.pop(context, rule);
    }
  }
}

/// Compact version of bulk hide for use in menus
class QuickHidePatternDialog extends StatefulWidget {
  final String? initialPattern;

  const QuickHidePatternDialog({super.key, this.initialPattern});

  @override
  State<QuickHidePatternDialog> createState() => _QuickHidePatternDialogState();

  static Future<String?> show(BuildContext context, {String? initialPattern}) {
    return showDialog<String>(
      context: context,
      builder: (context) => QuickHidePatternDialog(initialPattern: initialPattern),
    );
  }
}

class _QuickHidePatternDialogState extends State<QuickHidePatternDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPattern);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.loc.quick_hide_pattern),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: context.loc.pattern,
              hintText: '*spanish*',
              helperText: context.loc.pattern_wildcard_help,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final pattern = _controller.text.trim();
            if (pattern.isNotEmpty) {
              Navigator.pop(context, pattern);
            }
          },
          child: Text(context.loc.hide),
        ),
      ],
    );
  }
}
