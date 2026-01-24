import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/services/app_state.dart';
import '../../widgets/playlist_info_widget.dart';
import '../../widgets/playlist_refresh_widget.dart';
import '../settings/general_settings_section.dart';
import 'm3u_data_loader_screen.dart';

class M3uPlaylistSettingsScreen extends StatefulWidget {
  final Playlist playlist;

  const M3uPlaylistSettingsScreen({super.key, required this.playlist});

  @override
  State<M3uPlaylistSettingsScreen> createState() =>
      _M3uPlaylistSettingsScreenState();
}

class _M3uPlaylistSettingsScreenState extends State<M3uPlaylistSettingsScreen> {
  void _onRefreshPressed() {
    // Navigate to data loader screen with refresh flag
    // Pass existing m3uItems from AppState if available
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => M3UDataLoaderScreen(
          playlist: widget.playlist,
          m3uItems: AppState.m3uItems ?? [],
          refreshAll: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SelectableText(
          context.loc.settings,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        children: [
          PlaylistRefreshWidget(
            playlist: widget.playlist,
            onRefreshPressed: _onRefreshPressed,
          ),
          const SizedBox(height: 12),
          const GeneralSettingsWidget(),
          const SizedBox(height: 16),
          PlaylistInfoWidget(playlist: widget.playlist),
        ],
      ),
    );
  }
}
