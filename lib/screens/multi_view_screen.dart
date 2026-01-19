import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/utils/build_media_url.dart';

class MultiViewScreen extends StatefulWidget {
  final List<ContentItem> initialItems;
  final int gridSize; // 2 or 4

  const MultiViewScreen({
    super.key,
    required this.initialItems,
    this.gridSize = 2,
  });

  @override
  State<MultiViewScreen> createState() => _MultiViewScreenState();
}

class _MultiViewScreenState extends State<MultiViewScreen> {
  late List<Player> _players;
  late List<VideoController> _controllers;
  late List<ContentItem?> _items;
  int? _focusedIndex;
  bool _showControls = true;
  int _gridSize = 2;

  @override
  void initState() {
    super.initState();
    _gridSize = widget.gridSize.clamp(2, 4);
    _initializePlayers();

    // Enter fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _initializePlayers() {
    _players = List.generate(_gridSize, (_) => Player());
    _controllers = _players.map((p) => VideoController(p)).toList();
    _items = List.filled(_gridSize, null);

    // Load initial items
    for (var i = 0; i < widget.initialItems.length && i < _gridSize; i++) {
      _loadContent(i, widget.initialItems[i]);
    }
  }

  void _loadContent(int index, ContentItem item) {
    if (index < 0 || index >= _gridSize) return;

    final url = _getStreamUrl(item);
    if (url != null) {
      _items[index] = item;
      _players[index].open(Media(url));
      setState(() {});
    }
  }

  String? _getStreamUrl(ContentItem item) {
    // Use the buildMediaUrl utility which handles both Xtream and M3U
    final url = buildMediaUrl(item);
    if (url.startsWith('error://')) {
      return null;
    }
    return url;
  }

  void _removeContent(int index) {
    if (index < 0 || index >= _gridSize) return;

    _players[index].stop();
    _items[index] = null;
    setState(() {});
  }

  void _swapContent(int from, int to) {
    if (from < 0 || from >= _gridSize || to < 0 || to >= _gridSize) return;
    if (from == to) return;

    final tempItem = _items[from];
    final tempPosition = _players[from].state.position;

    _items[from] = _items[to];
    _items[to] = tempItem;

    // Reload both players
    if (_items[from] != null) {
      final url = _getStreamUrl(_items[from]!);
      if (url != null) {
        _players[from].open(Media(url));
      }
    } else {
      _players[from].stop();
    }

    if (_items[to] != null) {
      final url = _getStreamUrl(_items[to]!);
      if (url != null) {
        _players[to].open(Media(url));
      }
    } else {
      _players[to].stop();
    }

    setState(() {});
  }

  void _setGridSize(int size) {
    if (size == _gridSize) return;

    // Stop players that will be removed
    for (var i = size; i < _gridSize; i++) {
      _players[i].stop();
      _players[i].dispose();
    }

    // Save current items
    final currentItems = _items.take(size.clamp(0, _items.length)).toList();

    // Reinitialize with new size
    _gridSize = size;
    _players = List.generate(_gridSize, (i) {
      if (i < currentItems.length) {
        return Player()..open(Media(_getStreamUrl(currentItems[i]!)!));
      }
      return Player();
    });
    _controllers = _players.map((p) => VideoController(p)).toList();
    _items = List.generate(_gridSize, (i) {
      if (i < currentItems.length) return currentItems[i];
      return null;
    });

    setState(() {});
  }

  void _toggleFullscreenOnView(int index) {
    if (_focusedIndex == index) {
      _focusedIndex = null;
    } else {
      _focusedIndex = index;
    }
    setState(() {});
  }

  void _muteAllExcept(int index) {
    for (var i = 0; i < _players.length; i++) {
      _players[i].setVolume(i == index ? 100 : 0);
    }
    setState(() {});
  }

  void _unmuteAll() {
    for (final player in _players) {
      player.setVolume(100);
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final player in _players) {
      player.dispose();
    }

    // Exit fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          children: [
            // Video grid
            _buildVideoGrid(),
            // Controls overlay
            if (_showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (_focusedIndex != null) {
      // Show only focused view
      return _buildVideoView(_focusedIndex!);
    }

    final crossAxisCount = _gridSize == 2 ? 2 : 2;
    final mainAxisCount = _gridSize == 2 ? 1 : 2;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: MediaQuery.of(context).size.width /
            MediaQuery.of(context).size.height *
            mainAxisCount /
            crossAxisCount,
      ),
      itemCount: _gridSize,
      itemBuilder: (context, index) => _buildVideoView(index),
    );
  }

  Widget _buildVideoView(int index) {
    final item = _items[index];

    return GestureDetector(
      onDoubleTap: () => _toggleFullscreenOnView(index),
      onLongPress: () => _muteAllExcept(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _focusedIndex == index
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade800,
            width: 1,
          ),
        ),
        child: item == null
            ? _buildEmptySlot(index)
            : Stack(
                children: [
                  Video(
                    controller: _controllers[index],
                    fill: Colors.black,
                  ),
                  // Channel info overlay
                  if (_showControls)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // View controls
                  if (_showControls)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                            onPressed: () => _toggleFullscreenOnView(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => _removeContent(index),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptySlot(int index) {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to add channel',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(180),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              // Grid size selector
              PopupMenuButton<int>(
                icon: const Icon(Icons.grid_view, color: Colors.white),
                onSelected: _setGridSize,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 2, child: Text('2 Screens')),
                  const PopupMenuItem(value: 4, child: Text('4 Screens')),
                ],
              ),
              // Unmute all
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.white),
                onPressed: _unmuteAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
