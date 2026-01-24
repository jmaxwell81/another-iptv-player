import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/fullscreen_service.dart';

/// Fullscreen toggle button for desktop platforms (macOS, Windows, Linux)
class VideoFullscreenWidget extends StatefulWidget {
  const VideoFullscreenWidget({super.key});

  @override
  State<VideoFullscreenWidget> createState() => _VideoFullscreenWidgetState();
}

class _VideoFullscreenWidgetState extends State<VideoFullscreenWidget> {
  final FullscreenService _fullscreenService = FullscreenService();

  @override
  void initState() {
    super.initState();
    _fullscreenService.addListener(_onFullscreenChanged);
    _fullscreenService.initialize();
  }

  @override
  void dispose() {
    _fullscreenService.removeListener(_onFullscreenChanged);
    super.dispose();
  }

  void _onFullscreenChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Only show on supported desktop platforms
    if (!_fullscreenService.isSupported) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: Icon(
        _fullscreenService.isFullscreen
            ? Icons.fullscreen_exit
            : Icons.fullscreen,
      ),
      tooltip: _fullscreenService.isFullscreen
          ? 'Exit Fullscreen (F)'
          : 'Fullscreen (F)',
      onPressed: () => _fullscreenService.toggle(),
    );
  }
}
