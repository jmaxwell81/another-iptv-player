import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:another_iptv_player/models/timeshift.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:uuid/uuid.dart';

/// FFmpeg availability status
enum FfmpegStatus {
  unknown,
  available,
  notFound,
  sandboxRestricted,
  permissionDenied,
  error,
}

/// Service for managing timeshift buffering for live streams
/// Allows pausing live TV for up to 30 minutes and seeking within buffer
class TimeshiftService extends ChangeNotifier {
  static final TimeshiftService _instance = TimeshiftService._internal();
  factory TimeshiftService() => _instance;
  TimeshiftService._internal();

  TimeshiftState _state = const TimeshiftState();
  Timer? _bufferTimer;
  Process? _ffmpegProcess;
  final List<TimeshiftRecording> _savedRecordings = [];
  bool _isInitialized = false;

  // FFmpeg status tracking
  FfmpegStatus _ffmpegStatus = FfmpegStatus.unknown;
  String? _ffmpegPath;
  String? _ffmpegError;
  String? _customFfmpegPath;

  TimeshiftState get state => _state;
  List<TimeshiftRecording> get savedRecordings => List.unmodifiable(_savedRecordings);
  bool get isTimeshiftActive => _state.isBuffering;
  FfmpegStatus get ffmpegStatus => _ffmpegStatus;
  String? get ffmpegPath => _ffmpegPath;
  String? get ffmpegError => _ffmpegError;
  bool get isFfmpegAvailable => _ffmpegStatus == FfmpegStatus.available;

  /// Get platform-specific FFmpeg installation instructions
  static String getInstallInstructions() {
    if (Platform.isMacOS) {
      return '''FFmpeg Installation (macOS):

Option 1 - Homebrew (recommended):
  brew install ffmpeg

Option 2 - MacPorts:
  sudo port install ffmpeg

Option 3 - Download binary:
  Visit https://ffmpeg.org/download.html

Note: macOS sandboxed apps may have restrictions running external binaries.
For best results, run the app outside the App Store sandbox.''';
    } else if (Platform.isWindows) {
      return '''FFmpeg Installation (Windows):

Option 1 - winget:
  winget install FFmpeg

Option 2 - Chocolatey:
  choco install ffmpeg

Option 3 - Download binary:
  1. Visit https://ffmpeg.org/download.html
  2. Download Windows build
  3. Extract to C:\\ffmpeg
  4. Add C:\\ffmpeg\\bin to PATH environment variable''';
    } else if (Platform.isLinux) {
      return '''FFmpeg Installation (Linux):

Ubuntu/Debian:
  sudo apt update && sudo apt install ffmpeg

Fedora:
  sudo dnf install ffmpeg

Arch Linux:
  sudo pacman -S ffmpeg''';
    } else if (Platform.isAndroid) {
      return '''FFmpeg for Android:
Timeshift recording is not currently supported on Android.
The feature requires FFmpeg which cannot be bundled with the app.''';
    } else if (Platform.isIOS) {
      return '''FFmpeg for iOS:
Timeshift recording is not currently supported on iOS due to platform restrictions.''';
    }
    return 'Please install FFmpeg for your platform from https://ffmpeg.org/download.html';
  }

  /// Set custom FFmpeg path
  Future<void> setCustomFfmpegPath(String? path) async {
    _customFfmpegPath = path;
    await UserPreferences.setCustomFfmpegPath(path);
    // Re-check FFmpeg availability
    await checkFfmpegAvailability();
  }

  /// Get the effective FFmpeg command/path to use
  String get _ffmpegCommand => _customFfmpegPath ?? 'ffmpeg';

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Load custom FFmpeg path from preferences
    _customFfmpegPath = await UserPreferences.getCustomFfmpegPath();
    await checkFfmpegAvailability();
    await _loadSavedRecordings();
    _isInitialized = true;
  }

  /// Check if FFmpeg is available and can be executed
  Future<FfmpegStatus> checkFfmpegAvailability() async {
    _ffmpegError = null;

    try {
      // First, try to find FFmpeg
      String ffmpegCmd = _ffmpegCommand;

      if (_customFfmpegPath == null) {
        // Try to locate FFmpeg using 'which' on Unix or 'where' on Windows
        if (Platform.isWindows) {
          final result = await Process.run('where', ['ffmpeg']);
          if (result.exitCode == 0) {
            _ffmpegPath = (result.stdout as String).trim().split('\n').first;
          } else {
            _ffmpegStatus = FfmpegStatus.notFound;
            _ffmpegError = 'FFmpeg not found in PATH. Please install FFmpeg.';
            notifyListeners();
            return _ffmpegStatus;
          }
        } else {
          final result = await Process.run('which', ['ffmpeg']);
          if (result.exitCode == 0) {
            _ffmpegPath = (result.stdout as String).trim();
          } else {
            _ffmpegStatus = FfmpegStatus.notFound;
            _ffmpegError = 'FFmpeg not found in PATH. Please install FFmpeg.';
            notifyListeners();
            return _ffmpegStatus;
          }
        }
      } else {
        _ffmpegPath = _customFfmpegPath;
        // Verify custom path exists
        if (!await File(_customFfmpegPath!).exists()) {
          _ffmpegStatus = FfmpegStatus.notFound;
          _ffmpegError = 'Custom FFmpeg path does not exist: $_customFfmpegPath';
          notifyListeners();
          return _ffmpegStatus;
        }
        ffmpegCmd = _customFfmpegPath!;
      }

      // Now try to actually run FFmpeg to verify it works
      try {
        final testResult = await Process.run(ffmpegCmd, ['-version']);
        if (testResult.exitCode == 0) {
          _ffmpegStatus = FfmpegStatus.available;
          debugPrint('FFmpeg available at: $_ffmpegPath');
          debugPrint('FFmpeg version: ${(testResult.stdout as String).split('\n').first}');
        } else {
          _ffmpegStatus = FfmpegStatus.error;
          _ffmpegError = 'FFmpeg returned error code: ${testResult.exitCode}';
        }
      } on ProcessException catch (e) {
        // Check for specific error types
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('operation not permitted') ||
            errorMsg.contains('permission denied')) {
          if (Platform.isMacOS) {
            _ffmpegStatus = FfmpegStatus.sandboxRestricted;
            _ffmpegError = 'macOS sandbox restricts running FFmpeg. '
                'The app may need to be run outside the sandbox for timeshift to work.';
          } else {
            _ffmpegStatus = FfmpegStatus.permissionDenied;
            _ffmpegError = 'Permission denied running FFmpeg. Check file permissions.';
          }
        } else {
          _ffmpegStatus = FfmpegStatus.error;
          _ffmpegError = 'Error running FFmpeg: ${e.message}';
        }
      }
    } catch (e) {
      _ffmpegStatus = FfmpegStatus.error;
      _ffmpegError = 'Error checking FFmpeg: $e';
    }

    notifyListeners();
    return _ffmpegStatus;
  }

  /// Start timeshift buffering for a live stream
  /// Returns a tuple of (success, errorMessage)
  Future<(bool, String?)> startTimeshiftWithError({
    required String streamUrl,
    required String contentId,
    required String contentName,
    required String playlistId,
  }) async {
    // Stop any existing timeshift
    await stopTimeshift();

    // Check FFmpeg availability first
    if (_ffmpegStatus == FfmpegStatus.unknown) {
      await checkFfmpegAvailability();
    }

    if (_ffmpegStatus != FfmpegStatus.available) {
      String errorMsg;
      switch (_ffmpegStatus) {
        case FfmpegStatus.notFound:
          errorMsg = 'FFmpeg not found. Please install FFmpeg to use timeshift.';
          break;
        case FfmpegStatus.sandboxRestricted:
          errorMsg = 'macOS sandbox restricts FFmpeg. Timeshift requires running the app outside the sandbox.';
          break;
        case FfmpegStatus.permissionDenied:
          errorMsg = 'Permission denied. Check FFmpeg file permissions.';
          break;
        default:
          errorMsg = _ffmpegError ?? 'FFmpeg is not available.';
      }
      return (false, errorMsg);
    }

    try {
      // Create temp directory for buffer
      final tempDir = await getTemporaryDirectory();
      final bufferDir = Directory('${tempDir.path}/timeshift');
      if (!await bufferDir.exists()) {
        await bufferDir.create(recursive: true);
      }

      final bufferPath = '${bufferDir.path}/${contentId}_${DateTime.now().millisecondsSinceEpoch}.ts';

      // Start FFmpeg to buffer the stream
      // Using segment muxer to create a rolling buffer
      try {
        _ffmpegProcess = await Process.start(_ffmpegCommand, [
          '-y', // Overwrite output
          '-i', streamUrl,
          '-c', 'copy', // Copy codec, no re-encoding
          '-f', 'mpegts', // MPEG-TS format for live streams
          '-segment_time', '10', // 10 second segments
          '-segment_list_size', '180', // Keep last 180 segments (30 min at 10s each)
          '-segment_wrap', '180', // Wrap around to reuse segment numbers
          bufferPath,
        ]);
      } on ProcessException catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('operation not permitted')) {
          _ffmpegStatus = FfmpegStatus.sandboxRestricted;
          _ffmpegError = 'macOS sandbox restricts running FFmpeg.';
          return (false, 'macOS sandbox restricts FFmpeg. Run the app outside sandbox for timeshift.');
        }
        return (false, 'Failed to start FFmpeg: ${e.message}');
      }

      // Listen for FFmpeg output/errors
      _ffmpegProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('FFmpeg timeshift: $data');
      });

      _state = TimeshiftState(
        isBuffering: true,
        bufferStartTime: DateTime.now(),
        bufferFilePath: bufferPath,
        streamUrl: streamUrl,
        contentId: contentId,
        contentName: contentName,
        playlistId: playlistId,
        isLive: true,
      );

      // Start timer to track buffer duration
      _bufferTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateBufferDuration();
      });

      notifyListeners();
      return (true, null);
    } catch (e) {
      debugPrint('Failed to start timeshift: $e');
      return (false, 'Failed to start timeshift: $e');
    }
  }

  /// Start timeshift buffering for a live stream (legacy API, returns bool only)
  Future<bool> startTimeshift({
    required String streamUrl,
    required String contentId,
    required String contentName,
    required String playlistId,
  }) async {
    final (success, _) = await startTimeshiftWithError(
      streamUrl: streamUrl,
      contentId: contentId,
      contentName: contentName,
      playlistId: playlistId,
    );
    return success;
  }

  void _updateBufferDuration() {
    if (_state.bufferStartTime == null) return;

    final elapsed = DateTime.now().difference(_state.bufferStartTime!);
    final cappedDuration = elapsed > TimeshiftState.maxBufferDuration
        ? TimeshiftState.maxBufferDuration
        : elapsed;

    // Update position if live (following the buffer head)
    final newPosition = _state.isLive ? cappedDuration : _state.currentPosition;

    _state = _state.copyWith(
      bufferDuration: cappedDuration,
      currentPosition: newPosition,
    );
    notifyListeners();
  }

  /// Stop timeshift buffering
  Future<void> stopTimeshift() async {
    _bufferTimer?.cancel();
    _bufferTimer = null;

    if (_ffmpegProcess != null) {
      _ffmpegProcess!.kill();
      _ffmpegProcess = null;
    }

    // Clean up temp buffer file
    if (_state.bufferFilePath != null) {
      try {
        final file = File(_state.bufferFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Failed to clean up buffer file: $e');
      }
    }

    _state = const TimeshiftState();
    notifyListeners();
  }

  /// Pause playback (go behind live)
  void pause() {
    if (!_state.isBuffering) return;
    _state = _state.copyWith(isLive: false);
    notifyListeners();
  }

  /// Resume live playback (catch up to live)
  void goLive() {
    if (!_state.isBuffering) return;
    _state = _state.copyWith(
      isLive: true,
      currentPosition: _state.bufferDuration,
    );
    notifyListeners();
  }

  /// Seek to a specific position in the buffer
  void seekTo(Duration position) {
    if (!_state.isBuffering) return;

    // Clamp position to valid range
    Duration clampedPosition;
    if (position < Duration.zero) {
      clampedPosition = Duration.zero;
    } else if (position > _state.bufferDuration) {
      clampedPosition = _state.bufferDuration;
    } else {
      clampedPosition = position;
    }
    final isNowLive = (_state.bufferDuration - clampedPosition) < const Duration(seconds: 5);

    _state = _state.copyWith(
      currentPosition: clampedPosition,
      isLive: isNowLive,
    );
    notifyListeners();
  }

  /// Seek forward by specified duration
  void seekForward(Duration amount) {
    seekTo(_state.currentPosition + amount);
  }

  /// Seek backward by specified duration
  void seekBackward(Duration amount) {
    seekTo(_state.currentPosition - amount);
  }

  /// Update current playback position (called from player)
  void updatePosition(Duration position) {
    if (!_state.isBuffering || _state.isLive) return;

    // Check if we've caught up to live
    final behindLive = _state.bufferDuration - position;
    if (behindLive < const Duration(seconds: 3)) {
      goLive();
    } else {
      _state = _state.copyWith(currentPosition: position);
      notifyListeners();
    }
  }

  /// Save the current buffer to permanent storage
  /// Returns the saved recording or null if failed
  Future<TimeshiftRecording?> saveBuffer({
    Duration? additionalDuration, // Record additional time beyond buffer
  }) async {
    if (!_state.isBuffering || _state.bufferFilePath == null) {
      return null;
    }

    try {
      // Get documents directory for permanent storage
      final docsDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${docsDir.path}/timeshift_recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final id = const Uuid().v4();
      final fileName = '${_state.contentName}_${DateTime.now().millisecondsSinceEpoch}.ts';
      final savePath = '${recordingsDir.path}/$fileName';

      // Copy buffer file to permanent location
      final bufferFile = File(_state.bufferFilePath!);
      if (await bufferFile.exists()) {
        await bufferFile.copy(savePath);
      }

      // If additional duration requested, continue recording
      if (additionalDuration != null && additionalDuration > Duration.zero) {
        // Start a new FFmpeg process to append to the saved file
        final appendProcess = await Process.start('ffmpeg', [
          '-y',
          '-i', _state.streamUrl!,
          '-c', 'copy',
          '-t', additionalDuration.inSeconds.toString(),
          '-f', 'mpegts',
          savePath,
        ]);

        // Wait for it to complete
        await appendProcess.exitCode;
      }

      final recording = TimeshiftRecording(
        id: id,
        contentId: _state.contentId!,
        contentName: _state.contentName!,
        playlistId: _state.playlistId!,
        filePath: savePath,
        recordingStartTime: _state.bufferStartTime!,
        recordingEndTime: DateTime.now(),
        duration: _state.bufferDuration + (additionalDuration ?? Duration.zero),
        status: TimeshiftRecordingStatus.completed,
      );

      _savedRecordings.add(recording);
      await _saveSavedRecordings();
      notifyListeners();

      return recording;
    } catch (e) {
      debugPrint('Failed to save buffer: $e');
      return null;
    }
  }

  /// Delete a saved recording
  Future<void> deleteRecording(String recordingId) async {
    final index = _savedRecordings.indexWhere((r) => r.id == recordingId);
    if (index == -1) return;

    final recording = _savedRecordings[index];

    // Delete the file
    try {
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete recording file: $e');
    }

    _savedRecordings.removeAt(index);
    await _saveSavedRecordings();
    notifyListeners();
  }

  /// Load saved recordings from preferences
  Future<void> _loadSavedRecordings() async {
    try {
      final jsonList = await UserPreferences.getTimeshiftRecordings();
      _savedRecordings.clear();
      for (final json in jsonList) {
        try {
          final recording = TimeshiftRecording.fromJson(json);
          // Only add if file still exists
          if (await recording.fileExists()) {
            _savedRecordings.add(recording);
          }
        } catch (e) {
          debugPrint('Failed to load recording: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load saved recordings: $e');
    }
  }

  /// Save recordings list to preferences
  Future<void> _saveSavedRecordings() async {
    try {
      final jsonList = _savedRecordings.map((r) => r.toJson()).toList();
      await UserPreferences.setTimeshiftRecordings(jsonList);
    } catch (e) {
      debugPrint('Failed to save recordings: $e');
    }
  }

  /// Get total storage used by recordings
  Future<int> getStorageUsed() async {
    int total = 0;
    for (final recording in _savedRecordings) {
      try {
        final file = File(recording.filePath);
        if (await file.exists()) {
          total += await file.length();
        }
      } catch (e) {
        // Ignore
      }
    }
    return total;
  }

  @override
  void dispose() {
    stopTimeshift();
    super.dispose();
  }
}
