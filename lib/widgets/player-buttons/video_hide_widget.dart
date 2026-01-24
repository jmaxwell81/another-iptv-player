import 'dart:async';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/hidden_items_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/player_state.dart';
import 'package:flutter/material.dart';
import '../../models/content_type.dart';

/// Widget to hide/unhide the current channel from the player
class VideoHideWidget extends StatefulWidget {
  const VideoHideWidget({super.key});

  @override
  State<VideoHideWidget> createState() => _VideoHideWidgetState();
}

class _VideoHideWidgetState extends State<VideoHideWidget> {
  bool _isHidden = false;
  final HiddenItemsRepository _hiddenItemsRepository = HiddenItemsRepository();
  StreamSubscription? _contentItemSubscription;

  @override
  void initState() {
    super.initState();
    _checkHiddenStatus();

    // Update hidden status when content item changes
    _contentItemSubscription = EventBus()
        .on<ContentItem>('player_content_item')
        .listen((ContentItem item) {
      _checkHiddenStatus();
    });
  }

  @override
  void dispose() {
    _contentItemSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkHiddenStatus() async {
    final currentContent = PlayerState.currentContent;
    if (currentContent == null) return;

    // Only check for live streams
    if (currentContent.contentType == ContentType.liveStream) {
      final playlistId = currentContent.sourcePlaylistId ??
          AppState.currentPlaylist?.id;
      if (playlistId == null) return;

      final isHidden = await _hiddenItemsRepository.isHidden(
        playlistId,
        currentContent.id,
        currentContent.contentType,
      );
      if (mounted) {
        setState(() {
          _isHidden = isHidden;
        });
      }
    }
  }

  Future<void> _toggleHidden() async {
    final currentContent = PlayerState.currentContent;
    if (currentContent == null) return;

    if (currentContent.contentType != ContentType.liveStream) return;

    // Show confirmation dialog before hiding
    if (!_isHidden) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hide Channel'),
          content: Text(
            'Hide "${currentContent.name}" from the channel list?\n\n'
            'You can unhide it later from Settings > Hidden Items.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Hide'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      if (_isHidden) {
        await _hiddenItemsRepository.unhideContentItem(currentContent);
        if (mounted) {
          setState(() {
            _isHidden = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${currentContent.name} is now visible'),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green.shade700,
              showCloseIcon: true,
              closeIconColor: Colors.white,
            ),
          );
        }
      } else {
        await _hiddenItemsRepository.hideContentItem(currentContent);
        if (mounted) {
          setState(() {
            _isHidden = true;
          });
          // Capture ScaffoldMessenger before navigation to ensure snackbar auto-dismisses
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('${currentContent.name} hidden'),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange.shade700,
              showCloseIcon: true,
              closeIconColor: Colors.white,
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () async {
                  await _hiddenItemsRepository.unhideContentItem(currentContent);
                  if (mounted) {
                    setState(() {
                      _isHidden = false;
                    });
                  }
                },
              ),
            ),
          );
          // Go back after hiding
          if (mounted) {
            Navigator.of(context).maybePop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            showCloseIcon: true,
            closeIconColor: Colors.white,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentContent = PlayerState.currentContent;

    // Only show for live streams
    if (currentContent == null ||
        currentContent.contentType != ContentType.liveStream) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: _isHidden ? 'Unhide channel' : 'Hide channel',
      icon: Icon(
        _isHidden ? Icons.visibility : Icons.visibility_off_outlined,
        color: _isHidden ? Colors.orange : Colors.white,
      ),
      onPressed: _toggleHidden,
    );
  }
}
