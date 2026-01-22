import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/pip_manager.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/widgets/player_widget.dart';

/// Picture-in-Picture overlay widget that appears in the bottom right corner
class PipOverlayWidget extends StatefulWidget {
  /// The screen identifier to check if PiP should be shown
  final String currentScreen;

  const PipOverlayWidget({
    super.key,
    required this.currentScreen,
  });

  @override
  State<PipOverlayWidget> createState() => _PipOverlayWidgetState();
}

class _PipOverlayWidgetState extends State<PipOverlayWidget>
    with SingleTickerProviderStateMixin {
  final PipManager _pipManager = PipManager();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  Key? _playerKey;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pipManager.addListener(_onPipStateChanged);
    _updatePlayerKey();
  }

  @override
  void dispose() {
    _pipManager.removeListener(_onPipStateChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onPipStateChanged() {
    if (!mounted) return;

    if (_pipManager.shouldShowPip(widget.currentScreen)) {
      _animationController.forward();
      _updatePlayerKey();
    } else {
      _animationController.reverse();
    }
    setState(() {});
  }

  void _updatePlayerKey() {
    if (_pipManager.currentItem != null) {
      _playerKey = ValueKey('pip_${_pipManager.currentItem!.id}_${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  void _closePip() {
    _pipManager.stopPip();
  }

  void _expandToFullScreen(BuildContext context) {
    if (_pipManager.currentItem == null) return;

    final item = _pipManager.currentItem!;
    _pipManager.stopPip();
    navigateByContentType(context, item);
  }

  @override
  Widget build(BuildContext context) {
    if (!_pipManager.shouldShowPip(widget.currentScreen) || _pipManager.currentItem == null) {
      return const SizedBox.shrink();
    }

    const double pipWidth = 280;
    const double pipHeight = 157.5; // 16:9 ratio

    return Positioned(
      bottom: 24,
      right: 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: pipWidth,
            height: pipHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Video player
                if (_playerKey != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: PlayerWidget(
                      key: _playerKey,
                      contentItem: _pipManager.currentItem!,
                      showControls: false,
                      showInfo: false,
                    ),
                  ),
                // Gradient overlay for controls
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4],
                      ),
                    ),
                  ),
                ),
                // Channel name
                Positioned(
                  left: 8,
                  top: 8,
                  right: 40,
                  child: Text(
                    _pipManager.currentItem!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Live indicator
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    onPressed: _closePip,
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                // Expand button (tap on video area)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _expandToFullScreen(context),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
