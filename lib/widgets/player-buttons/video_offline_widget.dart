import 'dart:async';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/offline_items_repository.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:another_iptv_player/services/player_state.dart';
import 'package:flutter/material.dart';
import '../../models/content_type.dart';

/// Widget to mark the current channel as offline/online from the player
class VideoOfflineWidget extends StatefulWidget {
  const VideoOfflineWidget({super.key});

  @override
  State<VideoOfflineWidget> createState() => _VideoOfflineWidgetState();
}

class _VideoOfflineWidgetState extends State<VideoOfflineWidget> {
  bool _isOffline = false;
  final OfflineItemsRepository _offlineItemsRepository = OfflineItemsRepository();
  StreamSubscription? _contentItemSubscription;
  int _tempHideHours = 48;

  @override
  void initState() {
    super.initState();
    _checkOfflineStatus();
    _loadSettings();

    // Update offline status when content item changes
    _contentItemSubscription = EventBus()
        .on<ContentItem>('player_content_item')
        .listen((ContentItem item) {
      _checkOfflineStatus();
    });
  }

  @override
  void dispose() {
    _contentItemSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _tempHideHours = await UserPreferences.getOfflineStreamTempHideHours();
  }

  Future<void> _checkOfflineStatus() async {
    final currentContent = PlayerState.currentContent;
    if (currentContent == null) return;

    // Only check for live streams
    if (currentContent.contentType == ContentType.liveStream) {
      final playlistId = currentContent.sourcePlaylistId ??
          AppState.currentPlaylist?.id;
      if (playlistId == null) return;

      final isOffline = await _offlineItemsRepository.isOffline(
        playlistId,
        currentContent.id,
      );
      if (mounted) {
        setState(() {
          _isOffline = isOffline;
        });
      }
    }
  }

  Future<void> _showOfflineMenu() async {
    final currentContent = PlayerState.currentContent;
    if (currentContent == null) return;

    if (currentContent.contentType != ContentType.liveStream) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                _isOffline ? 'Channel Marked Offline' : 'Mark Channel as Offline',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                _isOffline
                    ? 'This channel will be skipped during navigation'
                    : 'Mark this channel as unavailable to skip it during navigation',
              ),
            ),
            const Divider(),
            if (_isOffline) ...[
              ListTile(
                leading: const Icon(Icons.signal_wifi_4_bar, color: Colors.green),
                title: const Text('Mark Online'),
                subtitle: const Text('Remove offline status'),
                onTap: () => Navigator.pop(context, 'online'),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.signal_wifi_off, color: Colors.orange),
                title: Text('Mark Offline ($_tempHideHours hours)'),
                subtitle: const Text('Temporary - will auto-restore'),
                onTap: () => Navigator.pop(context, 'temp'),
              ),
              ListTile(
                leading: const Icon(Icons.signal_wifi_off, color: Colors.red),
                title: const Text('Mark Offline (Permanent)'),
                subtitle: const Text('Until manually restored'),
                onTap: () => Navigator.pop(context, 'permanent'),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      if (result == 'online') {
        await _offlineItemsRepository.markOnline(currentContent);
        if (mounted) {
          setState(() {
            _isOffline = false;
          });
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('${currentContent.name} marked as online'),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green.shade700,
              showCloseIcon: true,
              closeIconColor: Colors.white,
            ),
          );
        }
      } else if (result == 'temp') {
        await _offlineItemsRepository.markOffline(
          currentContent,
          temporary: true,
          tempHours: _tempHideHours,
        );
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                '${currentContent.name} marked offline for $_tempHideHours hours',
              ),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange.shade700,
              showCloseIcon: true,
              closeIconColor: Colors.white,
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () async {
                  await _offlineItemsRepository.markOnline(currentContent);
                  if (mounted) {
                    setState(() {
                      _isOffline = false;
                    });
                  }
                },
              ),
            ),
          );
        }
      } else if (result == 'permanent') {
        await _offlineItemsRepository.markOffline(
          currentContent,
          temporary: false,
        );
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('${currentContent.name} marked offline permanently'),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade700,
              showCloseIcon: true,
              closeIconColor: Colors.white,
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () async {
                  await _offlineItemsRepository.markOnline(currentContent);
                  if (mounted) {
                    setState(() {
                      _isOffline = false;
                    });
                  }
                },
              ),
            ),
          );
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
      tooltip: _isOffline ? 'Mark channel online' : 'Mark channel offline',
      icon: Icon(
        _isOffline ? Icons.signal_wifi_off : Icons.signal_wifi_4_bar_outlined,
        color: _isOffline ? Colors.grey : Colors.white,
      ),
      onPressed: _showOfflineMenu,
    );
  }
}
