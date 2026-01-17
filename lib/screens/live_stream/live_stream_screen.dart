import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import '../../../models/content_type.dart';
import '../../../services/event_bus.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/player_widget.dart';

class LiveStreamScreen extends StatefulWidget {
  final ContentItem content;

  const LiveStreamScreen({super.key, required this.content});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late ContentItem contentItem;
  List<ContentItem> allContents = [];
  bool allContentsLoaded = false;
  int selectedContentItemIndex = 0;
  late StreamSubscription contentItemIndexChangedSubscription;

  @override
  void initState() {
    super.initState();
    contentItem = widget.content;
    _hideSystemUI();
    _initializeQueue();
  }

  Future<void> _initializeQueue() async {
    // Determine content type from sourceType or fallback to current playlist
    final bool contentIsXtream;
    final bool contentIsM3u;
    final String? sourcePlaylistId = widget.content.sourcePlaylistId;

    if (widget.content.sourceType != null) {
      contentIsXtream = widget.content.sourceType == PlaylistType.xtream;
      contentIsM3u = widget.content.sourceType == PlaylistType.m3u;
    } else if (AppState.currentPlaylist != null) {
      contentIsXtream = AppState.currentPlaylist!.type == PlaylistType.xtream;
      contentIsM3u = AppState.currentPlaylist!.type == PlaylistType.m3u;
    } else {
      contentIsXtream = widget.content.liveStream != null;
      contentIsM3u = widget.content.m3uItem != null;
    }

    if (contentIsXtream) {
      // Get the correct repository for this playlist
      final repository = sourcePlaylistId != null
          ? AppState.xtreamRepositories[sourcePlaylistId] ?? AppState.xtreamCodeRepository
          : AppState.xtreamCodeRepository;

      if (repository != null && widget.content.liveStream != null) {
        final channels = await repository.getLiveChannelsByCategoryId(
          categoryId: widget.content.liveStream!.categoryId,
        );
        if (channels != null) {
          allContents = channels.map((x) {
            return ContentItem(
              x.streamId,
              x.name,
              x.streamIcon,
              ContentType.liveStream,
              liveStream: x,
              sourcePlaylistId: sourcePlaylistId,
              sourceType: PlaylistType.xtream,
            );
          }).toList();
        }
      }
    } else if (contentIsM3u) {
      // Get the correct repository for this playlist
      final repository = sourcePlaylistId != null
          ? AppState.m3uRepositories[sourcePlaylistId] ?? AppState.m3uRepository
          : AppState.m3uRepository;

      if (repository != null && widget.content.m3uItem != null) {
        final items = await repository.getM3uItemsByCategoryId(
          categoryId: widget.content.m3uItem!.categoryId!,
        );
        if (items != null) {
          allContents = items.map((x) {
            return ContentItem(
              x.url,
              x.name ?? 'NO NAME',
              x.tvgLogo ?? '',
              ContentType.liveStream,
              m3uItem: x,
              sourcePlaylistId: sourcePlaylistId,
              sourceType: PlaylistType.m3u,
            );
          }).toList();
        }
      }
    }

    if (!mounted) return;
    setState(() {
      selectedContentItemIndex = allContents.indexWhere(
        (element) => element.id == widget.content.id,
      );
      allContentsLoaded = true;
    });

    contentItemIndexChangedSubscription = EventBus()
        .on<int>('player_content_item_index')
        .listen((int index) {
          if (!mounted) return;

          setState(() {
            selectedContentItemIndex = index;
            contentItem = allContents[selectedContentItemIndex];
          });
        });
  }

  @override
  void dispose() {
    contentItemIndexChangedSubscription.cancel();
    _showSystemUI();
    super.dispose();
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!allContentsLoaded) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: buildFullScreenLoadingWidget()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox.expand(
          child: PlayerWidget(contentItem: widget.content, queue: allContents),
        ),
      ),
    );
  }

}
