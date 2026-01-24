import 'package:flutter/material.dart';
import '../models/playlist_url.dart';

/// Widget for editing multiple URLs with reordering, add/remove, and health status
class MultiUrlEditor extends StatefulWidget {
  final String? primaryUrl;
  final List<String> additionalUrls;
  final bool showHealthStatus;
  final Map<String, UrlStatus>? urlStatusMap;
  final Function(String? primary, List<String> additional) onUrlsChanged;
  final Future<UrlHealthCheckResult> Function(String url)? onCheckHealth;

  const MultiUrlEditor({
    super.key,
    this.primaryUrl,
    this.additionalUrls = const [],
    this.showHealthStatus = false,
    this.urlStatusMap,
    required this.onUrlsChanged,
    this.onCheckHealth,
  });

  @override
  State<MultiUrlEditor> createState() => _MultiUrlEditorState();
}

class _MultiUrlEditorState extends State<MultiUrlEditor> {
  late List<TextEditingController> _controllers;
  final Map<int, bool> _isChecking = {};
  final Map<int, UrlStatus> _statusCache = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final allUrls = <String>[];
    if (widget.primaryUrl != null && widget.primaryUrl!.isNotEmpty) {
      allUrls.add(widget.primaryUrl!);
    }
    allUrls.addAll(widget.additionalUrls.where((u) => u.isNotEmpty));

    // Ensure at least one empty field for new input
    if (allUrls.isEmpty) {
      allUrls.add('');
    }

    _controllers = allUrls.map((url) => TextEditingController(text: url)).toList();

    // Initialize status cache from urlStatusMap
    if (widget.urlStatusMap != null) {
      for (var i = 0; i < _controllers.length; i++) {
        final url = _controllers[i].text;
        if (widget.urlStatusMap!.containsKey(url)) {
          _statusCache[i] = widget.urlStatusMap![url]!;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    final urls = _controllers.map((c) => c.text.trim()).where((u) => u.isNotEmpty).toList();
    final primary = urls.isNotEmpty ? urls.first : null;
    final additional = urls.length > 1 ? urls.sublist(1) : <String>[];
    widget.onUrlsChanged(primary, additional);
  }

  void _addUrl() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeUrl(int index) {
    if (_controllers.length <= 1) return;

    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
      _statusCache.remove(index);
      _isChecking.remove(index);

      // Reindex status cache
      final newCache = <int, UrlStatus>{};
      for (final entry in _statusCache.entries) {
        if (entry.key > index) {
          newCache[entry.key - 1] = entry.value;
        } else {
          newCache[entry.key] = entry.value;
        }
      }
      _statusCache.clear();
      _statusCache.addAll(newCache);
    });

    _notifyChanged();
  }

  void _moveUrl(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    setState(() {
      final controller = _controllers.removeAt(oldIndex);
      _controllers.insert(newIndex, controller);

      // Move status cache
      final oldStatus = _statusCache.remove(oldIndex);
      final entries = _statusCache.entries.toList();
      _statusCache.clear();

      for (final entry in entries) {
        int newKey = entry.key;
        if (entry.key > oldIndex && entry.key <= newIndex) {
          newKey = entry.key - 1;
        } else if (entry.key < oldIndex && entry.key >= newIndex) {
          newKey = entry.key + 1;
        }
        _statusCache[newKey] = entry.value;
      }

      if (oldStatus != null) {
        _statusCache[newIndex] = oldStatus;
      }
    });

    _notifyChanged();
  }

  Future<void> _checkHealth(int index) async {
    if (widget.onCheckHealth == null) return;

    final url = _controllers[index].text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isChecking[index] = true;
    });

    try {
      final result = await widget.onCheckHealth!(url);
      if (mounted) {
        setState(() {
          _statusCache[index] = result.status;
          _isChecking[index] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusCache[index] = UrlStatus.error;
          _isChecking[index] = false;
        });
      }
    }
  }

  Color _getStatusColor(UrlStatus status) {
    switch (status) {
      case UrlStatus.online:
        return Colors.green;
      case UrlStatus.offline:
      case UrlStatus.timeout:
        return Colors.red;
      case UrlStatus.error:
        return Colors.orange;
      case UrlStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(UrlStatus status) {
    switch (status) {
      case UrlStatus.online:
        return Icons.check_circle;
      case UrlStatus.offline:
        return Icons.cloud_off;
      case UrlStatus.timeout:
        return Icons.timer_off;
      case UrlStatus.error:
        return Icons.error;
      case UrlStatus.unknown:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Server URLs',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addUrl,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add URL'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Hint text
        Text(
          'Primary URL is used first. Backup URLs are tried if primary fails.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),

        // URL list
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _controllers.length,
          onReorder: _moveUrl,
          itemBuilder: (context, index) {
            return _buildUrlField(context, index);
          },
        ),
      ],
    );
  }

  Widget _buildUrlField(BuildContext context, int index) {
    final theme = Theme.of(context);
    final isPrimary = index == 0;
    final isChecking = _isChecking[index] ?? false;
    final status = _statusCache[index];

    return Container(
      key: ValueKey(_controllers[index]),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),

          // URL field
          Expanded(
            child: TextField(
              controller: _controllers[index],
              decoration: InputDecoration(
                labelText: isPrimary ? 'Primary URL' : 'Backup URL ${index}',
                hintText: 'http://example.com:8080',
                border: const OutlineInputBorder(),
                prefixIcon: isPrimary
                    ? const Icon(Icons.star, color: Colors.amber)
                    : Icon(Icons.backup, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                suffixIcon: widget.showHealthStatus && status != null
                    ? Icon(_getStatusIcon(status), color: _getStatusColor(status))
                    : null,
              ),
              onChanged: (_) => _notifyChanged(),
              keyboardType: TextInputType.url,
            ),
          ),

          const SizedBox(width: 4),

          // Health check button
          if (widget.onCheckHealth != null)
            IconButton(
              onPressed: isChecking ? null : () => _checkHealth(index),
              icon: isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              tooltip: 'Check connection',
            ),

          // Remove button
          if (_controllers.length > 1)
            IconButton(
              onPressed: () => _removeUrl(index),
              icon: const Icon(Icons.remove_circle_outline),
              color: theme.colorScheme.error,
              tooltip: 'Remove URL',
            ),
        ],
      ),
    );
  }
}

/// Compact version showing URL status chips
class MultiUrlStatusChips extends StatelessWidget {
  final List<PlaylistUrl> urls;
  final VoidCallback? onTap;

  const MultiUrlStatusChips({
    super.key,
    required this.urls,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final onlineCount = urls.where((u) => u.status == UrlStatus.online).length;
    final offlineCount = urls.where((u) =>
      u.status == UrlStatus.offline ||
      u.status == UrlStatus.timeout ||
      u.status == UrlStatus.error
    ).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Online count
          if (onlineCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '$onlineCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Offline count
          if (offlineCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    '$offlineCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Total count
          const SizedBox(width: 4),
          Text(
            '${urls.length} URLs',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for editing playlist URLs
class MultiUrlEditorDialog extends StatefulWidget {
  final String? primaryUrl;
  final List<String> additionalUrls;
  final Future<UrlHealthCheckResult> Function(String url)? onCheckHealth;

  const MultiUrlEditorDialog({
    super.key,
    this.primaryUrl,
    this.additionalUrls = const [],
    this.onCheckHealth,
  });

  @override
  State<MultiUrlEditorDialog> createState() => _MultiUrlEditorDialogState();
}

class _MultiUrlEditorDialogState extends State<MultiUrlEditorDialog> {
  String? _primaryUrl;
  List<String> _additionalUrls = [];

  @override
  void initState() {
    super.initState();
    _primaryUrl = widget.primaryUrl;
    _additionalUrls = List.from(widget.additionalUrls);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Server URLs'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: MultiUrlEditor(
            primaryUrl: _primaryUrl,
            additionalUrls: _additionalUrls,
            showHealthStatus: true,
            onCheckHealth: widget.onCheckHealth,
            onUrlsChanged: (primary, additional) {
              setState(() {
                _primaryUrl = primary;
                _additionalUrls = additional;
              });
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (_primaryUrl, _additionalUrls),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
