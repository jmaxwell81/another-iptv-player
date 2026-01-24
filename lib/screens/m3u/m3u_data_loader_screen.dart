import 'package:another_iptv_player/models/m3u_item.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/m3u_parser.dart';
import 'package:another_iptv_player/services/playlist_service.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/controllers/m3u_controller.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/progress_step.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:provider/provider.dart';
import '../playlist_screen.dart';
import 'm3u_home_screen.dart';

class M3UDataLoaderScreen extends StatefulWidget {
  final Playlist playlist;
  final List<M3uItem>? m3uItems;
  bool refreshAll = false;
  bool returnToPlaylistScreen = false;
  final List<M3uItem>? oldM3uItems;

  M3UDataLoaderScreen({
    super.key,
    required this.playlist,
    this.m3uItems,
    this.refreshAll = false,
    this.returnToPlaylistScreen = false,
    this.oldM3uItems,
  });

  @override
  M3UDataLoaderScreenState createState() => M3UDataLoaderScreenState();
}

class M3UDataLoaderScreenState extends State<M3UDataLoaderScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _waveAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  M3uController? _controller;
  bool _isDownloading = false;
  String? _downloadError;
  int _currentUrlIndex = 0;
  String? _activeUrl;

  Map<ProgressStep, String> get stepTitles => {
    ProgressStep.userInfo: 'Downloading M3U...',
    ProgressStep.categories: context.loc.preparing_categories,
    ProgressStep.liveChannels: context.loc.preparing_live_streams,
    ProgressStep.movies: context.loc.preparing_movies,
    ProgressStep.series: context.loc.preparing_series,
  };

  final Map<ProgressStep, IconData> stepIcons = {
    ProgressStep.userInfo: Icons.download,
    ProgressStep.categories: Icons.category,
    ProgressStep.liveChannels: Icons.live_tv,
    ProgressStep.movies: Icons.movie,
    ProgressStep.series: Icons.tv,
  };

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _waveAnimationController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveAnimationController, curve: Curves.linear),
    );

    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    List<M3uItem> m3uItems = widget.m3uItems ?? [];

    // Initialize URL index
    _currentUrlIndex = widget.playlist.activeUrlIndex ?? 0;
    final allUrls = widget.playlist.allUrls;
    if (allUrls.isNotEmpty) {
      _activeUrl = allUrls[_currentUrlIndex.clamp(0, allUrls.length - 1)];
    } else {
      _activeUrl = widget.playlist.url;
    }

    // If no m3uItems provided and we have a URL, download and parse
    if (m3uItems.isEmpty && _activeUrl != null) {
      m3uItems = await _downloadWithFailover();
      if (m3uItems.isEmpty && _downloadError != null) {
        return;
      }
    }

    _controller = M3uController(
      playlistId: widget.playlist.id,
      m3uItems: m3uItems,
      refreshAll: widget.refreshAll,
    );

    _startLoading();
  }

  Future<List<M3uItem>> _downloadWithFailover() async {
    final allUrls = widget.playlist.allUrls;
    if (allUrls.isEmpty && _activeUrl == null) {
      setState(() {
        _downloadError = 'No URL configured';
      });
      return [];
    }

    final urlsToTry = allUrls.isNotEmpty ? allUrls : [_activeUrl!];
    final startIndex = _currentUrlIndex;

    for (var attempt = 0; attempt < urlsToTry.length; attempt++) {
      final urlIndex = (startIndex + attempt) % urlsToTry.length;
      final url = urlsToTry[urlIndex];

      setState(() {
        _isDownloading = true;
        _downloadError = null;
        if (attempt > 0) {
          // Show message about trying backup URL
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Primary URL failed. Trying backup URL ${urlIndex + 1}...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });

      try {
        final m3uItems = await M3uParser.parseUrl(widget.playlist.id, url);

        if (m3uItems.isNotEmpty) {
          setState(() {
            _isDownloading = false;
            _currentUrlIndex = urlIndex;
            _activeUrl = url;
          });

          // Update active URL index if we switched URLs
          if (urlIndex != (widget.playlist.activeUrlIndex ?? 0)) {
            final updatedPlaylist = widget.playlist.copyWith(
              activeUrlIndex: urlIndex,
            );
            await PlaylistService.updatePlaylist(updatedPlaylist);
          }

          return m3uItems;
        }
      } catch (e) {
        // Continue to next URL
        if (attempt == urlsToTry.length - 1) {
          // Last attempt failed
          setState(() {
            _isDownloading = false;
            _downloadError = 'Failed to download M3U from all URLs: $e';
          });
        }
      }
    }

    setState(() {
      _isDownloading = false;
    });

    return [];
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseAnimationController.dispose();
    _waveAnimationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startLoading() async {
    if (_controller == null) return;

    final success = await _controller!.loadAllData();

    if (success) {
      _animationController.animateTo(1.0);
      _pulseAnimationController.stop();
      _waveAnimationController.stop();

      // Update last refresh time
      await UserPreferences.setLastRefreshTime(widget.playlist.id, DateTime.now());

      if (widget.returnToPlaylistScreen) {
        // Just pop back to the playlist screen
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        AppState.currentPlaylist = widget.playlist;
        await UserPreferences.setLastPlaylist(widget.playlist.id);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: _controller!,
              child: M3UHomeScreen(playlist: widget.playlist),
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  double _getProgressValue(ProgressStep step) {
    switch (step) {
      case ProgressStep.userInfo:
        return 0.2;
      case ProgressStep.categories:
        return 0.4;
      case ProgressStep.liveChannels:
        return 0.6;
      case ProgressStep.movies:
        return 0.8;
      case ProgressStep.series:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error if download failed
    if (_downloadError != null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 64),
                    SizedBox(height: 24),
                    Text(
                      'Failed to refresh playlist',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _downloadError!,
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Show loading while downloading or if controller not ready
    if (_isDownloading || _controller == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00d4ff)),
                  SizedBox(height: 24),
                  Text(
                    'Downloading M3U playlist...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: ChangeNotifierProvider.value(
          value: _controller!,
          child: Consumer<M3uController>(
            builder: (context, controller, child) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _animationController.animateTo(
                  _getProgressValue(controller.currentStep),
                );
              });

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Section - Logo
                      Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Color(0xFF00d4ff),
                                        Color(0xFF0099cc),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF00d4ff,
                                        ).withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.playlist_play,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Another IPTV Player',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            context.loc.slogan,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),

                      // Middle Section - Current Step
                      Column(
                        children: [
                          // Wave Animation
                          AnimatedBuilder(
                            animation: _waveAnimation,
                            builder: (context, child) {
                              return SizedBox(
                                width: 200,
                                height: 200,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer waves
                                    for (int i = 0; i < 3; i++)
                                      Transform.scale(
                                        scale:
                                            1 +
                                            (i * 0.3) +
                                            (_waveAnimation.value * 0.5),
                                        child: Container(
                                          width: 120 + (i * 20),
                                          height: 120 + (i * 20),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Color(0xFF00d4ff)
                                                  .withOpacity(
                                                    (1 - _waveAnimation.value) *
                                                        (0.3 - i * 0.1),
                                                  ),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Center icon
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF00d4ff),
                                            Color(0xFF0099cc),
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        stepIcons[controller.currentStep],
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 32),

                          Text(
                            stepTitles[controller.currentStep]!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 40),

                          // Progress indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: ProgressStep.values.map((step) {
                              bool isActive =
                                  step.index <= controller.currentStep.index;
                              bool isCurrent = step == controller.currentStep;

                              return AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                width: isCurrent ? 32 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: isActive
                                      ? Color(0xFF00d4ff)
                                      : Colors.white.withOpacity(0.3),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // Bottom Section - Progress
                      Column(
                        children: [
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _progressAnimation.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF00d4ff),
                                              Color(0xFF0099cc),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '${(_progressAnimation.value * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF00d4ff),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          // Error handling
                          if (controller.errorMessage != null) ...[
                            SizedBox(height: 32),
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 32,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    context.loc.error_occurred,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _getLocalizedError(
                                      controller.errorKey,
                                      controller.errorMessage!,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PlaylistScreen(),
                                        ),
                                        (route) => false,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF00d4ff),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(context.loc.close),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getLocalizedError(String? errorKey, String fallbackMessage) {
    return '';
  }

  //   if (errorKey == null) return fallbackMessage;
  //
  //   switch (errorKey) {
  //     // case 'preparing_m3u_exception_no_source':
  //     //   return context.loc.preparing_m3u_exception_no_source;
  //     // case 'preparing_m3u_exception_empty':
  //     //   return context.loc.preparing_m3u_exception_empty;
  //     // case 'preparing_m3u_exception_parse':
  //     //   return context.loc.preparing_m3u_exception_parse(fallbackMessage);
  //     // case 'preparing_categories_exception':
  //       return context.loc.preparing_categories_exception(fallbackMessage);
  //     case 'preparing_live_streams_exception_2':
  //       return context.loc.preparing_live_streams_exception_2(fallbackMessage);
  //     case 'preparing_movies_exception_2':
  //       return context.loc.preparing_movies_exception_2(fallbackMessage);
  //     case 'preparing_series_exception_2':
  //       return context.loc.preparing_series_exception_2(fallbackMessage);
  //     default:
  //       return fallbackMessage;
  //   }
  // }
}
