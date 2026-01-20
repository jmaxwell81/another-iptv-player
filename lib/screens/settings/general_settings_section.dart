import 'dart:io';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/screens/settings/subtitle_settings_section.dart';
import 'package:another_iptv_player/services/failed_domain_cache.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/services/timeshift_service.dart';
import 'package:another_iptv_player/services/vpn_detection_service.dart';
import 'package:another_iptv_player/services/opensubtitles_service.dart';
import 'package:another_iptv_player/services/tmdb_service.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:another_iptv_player/utils/show_loading_dialog.dart';
import 'package:another_iptv_player/widgets/vpn_status_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/locale_provider.dart';
import '../../controllers/unified_home_controller.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/theme_provider.dart';
import '../../l10n/supported_languages.dart';
import '../../models/m3u_item.dart';
import '../../repositories/user_preferences.dart';
import '../../services/app_state.dart';
import '../../services/m3u_parser.dart';
import '../../widgets/dropdown_tile_widget.dart';
import '../../widgets/section_title_widget.dart';
import '../m3u/m3u_data_loader_screen.dart';
import '../playlist_screen.dart';
import '../xtream-codes/xtream_code_data_loader_screen.dart';
import 'category_settings_section.dart';
import 'renaming_rules_screen.dart';
import 'category_config_screen.dart';
import 'active_sources_screen.dart';
import 'unified_category_settings_screen.dart';

final controller = XtreamCodeHomeController(true);

class GeneralSettingsWidget extends StatefulWidget {
  const GeneralSettingsWidget({super.key});

  @override
  State<GeneralSettingsWidget> createState() => _GeneralSettingsWidgetState();
}

class _GeneralSettingsWidgetState extends State<GeneralSettingsWidget> {
  final AppDatabase database = getIt<AppDatabase>();

  bool _backgroundPlayEnabled = false;
  bool _isLoading = true;
  String? _selectedFilePath;
  String _selectedTheme = 'system';
  bool _brightnessGesture = false;
  bool _volumeGesture = false;
  bool _seekGesture = false;
  bool _speedUpOnLongPress = true;
  bool _seekOnDoubleTap = true;
  String _appVersion = '';

  // Source health settings
  int _sourceErrorThreshold = 3;
  int _sourceErrorWindowMinutes = 2;
  bool _showStreamErrors = true;

  // Timeshift settings
  bool _timeshiftEnabled = true;
  int _timeshiftMaxBuffer = 30;

  // Default panel setting
  String _defaultPanel = 'live';

  // VPN settings
  final VpnDetectionService _vpnService = VpnDetectionService();
  bool _vpnCheckEnabled = false;
  bool _vpnKillSwitchEnabled = false;
  int _vpnCheckIntervalMinutes = 5;
  VpnStatusPosition _vpnStatusPosition = VpnStatusPosition.bottomLeft;
  double _vpnStatusOpacity = 0.5;
  bool _vpnShowOnlyWhenDisconnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final backgroundPlay = await UserPreferences.getBackgroundPlay();
      final themeMode = await UserPreferences.getThemeMode();
      final brightnessGesture = await UserPreferences.getBrightnessGesture();
      final volumeGesture = await UserPreferences.getVolumeGesture();
      final seekGesture = await UserPreferences.getSeekGesture();
      final speedUpOnLongPress = await UserPreferences.getSpeedUpOnLongPress();
      final seekOnDoubleTap = await UserPreferences.getSeekOnDoubleTap();
      final packageInfo = await PackageInfo.fromPlatform();
      final sourceErrorThreshold = await UserPreferences.getSourceErrorThreshold();
      final sourceErrorWindowMinutes = await UserPreferences.getSourceErrorWindowMinutes();
      final showStreamErrors = await UserPreferences.getShowStreamErrors();
      // VPN settings
      final vpnCheckEnabled = await UserPreferences.getVpnCheckEnabled();
      final vpnKillSwitchEnabled = await UserPreferences.getVpnKillSwitchEnabled();
      final vpnCheckIntervalMinutes = await UserPreferences.getVpnCheckIntervalMinutes();
      final vpnStatusPosition = await UserPreferences.getVpnStatusPosition();
      final vpnStatusOpacity = await UserPreferences.getVpnStatusOpacity();
      final vpnShowOnlyWhenDisconnected = await UserPreferences.getVpnShowOnlyWhenDisconnected();
      final defaultPanel = await UserPreferences.getDefaultPanel();
      final timeshiftEnabled = await UserPreferences.getTimeshiftEnabled();
      final timeshiftMaxBuffer = await UserPreferences.getTimeshiftMaxBuffer();
      setState(() {
        _defaultPanel = defaultPanel;
        _timeshiftEnabled = timeshiftEnabled;
        _timeshiftMaxBuffer = timeshiftMaxBuffer;
        _backgroundPlayEnabled = backgroundPlay;
        _selectedTheme = _themeModeToString(themeMode);
        _brightnessGesture = brightnessGesture;
        _volumeGesture = volumeGesture;
        _seekGesture = seekGesture;
        _speedUpOnLongPress = speedUpOnLongPress;
        _seekOnDoubleTap = seekOnDoubleTap;
        _appVersion = packageInfo.version;
        _sourceErrorThreshold = sourceErrorThreshold;
        _sourceErrorWindowMinutes = sourceErrorWindowMinutes;
        _showStreamErrors = showStreamErrors;
        _vpnCheckEnabled = vpnCheckEnabled;
        _vpnKillSwitchEnabled = vpnKillSwitchEnabled;
        _vpnCheckIntervalMinutes = vpnCheckIntervalMinutes;
        _vpnStatusPosition = VpnStatusPosition.fromInt(vpnStatusPosition);
        _vpnStatusOpacity = vpnStatusOpacity;
        _vpnShowOnlyWhenDisconnected = vpnShowOnlyWhenDisconnected;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  ThemeMode _stringToThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _saveBackgroundPlaySetting(bool value) async {
    try {
      await UserPreferences.setBackgroundPlay(value);
      setState(() {
        _backgroundPlayEnabled = value;
      });
    } catch (e) {
      setState(() {
        _backgroundPlayEnabled = !value;
      });
    }
  }

  // Check if we have any Xtream playlists available (either current or in combined mode)
  bool get _hasXtreamPlaylists {
    if (AppState.isCombinedMode) {
      return AppState.xtreamRepositories.isNotEmpty;
    }
    return isXtreamCode;
  }

  // Check if we have any M3U playlists available
  bool get _hasM3uPlaylists {
    if (AppState.isCombinedMode) {
      return AppState.m3uRepositories.isNotEmpty;
    }
    return isM3u;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.home),
            title: Text(context.loc.playlist_list),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await UserPreferences.removeLastPlaylist();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PlaylistScreen()),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 10),
        SectionTitleWidget(title: context.loc.general_settings),
        Card(
          child: Column(
            children: [
              // Show refresh option - in single mode uses current playlist, in combined mode shows all
              if (AppState.currentPlaylist != null || AppState.isCombinedMode)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(context.loc.refresh_contents),
                  subtitle: AppState.isCombinedMode
                      ? Text('Refresh all ${AppState.activePlaylists.length} sources')
                      : null,
                  trailing: const Icon(Icons.cloud_download),
                  onTap: () {
                    if (AppState.isCombinedMode) {
                      // In combined mode, go back to playlist selection
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => PlaylistScreen()),
                      );
                    } else if (isXtreamCode) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => XtreamCodeDataLoaderScreen(
                            playlist: AppState.currentPlaylist!,
                            refreshAll: true,
                          ),
                        ),
                      );
                    } else if (isM3u) {
                      refreshM3uPlaylist();
                    }
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.find_replace),
                title: const Text('Renaming Rules'),
                subtitle: const Text('Find and replace text in names'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RenamingRulesScreen(),
                    ),
                  );
                },
              ),
              // Show category configuration for any playlist
              if (AppState.currentPlaylist != null || AppState.isCombinedMode)
                const Divider(height: 1),
              if (AppState.currentPlaylist != null || AppState.isCombinedMode)
                ListTile(
                  leading: const Icon(Icons.merge),
                  title: const Text('Category Configuration'),
                  subtitle: AppState.isCombinedMode
                      ? const Text('Select a playlist to configure')
                      : const Text('Merge and reorder categories'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (AppState.isCombinedMode) {
                      // In combined mode, show playlist selection dialog
                      _showPlaylistSelectionForCategoryConfig(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryConfigScreen(
                            playlistId: AppState.currentPlaylist!.id,
                          ),
                        ),
                      );
                    }
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.merge_type),
                title: const Text('Combined Sources'),
                subtitle: Text(AppState.isCombinedMode
                    ? 'Currently active (${AppState.activePlaylists.length} sources)'
                    : 'Merge multiple playlists together'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActiveSourcesScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              DropdownTileWidget<Locale>(
                icon: Icons.language,
                label: context.loc.app_language,
                value: Localizations.localeOf(context),
                items: [
                  ...supportedLanguages.map(
                        (language) => DropdownMenuItem(
                      value: Locale(language['code']),
                      child: Text(language['name']),
                    ),
                  ),
                ],
                onChanged: (v) {
                  Provider.of<LocaleProvider>(
                    context,
                    listen: false,
                  ).setLocale(v!);
                },
              ),
              const Divider(height: 1),
              DropdownTileWidget<String>(
                icon: Icons.color_lens_outlined,
                label: context.loc.theme,
                value: _selectedTheme,
                items: [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(context.loc.standard),
                  ),
                  DropdownMenuItem(
                    value: 'light',
                    child: Text(context.loc.light),
                  ),
                  DropdownMenuItem(
                    value: 'dark',
                    child: Text(context.loc.dark),
                  ),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    final themeMode = _stringToThemeMode(value);
                    await themeProvider.setTheme(themeMode);
                    setState(() {
                      _selectedTheme = value;
                    });
                  }
                },
              ),
              const Divider(height: 1),
              DropdownTileWidget<String>(
                icon: Icons.home_outlined,
                label: 'Default Panel',
                value: _defaultPanel,
                items: const [
                  DropdownMenuItem(
                    value: 'live',
                    child: Text('Live Streams'),
                  ),
                  DropdownMenuItem(
                    value: 'history',
                    child: Text('History'),
                  ),
                  DropdownMenuItem(
                    value: 'favorites',
                    child: Text('Favorites'),
                  ),
                  DropdownMenuItem(
                    value: 'guide',
                    child: Text('TV Guide'),
                  ),
                  DropdownMenuItem(
                    value: 'movies',
                    child: Text('Movies'),
                  ),
                  DropdownMenuItem(
                    value: 'series',
                    child: Text('Series'),
                  ),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await UserPreferences.setDefaultPanel(value);
                    setState(() {
                      _defaultPanel = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionTitleWidget(title: context.loc.player_settings),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.play_circle_outline),
                title: Text(context.loc.continue_on_background),
                subtitle: Text(
                    context.loc.continue_on_background_description),
                value: _backgroundPlayEnabled,
                onChanged: _saveBackgroundPlaySetting,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(context.loc.subtitle_settings),
                subtitle:
                Text(context.loc.subtitle_settings_description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const SubtitleSettingsScreen(),
                    ),
                  );
                },
              ),
              // Player gesture settings - Only show on mobile platforms (Android & iOS)
              if (Theme.of(context).platform == TargetPlatform.android ||
                  Theme.of(context).platform == TargetPlatform.iOS) ...[
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.brightness_6),
                  title: Text(context.loc.brightness_gesture),
                  subtitle: Text(context.loc.brightness_gesture_description),
                  value: _brightnessGesture,
                  onChanged: (value) async {
                    await UserPreferences.setBrightnessGesture(value);
                    setState(() {
                      _brightnessGesture = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up),
                  title: Text(context.loc.volume_gesture),
                  subtitle: Text(context.loc.volume_gesture_description),
                  value: _volumeGesture,
                  onChanged: (value) async {
                    await UserPreferences.setVolumeGesture(value);
                    setState(() {
                      _volumeGesture = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.swipe),
                  title: Text(context.loc.seek_gesture),
                  subtitle: Text(context.loc.seek_gesture_description),
                  value: _seekGesture,
                  onChanged: (value) async {
                    await UserPreferences.setSeekGesture(value);
                    setState(() {
                      _seekGesture = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fast_forward),
                  title: Text(context.loc.speed_up_on_long_press),
                  subtitle: Text(context.loc.speed_up_on_long_press_description),
                  value: _speedUpOnLongPress,
                  onChanged: (value) async {
                    await UserPreferences.setSpeedUpOnLongPress(value);
                    setState(() {
                      _speedUpOnLongPress = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.touch_app),
                  title: Text(context.loc.seek_on_double_tap),
                  subtitle: Text(context.loc.seek_on_double_tap_description),
                  value: _seekOnDoubleTap,
                  onChanged: (value) async {
                    await UserPreferences.setSeekOnDoubleTap(value);
                    setState(() {
                      _seekOnDoubleTap = value;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SectionTitleWidget(title: 'Timeshift'),
        Card(
          child: Column(
            children: [
              // Only show on desktop platforms (timeshift requires FFmpeg)
              if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) ...[
                ListenableBuilder(
                  listenable: TimeshiftService(),
                  builder: (context, _) {
                    final service = TimeshiftService();
                    return ListTile(
                      leading: Icon(
                        service.isFfmpegAvailable ? Icons.check_circle : Icons.error_outline,
                        color: service.isFfmpegAvailable ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        service.isFfmpegAvailable
                            ? 'FFmpeg Available'
                            : _getFfmpegStatusText(service.ffmpegStatus),
                      ),
                      subtitle: Text(
                        service.isFfmpegAvailable
                            ? 'Path: ${service.ffmpegPath ?? "default"}'
                            : service.ffmpegError ?? 'Required for timeshift recording',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Re-check FFmpeg',
                            onPressed: () async {
                              await service.checkFfmpegAvailability();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.help_outline),
                            tooltip: 'Installation Instructions',
                            onPressed: () => _showFfmpegInstallDialog(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Custom FFmpeg Path'),
                  subtitle: FutureBuilder<String?>(
                    future: UserPreferences.getCustomFfmpegPath(),
                    builder: (context, snapshot) {
                      return Text(snapshot.data ?? 'Use system default');
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showFfmpegPathDialog(context),
                  ),
                ),
                const Divider(height: 1),
              ],
              SwitchListTile(
                secondary: const Icon(Icons.pause_circle_outline),
                title: const Text('Enable Timeshift'),
                subtitle: Text(
                  Platform.isAndroid || Platform.isIOS
                      ? 'Not available on mobile platforms'
                      : 'Pause and rewind live TV streams',
                ),
                value: _timeshiftEnabled,
                onChanged: (Platform.isAndroid || Platform.isIOS)
                    ? null
                    : (value) async {
                        await UserPreferences.setTimeshiftEnabled(value);
                        setState(() {
                          _timeshiftEnabled = value;
                        });
                      },
              ),
              if (_timeshiftEnabled && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Max Buffer Duration'),
                  subtitle: Text('Keep up to $_timeshiftMaxBuffer minutes'),
                  trailing: DropdownButton<int>(
                    value: _timeshiftMaxBuffer,
                    underline: const SizedBox(),
                    items: [15, 30, 45, 60].map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value min'),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        await UserPreferences.setTimeshiftMaxBuffer(value);
                        setState(() {
                          _timeshiftMaxBuffer = value;
                        });
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Recordings Location'),
                  subtitle: FutureBuilder<Directory>(
                    future: getApplicationDocumentsDirectory(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final path = '${snapshot.data!.path}/timeshift_recordings';
                        return Text(
                          path,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return const Text('Loading...');
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Open Folder',
                    onPressed: () async {
                      final docsDir = await getApplicationDocumentsDirectory();
                      final recordingsDir = Directory('${docsDir.path}/timeshift_recordings');
                      if (!await recordingsDir.exists()) {
                        await recordingsDir.create(recursive: true);
                      }
                      // Open the folder in system file browser
                      if (Platform.isMacOS) {
                        Process.run('open', [recordingsDir.path]);
                      } else if (Platform.isWindows) {
                        Process.run('explorer', [recordingsDir.path]);
                      } else if (Platform.isLinux) {
                        Process.run('xdg-open', [recordingsDir.path]);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SectionTitleWidget(title: 'Source Health Monitoring'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.error_outline),
                title: const Text('Show Stream Errors'),
                subtitle: const Text('Display error messages when streams fail'),
                value: _showStreamErrors,
                onChanged: (value) async {
                  await UserPreferences.setShowStreamErrors(value);
                  setState(() {
                    _showStreamErrors = value;
                  });
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('Error Threshold'),
                subtitle: Text('Mark source as down after $_sourceErrorThreshold errors'),
                trailing: DropdownButton<int>(
                  value: _sourceErrorThreshold,
                  underline: const SizedBox(),
                  items: [2, 3, 5, 10].map((value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value'),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      await UserPreferences.setSourceErrorThreshold(value);
                      setState(() {
                        _sourceErrorThreshold = value;
                      });
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Error Window'),
                subtitle: Text('Count errors within $_sourceErrorWindowMinutes minutes'),
                trailing: DropdownButton<int>(
                  value: _sourceErrorWindowMinutes,
                  underline: const SizedBox(),
                  items: [1, 2, 5, 10].map((value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value min'),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      await UserPreferences.setSourceErrorWindowMinutes(value);
                      setState(() {
                        _sourceErrorWindowMinutes = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SectionTitleWidget(title: 'VPN Protection'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.vpn_lock),
                title: const Text('Enable VPN Check'),
                subtitle: const Text('Monitor VPN connection status'),
                value: _vpnCheckEnabled,
                onChanged: (value) async {
                  await _vpnService.setVpnCheckEnabled(value);
                  setState(() {
                    _vpnCheckEnabled = value;
                  });
                  if (value) {
                    _vpnService.forceCheck();
                  }
                },
              ),
              if (_vpnCheckEnabled) ...[
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.security,
                    color: _vpnKillSwitchEnabled ? Colors.red : null,
                  ),
                  title: const Text('Kill Switch'),
                  subtitle: const Text('Block playback if VPN disconnects'),
                  value: _vpnKillSwitchEnabled,
                  onChanged: (value) async {
                    await _vpnService.setKillSwitchEnabled(value);
                    setState(() {
                      _vpnKillSwitchEnabled = value;
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Check Interval'),
                  subtitle: Text('Check every $_vpnCheckIntervalMinutes minutes'),
                  trailing: DropdownButton<int>(
                    value: _vpnCheckIntervalMinutes,
                    underline: const SizedBox(),
                    items: [1, 2, 5, 10, 15, 30].map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value min'),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        await _vpnService.setCheckInterval(value);
                        setState(() {
                          _vpnCheckIntervalMinutes = value;
                        });
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Status Position'),
                  subtitle: Text(_vpnStatusPosition.displayName),
                  trailing: DropdownButton<VpnStatusPosition>(
                    value: _vpnStatusPosition,
                    underline: const SizedBox(),
                    items: VpnStatusPosition.values.map((pos) {
                      return DropdownMenuItem<VpnStatusPosition>(
                        value: pos,
                        child: Text(pos.displayName),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        await UserPreferences.setVpnStatusPosition(value.value);
                        setState(() {
                          _vpnStatusPosition = value;
                        });
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.opacity),
                  title: const Text('Status Opacity'),
                  subtitle: Text('${(_vpnStatusOpacity * 100).round()}%'),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: _vpnStatusOpacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(_vpnStatusOpacity * 100).round()}%',
                      onChanged: (value) async {
                        await UserPreferences.setVpnStatusOpacity(value);
                        setState(() {
                          _vpnStatusOpacity = value;
                        });
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off),
                  title: const Text('Hide When Connected'),
                  subtitle: const Text('Only show indicator if VPN disconnected'),
                  value: _vpnShowOnlyWhenDisconnected,
                  onChanged: (value) async {
                    await UserPreferences.setVpnShowOnlyWhenDisconnected(value);
                    setState(() {
                      _vpnShowOnlyWhenDisconnected = value;
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    _vpnService.isVpnConnected ? Icons.lock : Icons.lock_open,
                    color: _vpnService.isVpnConnected ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    _vpnService.isVpnConnected ? 'VPN Connected' : 'VPN Not Connected',
                  ),
                  subtitle: Text(
                    '${_vpnService.currentStatus.countryName} (${_vpnService.currentStatus.countryCode})',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await _vpnService.forceCheck();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SectionTitleWidget(title: 'External Services (Subtitles & Details)'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.subtitles),
                title: const Text('OpenSubtitles API Key'),
                subtitle: FutureBuilder<String?>(
                  future: UserPreferences.getOpenSubtitlesApiKey(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                      return const Text('Configured - Subtitle search enabled');
                    }
                    return const Text('Not configured - Get free key at opensubtitles.com');
                  },
                ),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _showApiKeyDialog(
                  context,
                  title: 'OpenSubtitles API Key',
                  description: 'Enter your OpenSubtitles API key.\n\nGet a free API key at: https://opensubtitles.com/api-key',
                  getCurrentValue: UserPreferences.getOpenSubtitlesApiKey,
                  onSave: (value) async {
                    await UserPreferences.setOpenSubtitlesApiKey(value);
                    await getIt<OpenSubtitlesService>().setApiKey(value);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.movie_filter),
                title: const Text('TMDB API Key'),
                subtitle: FutureBuilder<String?>(
                  future: UserPreferences.getTmdbApiKey(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                      return const Text('Configured - Movie/series details enabled');
                    }
                    return const Text('Not configured - Get free key at themoviedb.org');
                  },
                ),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _showApiKeyDialog(
                  context,
                  title: 'TMDB API Key',
                  description: 'Enter your TMDB API key for movie and series details.\n\nGet a free API key at: https://www.themoviedb.org/settings/api',
                  getCurrentValue: UserPreferences.getTmdbApiKey,
                  onSave: (value) async {
                    await UserPreferences.setTmdbApiKey(value);
                    await getIt<TmdbService>().setApiKey(value);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Preferred Subtitle Language'),
                subtitle: FutureBuilder<String>(
                  future: UserPreferences.getPreferredSubtitleLanguage(),
                  builder: (context, snapshot) {
                    final lang = snapshot.data ?? 'en';
                    return Text(_getLanguageName(lang));
                  },
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _showSubtitleLanguageDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Auto-download Subtitles'),
                subtitle: const Text('Automatically search and download matching subtitles'),
                trailing: FutureBuilder<bool>(
                  future: UserPreferences.getAutoDownloadSubtitles(),
                  builder: (context, snapshot) {
                    return Switch(
                      value: snapshot.data ?? false,
                      onChanged: (value) async {
                        await UserPreferences.setAutoDownloadSubtitles(value);
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SectionTitleWidget(title: 'Image Cache'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Blocked Domains'),
                subtitle: Text(
                  '${FailedDomainCache().blockedDomainCount} domains blocked for 24 hours',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Clear Blocked Domains'),
                subtitle: const Text('Reset blocked domains and retry image loading'),
                onTap: () async {
                  await FailedDomainCache().clearCache();
                  if (context.mounted) {
                    setState(() {}); // Refresh UI
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Blocked domains cache cleared'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionTitleWidget(title: context.loc.about),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.loc.app_version),
                subtitle: Text(_appVersion.isNotEmpty ? _appVersion : 'Loading...'),
                dense: true,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(context.loc.support_on_github),
                subtitle: Text(context.loc.support_on_github_description),
                trailing: const Icon(Icons.open_in_new, size: 18),
                dense: true,
                onTap: () async {
                  final url = Uri.parse('https://github.com/bsogulcan/another-iptv-player');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPlaylistSelectionForCategoryConfig(BuildContext parentContext) {
    // Get all playlists from combined mode (both Xtream and M3U)
    final allPlaylists = AppState.activePlaylists.entries.toList();

    if (allPlaylists.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text('No playlists available')),
      );
      return;
    }

    showDialog<String>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Playlist'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allPlaylists.length,
            itemBuilder: (context, index) {
              final entry = allPlaylists[index];
              final isXtream = AppState.xtreamRepositories.containsKey(entry.key);
              return ListTile(
                leading: Icon(
                  isXtream ? Icons.live_tv : Icons.playlist_play,
                  color: isXtream ? Colors.blue : Colors.green,
                ),
                title: Text(entry.value.name),
                subtitle: Text(isXtream ? 'Xtream Codes' : 'M3U'),
                onTap: () {
                  // Return the playlist ID to select
                  Navigator.pop(dialogContext, entry.key);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ).then((selectedPlaylistId) {
      // Navigate after dialog is fully closed
      if (selectedPlaylistId != null) {
        Navigator.push<bool>(
          parentContext,
          MaterialPageRoute(
            builder: (context) => CategoryConfigScreen(
              playlistId: selectedPlaylistId,
            ),
          ),
        ).then((hasHiddenCategoryChanges) {
          // Reload hidden categories in the unified controller if changes were made
          if (hasHiddenCategoryChanges == true && AppState.isCombinedMode) {
            try {
              final controller = parentContext.read<UnifiedHomeController>();
              controller.loadHiddenCategories();
              controller.loadAllContent(); // Reload to apply filters
            } catch (e) {
              debugPrint('Could not notify UnifiedHomeController: $e');
            }
          }
        });
      }
    });
  }

  refreshM3uPlaylist() async {
    List<M3uItem> oldM3uItems = AppState.m3uItems!;
    List<M3uItem> newM3uItems = [];

    if (AppState.currentPlaylist!.url!.startsWith('http')) {
      showLoadingDialog(context, context.loc.loading_m3u);
      final params = {
        'id': AppState.currentPlaylist!.id,
        'url': AppState.currentPlaylist!.url!,
      };
      newM3uItems = await compute(M3uParser.parseM3uUrl, params);
    } else {
      await _pickFile();
      if (_selectedFilePath == null) return;

      showLoadingDialog(context, context.loc.loading_m3u);
      final params = {
        'id': AppState.currentPlaylist!.id,
        'filePath': _selectedFilePath!,
      };
      newM3uItems = await compute(M3uParser.parseM3uFile, params);
    }

    newM3uItems = updateM3UItemIdsByPosition(
      oldItems: oldM3uItems,
      newItems: newM3uItems,
    );

    await database.deleteAllM3uItems(AppState.currentPlaylist!.id);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => M3uDataLoaderScreen(
          playlist: AppState.currentPlaylist!,
          m3uItems: newM3uItems,
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    _selectedFilePath = null;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.file_selection_error)),
      );
    }
  }

  List<M3uItem> updateM3UItemIdsByPosition({
    required List<M3uItem> oldItems,
    required List<M3uItem> newItems,
  }) {
    Map<String, List<MapEntry<int, String>>> groupedOldItems = {};
    for (int i = 0; i < oldItems.length; i++) {
      M3uItem item = oldItems[i];
      String key = "${item.url}|||${item.name}";
      groupedOldItems.putIfAbsent(key, () => []);
      groupedOldItems[key]!.add(MapEntry(i, item.id));
    }

    Map<String, int> groupUsageCounter = {};
    List<M3uItem> updatedItems = [];

    for (int i = 0; i < newItems.length; i++) {
      M3uItem newItem = newItems[i];
      String key = "${newItem.url}|||${newItem.name}";

      if (groupedOldItems.containsKey(key)) {
        List<MapEntry<int, String>> oldGroup = groupedOldItems[key]!;
        int usageCount = groupUsageCounter[key] ?? 0;

        if (usageCount < oldGroup.length) {
          String oldId = oldGroup[usageCount].value;
          updatedItems.add(newItem.copyWith(id: oldId));
          groupUsageCounter[key] = usageCount + 1;
        } else {
          updatedItems.add(newItem);
        }
      } else {
        updatedItems.add(newItem);
      }
    }

    return updatedItems;
  }

  String _getFfmpegStatusText(FfmpegStatus status) {
    switch (status) {
      case FfmpegStatus.available:
        return 'FFmpeg Available';
      case FfmpegStatus.notFound:
        return 'FFmpeg Not Found';
      case FfmpegStatus.sandboxRestricted:
        return 'Sandbox Restricted';
      case FfmpegStatus.permissionDenied:
        return 'Permission Denied';
      case FfmpegStatus.error:
        return 'FFmpeg Error';
      case FfmpegStatus.unknown:
        return 'Checking FFmpeg...';
    }
  }

  void _showFfmpegInstallDialog(BuildContext context) {
    final instructions = TimeshiftService.getInstallInstructions();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FFmpeg Installation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Timeshift requires FFmpeg to be installed on your system.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  instructions,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              if (Platform.isMacOS) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: macOS App Store apps run in a sandbox that may prevent running external binaries like FFmpeg. '
                          'For timeshift to work, you may need to run a non-sandboxed version of the app.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: instructions));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Instructions copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFfmpegPathDialog(BuildContext context) {
    final controller = TextEditingController();
    UserPreferences.getCustomFfmpegPath().then((path) {
      controller.text = path ?? '';
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom FFmpeg Path'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the full path to your FFmpeg executable, or leave empty to use the system default.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'FFmpeg Path',
                hintText: Platform.isMacOS || Platform.isLinux
                    ? '/usr/local/bin/ffmpeg'
                    : 'C:\\ffmpeg\\bin\\ffmpeg.exe',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.any,
                      allowMultiple: false,
                    );
                    if (result != null && result.files.single.path != null) {
                      controller.text = result.files.single.path!;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Example paths:\n'
              '• macOS (Homebrew): /opt/homebrew/bin/ffmpeg\n'
              '• macOS (Intel): /usr/local/bin/ffmpeg\n'
              '• Linux: /usr/bin/ffmpeg\n'
              '• Windows: C:\\ffmpeg\\bin\\ffmpeg.exe',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await TimeshiftService().setCustomFfmpegPath(null);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Use Default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final path = controller.text.trim();
              await TimeshiftService().setCustomFfmpegPath(
                path.isEmpty ? null : path,
              );
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(
    BuildContext context, {
    required String title,
    required String description,
    required Future<String?> Function() getCurrentValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController();
    final currentValue = await getCurrentValue();
    controller.text = currentValue ?? '';

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => controller.clear(),
                ),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              await onSave(value);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value.isEmpty ? 'API key removed' : 'API key saved'),
                    backgroundColor: value.isEmpty ? Colors.orange : Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSubtitleLanguageDialog(BuildContext context) async {
    final currentLang = await UserPreferences.getPreferredSubtitleLanguage();

    final languages = [
      ('en', 'English'),
      ('es', 'Spanish'),
      ('fr', 'French'),
      ('de', 'German'),
      ('it', 'Italian'),
      ('pt', 'Portuguese'),
      ('ru', 'Russian'),
      ('zh', 'Chinese'),
      ('ja', 'Japanese'),
      ('ko', 'Korean'),
      ('ar', 'Arabic'),
      ('tr', 'Turkish'),
      ('nl', 'Dutch'),
      ('pl', 'Polish'),
      ('sv', 'Swedish'),
      ('da', 'Danish'),
      ('fi', 'Finnish'),
      ('no', 'Norwegian'),
      ('el', 'Greek'),
      ('he', 'Hebrew'),
      ('hi', 'Hindi'),
      ('th', 'Thai'),
      ('vi', 'Vietnamese'),
      ('id', 'Indonesian'),
      ('cs', 'Czech'),
      ('hu', 'Hungarian'),
      ('ro', 'Romanian'),
      ('uk', 'Ukrainian'),
    ];

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preferred Subtitle Language'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final (code, name) = languages[index];
              return RadioListTile<String>(
                title: Text(name),
                subtitle: Text(code.toUpperCase()),
                value: code,
                groupValue: currentLang,
                onChanged: (value) async {
                  if (value != null) {
                    await UserPreferences.setPreferredSubtitleLanguage(value);
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    const languageNames = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
      'tr': 'Turkish',
      'nl': 'Dutch',
      'pl': 'Polish',
      'sv': 'Swedish',
      'da': 'Danish',
      'fi': 'Finnish',
      'no': 'Norwegian',
      'el': 'Greek',
      'he': 'Hebrew',
      'hi': 'Hindi',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'cs': 'Czech',
      'hu': 'Hungarian',
      'ro': 'Romanian',
      'uk': 'Ukrainian',
    };
    return languageNames[code] ?? code.toUpperCase();
  }
}
