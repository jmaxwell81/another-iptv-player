import 'package:another_iptv_player/l10n/app_localizations.dart';
import 'package:another_iptv_player/repositories/epg_repository.dart';
import 'package:another_iptv_player/services/network_discovery_service.dart';
import 'package:another_iptv_player/services/source_health_monitor_service.dart';
import 'package:another_iptv_player/services/source_offline_service.dart';
import 'package:another_iptv_player/services/stream_server.dart';
import 'package:another_iptv_player/services/opensubtitles_service.dart';
import 'package:another_iptv_player/services/tmdb_service.dart';
import 'package:another_iptv_player/services/omdb_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/utils/audio_handler.dart';
import 'package:media_kit/media_kit.dart';

GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio service with error handling
  try {
    getIt.registerSingleton<MyAudioHandler>(await initAudioService());
  } catch (e) {
    debugPrint('Failed to initialize audio service: $e');
    // Register a placeholder that won't crash the app
    getIt.registerSingleton<MyAudioHandler>(MyAudioHandler());
  }

  // Initialize database
  try {
    getIt.registerSingleton<AppDatabase>(AppDatabase());
  } catch (e) {
    debugPrint('Failed to initialize database: $e');
    rethrow; // Database is critical, let it fail
  }

  getIt.registerLazySingleton<StreamServer>(() => StreamServer());
  getIt.registerLazySingleton<NetworkDiscoveryService>(
    () => NetworkDiscoveryService(),
  );
  getIt.registerLazySingleton<EpgRepository>(() => EpgRepository());
  getIt.registerLazySingleton<OpenSubtitlesService>(() => OpenSubtitlesService());
  getIt.registerLazySingleton<TmdbService>(() => TmdbService());
  getIt.registerLazySingleton<OmdbService>(() => OmdbService());

  // Source health monitoring services (use factory pattern for singletons)
  getIt.registerLazySingleton<SourceOfflineService>(() => SourceOfflineService());
  getIt.registerLazySingleton<SourceHealthMonitorService>(() => SourceHealthMonitorService());

  // Initialize MediaKit with error handling for devices that don't support it
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('Failed to initialize MediaKit: $e');
    // Continue anyway - video playback may not work but app won't crash
  }

  // Initialize external services with error handling
  try {
    await getIt<OpenSubtitlesService>().initialize();
  } catch (e) {
    debugPrint('Failed to initialize OpenSubtitles service: $e');
  }

  try {
    await getIt<TmdbService>().initialize();
  } catch (e) {
    debugPrint('Failed to initialize TMDB service: $e');
  }

  try {
    await getIt<OmdbService>().initialize();
  } catch (e) {
    debugPrint('Failed to initialize OMDB service: $e');
  }

  // Initialize source offline service (loads offline sources from database)
  try {
    await getIt<SourceOfflineService>().initialize();
  } catch (e) {
    debugPrint('Failed to initialize source offline service: $e');
  }
}

void setupLocator(BuildContext context) {
  getIt.registerSingleton<AppLocalizations>(AppLocalizations.of(context)!);
}
