import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/screens/m3u/m3u_home_screen.dart';
import 'package:another_iptv_player/screens/playlist_screen.dart';
import 'package:another_iptv_player/screens/unified/unified_home_screen.dart';
import 'package:another_iptv_player/services/active_playlists_service.dart';
import 'package:flutter/material.dart';
import '../../repositories/user_preferences.dart';
import '../../services/app_state.dart';
import '../../services/playlist_service.dart';
import 'xtream-codes/xtream_code_home_screen.dart';

class AppInitializerScreen extends StatefulWidget {
  const AppInitializerScreen({super.key});

  @override
  State<AppInitializerScreen> createState() => _AppInitializerScreenState();
}

class _AppInitializerScreenState extends State<AppInitializerScreen> {
  bool _isLoading = true;
  Playlist? _lastPlaylist;
  bool _isCombinedMode = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check for combined mode first
    final activePlaylistsService = ActivePlaylistsService();
    await activePlaylistsService.loadConfiguration();

    if (activePlaylistsService.isCombinedMode && activePlaylistsService.activeCount >= 2) {
      // Restore combined mode
      await _restoreCombinedMode(activePlaylistsService);
      setState(() {
        _isCombinedMode = true;
        _isLoading = false;
      });
      return;
    }

    // Fall back to single playlist mode
    await _loadLastPlaylist();
  }

  Future<void> _restoreCombinedMode(ActivePlaylistsService service) async {
    // Clear existing state
    AppState.clearActivePlaylists();

    // Load and register all active playlists
    for (final playlistId in service.activePlaylistIds) {
      final playlist = await PlaylistService.getPlaylistById(playlistId);
      if (playlist == null) continue;

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
  }

  Future<void> _loadLastPlaylist() async {
    final lastPlaylistId = await UserPreferences.getLastPlaylist();

    if (lastPlaylistId != null) {
      final playlist = await PlaylistService.getPlaylistById(lastPlaylistId);
      if (playlist != null) {
        AppState.currentPlaylist = playlist;
        _lastPlaylist = playlist;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Combined mode takes priority
    if (_isCombinedMode) {
      return const UnifiedHomeScreen();
    }

    if (_lastPlaylist == null) {
      return const PlaylistScreen();
    } else {
      switch (_lastPlaylist!.type) {
        case PlaylistType.xtream:
          return XtreamCodeHomeScreen(playlist: _lastPlaylist!);
        case PlaylistType.m3u:
          return M3UHomeScreen(playlist: _lastPlaylist!);
      }
    }
  }
}
