import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/playlist_controller.dart';
import '../../models/playlist_model.dart';
import '../../widgets/playlist_card.dart';
import '../../widgets/playlist_states.dart';
import 'playlist_type_screen.dart';
import 'xtream-codes/new_xtream_code_playlist_screen.dart';
import 'xtream-codes/xtream_code_data_loader_screen.dart';
import 'm3u/new_m3u_playlist_screen.dart';
import 'm3u/m3u_data_loader_screen.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  PlaylistScreenState createState() => PlaylistScreenState();
}

class PlaylistScreenState extends State<PlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlaylistController(),
      child: _PlaylistScreenBody(),
    );
  }
}

class _PlaylistScreenBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlaylistsIfNeeded(context);
    });

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<PlaylistController>(
        builder: (context, controller, child) =>
            _buildBodyFromState(context, controller),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  void _initializePlaylistsIfNeeded(BuildContext context) {
    final controller = context.read<PlaylistController>();
    if (!controller.isLoading &&
        controller.playlists.isEmpty &&
        controller.error == null) {
      controller.loadPlaylists(context);
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        context.loc.my_playlists,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        Consumer<PlaylistController>(
          builder: (context, controller, child) {
            if (controller.playlists.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Refresh All',
              onPressed: () => _showRefreshAllDialog(context, controller),
            );
          },
        ),
      ],
    );
  }

  void _showRefreshAllDialog(BuildContext context, PlaylistController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refresh All Playlists'),
        content: Text(
          'This will refresh all ${controller.playlists.length} playlist(s) one by one. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _refreshAllPlaylists(context, controller);
            },
            child: const Text('Refresh All'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAllPlaylists(BuildContext context, PlaylistController controller) async {
    // Get all playlists and refresh them sequentially
    final playlists = controller.playlists.toList();

    for (int i = 0; i < playlists.length; i++) {
      final playlist = playlists[i];

      if (!context.mounted) return;

      // Show progress snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refreshing ${playlist.name} (${i + 1}/${playlists.length})...'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to the data loader screen for this playlist
      AppState.currentPlaylist = playlist;

      if (playlist.type == PlaylistType.xtream) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => XtreamCodeDataLoaderScreen(
              playlist: playlist,
              refreshAll: true,
              returnToPlaylistScreen: true,
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => M3UDataLoaderScreen(
              playlist: playlist,
              refreshAll: true,
              returnToPlaylistScreen: true,
            ),
          ),
        );
      }

    }

    if (context.mounted) {
      controller.loadPlaylists(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All playlists refreshed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildBodyFromState(
    BuildContext context,
    PlaylistController controller,
  ) {
    if (controller.isLoading) {
      return const PlaylistLoadingState();
    }

    if (controller.error != null) {
      return PlaylistErrorState(
        error: controller.error!,
        onRetry: () => controller.loadPlaylists(context),
      );
    }

    if (controller.playlists.isEmpty) {
      return PlaylistEmptyState(
        onCreatePlaylist: () => _navigateToCreatePlaylist(context),
      );
    }

    return _buildPlaylistList(context, controller);
  }

  Widget _buildPlaylistList(
    BuildContext context,
    PlaylistController controller,
  ) {
    return RefreshIndicator(
      onRefresh: () => controller.loadPlaylists(context),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.playlists.length,
        itemBuilder: (context, index) {
          final playlist = controller.playlists[index];
          return PlaylistCard(
            playlist: playlist,
            onTap: () => controller.openPlaylist(context, playlist),
            onDelete: () => _showDeleteDialog(context, controller, playlist),
            onEdit: () => _navigateToEditPlaylist(context, controller, playlist),
            onRefresh: () => _refreshPlaylist(context, controller, playlist),
          );
        },
      ),
    );
  }

  Future<void> _refreshPlaylist(
    BuildContext context,
    PlaylistController controller,
    Playlist playlist,
  ) async {
    AppState.currentPlaylist = playlist;

    if (playlist.type == PlaylistType.xtream) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => XtreamCodeDataLoaderScreen(
            playlist: playlist,
            refreshAll: true,
            returnToPlaylistScreen: true,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => M3UDataLoaderScreen(
            playlist: playlist,
            refreshAll: true,
            returnToPlaylistScreen: true,
          ),
        ),
      );
    }

    // Reload the playlist list to update the last refresh time display
    if (context.mounted) {
      controller.loadPlaylists(context);
    }
  }

  Future<void> _navigateToEditPlaylist(
    BuildContext context,
    PlaylistController controller,
    Playlist playlist,
  ) async {
    Widget editScreen;
    if (playlist.type == PlaylistType.xtream) {
      editScreen = NewXtreamCodePlaylistScreen(editPlaylist: playlist);
    } else {
      editScreen = NewM3uPlaylistScreen(editPlaylist: playlist);
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => editScreen),
    );

    // Refresh the playlist list if edit was successful
    if (result == true && context.mounted) {
      controller.loadPlaylists(context);
    }
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _navigateToCreatePlaylist(context),
      tooltip: context.loc.create_new_playlist,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _navigateToCreatePlaylist(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlaylistTypeScreen()),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    PlaylistController controller,
    Playlist playlist,
  ) {
    showDialog(
      context: context,
      builder: (context) => _DeletePlaylistDialog(
        playlist: playlist,
        onDelete: () async {
          final success = await controller.deletePlaylist(playlist.id);
          if (success && context.mounted) {
            _showSuccessSnackBar(context, playlist.name);
          }
        },
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String playlistName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.loc.playlist_deleted(playlistName)),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _DeletePlaylistDialog extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onDelete;

  const _DeletePlaylistDialog({required this.playlist, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.loc.playlist_delete_confirmation_title),
      content: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              text: context.loc.playlist_delete_confirmation_message(
                playlist.name,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(context.loc.delete),
        ),
      ],
    );
  }
}
