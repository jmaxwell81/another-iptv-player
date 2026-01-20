import 'package:another_iptv_player/l10n/app_localizations.dart';
import 'package:another_iptv_player/repositories/epg_repository.dart';
import 'package:another_iptv_player/services/network_discovery_service.dart';
import 'package:another_iptv_player/services/stream_server.dart';
import 'package:another_iptv_player/services/opensubtitles_service.dart';
import 'package:another_iptv_player/services/tmdb_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/utils/audio_handler.dart';
import 'package:media_kit/media_kit.dart';

GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  WidgetsFlutterBinding.ensureInitialized();

  getIt.registerSingleton<MyAudioHandler>(await initAudioService());
  getIt.registerSingleton<AppDatabase>(AppDatabase());
  getIt.registerLazySingleton<StreamServer>(() => StreamServer());
  getIt.registerLazySingleton<NetworkDiscoveryService>(
    () => NetworkDiscoveryService(),
  );
  getIt.registerLazySingleton<EpgRepository>(() => EpgRepository());
  getIt.registerLazySingleton<OpenSubtitlesService>(() => OpenSubtitlesService());
  getIt.registerLazySingleton<TmdbService>(() => TmdbService());

  MediaKit.ensureInitialized();

  // Initialize external services
  await getIt<OpenSubtitlesService>().initialize();
  await getIt<TmdbService>().initialize();
}

void setupLocator(BuildContext context) {
  getIt.registerSingleton<AppLocalizations>(AppLocalizations.of(context)!);
}
