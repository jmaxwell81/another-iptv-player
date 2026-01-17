import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/custom_rename.dart';
import 'package:another_iptv_player/services/custom_rename_service.dart';

/// Dialog for renaming an individual item
class RenameDialog extends StatefulWidget {
  final String currentName;
  final String itemId;
  final String? playlistId;
  final CustomRenameType type;

  const RenameDialog({
    super.key,
    required this.currentName,
    required this.itemId,
    this.playlistId,
    required this.type,
  });

  /// Show the rename dialog and return the new name (or null if cancelled)
  static Future<String?> show({
    required BuildContext context,
    required String currentName,
    required String itemId,
    String? playlistId,
    required CustomRenameType type,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        currentName: currentName,
        itemId: itemId,
        playlistId: playlistId,
        type: type,
      ),
    );
  }

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;
  bool _hasCustomName = false;
  String? _originalName;

  @override
  void initState() {
    super.initState();

    // Check if there's an existing custom name
    _hasCustomName = CustomRenameService().hasCustomName(
      widget.type,
      widget.itemId,
      widget.playlistId,
    );

    if (_hasCustomName) {
      _originalName = CustomRenameService().getOriginalName(
        widget.type,
        widget.itemId,
        widget.playlistId,
      );
    }

    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    // Get the original name (either from existing custom rename or current display name)
    final originalName = _originalName ?? widget.currentName;

    // If the new name is the same as the original, remove the custom rename
    if (newName == originalName && _hasCustomName) {
      await CustomRenameService().removeCustomName(
        widget.type,
        widget.itemId,
        widget.playlistId,
      );
    } else if (newName != originalName) {
      // Save the new custom name
      await CustomRenameService().setCustomName(
        type: widget.type,
        itemId: widget.itemId,
        originalName: originalName,
        customName: newName,
        playlistId: widget.playlistId,
      );
    }

    if (mounted) {
      Navigator.pop(context, newName);
    }
  }

  Future<void> _resetToOriginal() async {
    if (_hasCustomName && _originalName != null) {
      await CustomRenameService().removeCustomName(
        widget.type,
        widget.itemId,
        widget.playlistId,
      );
      if (mounted) {
        Navigator.pop(context, _originalName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rename ${widget.type.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasCustomName && _originalName != null) ...[
            Text(
              'Original name:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _originalName!,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (_hasCustomName)
          TextButton(
            onPressed: _resetToOriginal,
            child: const Text('Reset'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
