import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/playlist_controller.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/active_playlists_service.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/screens/unified/unified_home_screen.dart';
import 'package:another_iptv_player/screens/playlist_screen.dart';

/// Screen for managing which playlists are active in combined mode
class ActiveSourcesScreen extends StatefulWidget {
  const ActiveSourcesScreen({super.key});

  @override
  State<ActiveSourcesScreen> createState() => _ActiveSourcesScreenState();
}

class _ActiveSourcesScreenState extends State<ActiveSourcesScreen> {
  final ActivePlaylistsService _service = ActivePlaylistsService();
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _service.loadConfiguration();
      if (!mounted) return;
      final playlistController = Provider.of<PlaylistController>(context, listen: false);
      await playlistController.loadPlaylists(context);
      if (!mounted) return;
      _playlists = playlistController.playlists;
    } catch (e) {
      debugPrint('ActiveSourcesScreen: Error loading data: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _togglePlaylist(Playlist playlist) async {
    await _service.togglePlaylistActive(playlist.id);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCombinedMode(bool enabled) async {
    await _service.setCombinedMode(enabled);
    if (mounted) setState(() {});
  }

  Future<void> _activateCombinedMode() async {
    if (_service.activeCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 playlists to use combined mode')),
      );
      return;
    }

    setState(() => _isActivating = true);

    try {
      // Clear existing state
      AppState.clearActivePlaylists();

      // Register all active playlists in order (first = highest priority)
      for (final playlistId in _service.orderedActivePlaylistIds) {
        final playlist = _playlists.firstWhere(
          (p) => p.id == playlistId,
          orElse: () => throw Exception('Playlist not found: $playlistId'),
        );

        if (playlist.type == PlaylistType.xtream) {
          final repository = IptvRepository(
            ApiConfig(
              baseUrl: playlist.url!,
              username: playlist.username!,
              password: playlist.password!,
            ),
            playlist.id,
          );
          AppState.registerPlaylist(playlist, xtreamRepo: repository);
        } else {
          final repository = M3uRepository(playlistId: playlist.id);
          AppState.registerPlaylist(playlist, m3uRepo: repository);
        }
      }

      AppState.isCombinedMode = true;
      await _service.setCombinedMode(true);

      // Navigate to unified home screen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UnifiedHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('ActiveSourcesScreen: Error activating combined mode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  Future<void> _exitCombinedMode() async {
    AppState.clearActivePlaylists();
    await _service.setCombinedMode(false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => PlaylistScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Combined Sources')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combined Sources'),
        actions: [
          if (AppState.isCombinedMode)
            TextButton.icon(
              onPressed: _exitCombinedMode,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Exit Combined Mode'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Combined mode status card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppState.isCombinedMode ? Icons.check_circle : Icons.info_outline,
                        color: AppState.isCombinedMode ? Colors.green : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppState.isCombinedMode
                              ? 'Combined mode is active'
                              : 'Select playlists to combine',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppState.isCombinedMode
                        ? '${AppState.activePlaylists.length} playlists are being combined. Categories with the same name will be merged.'
                        : 'Select at least 2 playlists below, then tap "Activate Combined Mode" to merge their content.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_service.activeCount >= 2 && !AppState.isCombinedMode) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isActivating ? null : _activateCombinedMode,
                        icon: _isActivating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.merge),
                        label: Text(_isActivating ? 'Activating...' : 'Activate Combined Mode'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Active sources (reorderable) section
          if (_service.activeCount > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Active Sources (drag to reorder)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    'First = highest priority',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: (_service.activeCount * 72.0).clamp(72.0, 216.0),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _service.orderedActivePlaylistIds.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final playlistId = _service.orderedActivePlaylistIds[index];
                  final playlist = _playlists.firstWhere(
                    (p) => p.id == playlistId,
                    orElse: () => Playlist(id: playlistId, name: 'Unknown', type: PlaylistType.xtream, createdAt: DateTime.now()),
                  );

                  return Card(
                    key: ValueKey(playlistId),
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            playlist.type == PlaylistType.xtream
                                ? Icons.cloud
                                : Icons.file_present,
                            color: playlist.type == PlaylistType.xtream
                                ? Colors.blue
                                : Colors.green,
                            size: 20,
                          ),
                        ],
                      ),
                      title: Text(playlist.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!AppState.isCombinedMode)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _togglePlaylist(playlist),
                              tooltip: 'Remove from combined',
                            ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 32),
          ],

          // Available playlists header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Available Playlists',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${_service.activeCount} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Playlist list (all playlists)
          Expanded(
            child: _playlists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        const Text('No playlists available'),
                        const SizedBox(height: 8),
                        const Text('Add playlists first to use combined mode'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      final isActive = _service.isPlaylistActive(playlist.id);
                      final isCurrentlyActive = AppState.activePlaylists.containsKey(playlist.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isActive
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            playlist.type == PlaylistType.xtream
                                ? Icons.cloud
                                : Icons.file_present,
                            color: playlist.type == PlaylistType.xtream
                                ? Colors.blue
                                : Colors.green,
                          ),
                          title: Text(playlist.name),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: playlist.type == PlaylistType.xtream
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  playlist.type == PlaylistType.xtream ? 'Xtream' : 'M3U',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: playlist.type == PlaylistType.xtream
                                        ? Colors.blue
                                        : Colors.green,
                                  ),
                                ),
                              ),
                              if (isCurrentlyActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(fontSize: 10, color: Colors.green),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Switch(
                            value: isActive,
                            onChanged: AppState.isCombinedMode
                                ? null // Disable switching when combined mode is active
                                : (_) => _togglePlaylist(playlist),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    await _service.reorderPlaylist(oldIndex, newIndex);
    if (mounted) setState(() {});
  }
}
