import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:another_iptv_player/models/recording_job.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/timeshift_service.dart';

/// Service for managing background live stream recordings
class LiveRecordingService extends ChangeNotifier {
  static final LiveRecordingService _instance = LiveRecordingService._internal();
  factory LiveRecordingService() => _instance;
  LiveRecordingService._internal();

  final TimeshiftService _timeshiftService = TimeshiftService();
  final Map<String, RecordingJob> _activeJobs = {};
  final Map<String, Process> _processes = {};
  final Map<String, Timer> _progressTimers = {};
  final List<RecordingJob> _completedJobs = [];
  bool _isInitialized = false;

  /// All active recording jobs
  List<RecordingJob> get activeJobs => _activeJobs.values.toList();

  /// All completed recording jobs
  List<RecordingJob> get completedJobs => List.unmodifiable(_completedJobs);

  /// Total number of active recordings
  int get activeCount => _activeJobs.length;

  /// Whether there are any active recordings
  bool get hasActiveRecordings => _activeJobs.isNotEmpty;

  /// FFmpeg status from timeshift service
  FfmpegStatus get ffmpegStatus => _timeshiftService.ffmpegStatus;

  /// FFmpeg error message
  String? get ffmpegError => _timeshiftService.ffmpegError;

  /// Whether FFmpeg is available
  bool get isFfmpegAvailable => _timeshiftService.isFfmpegAvailable;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _timeshiftService.initialize();
    await _loadCompletedJobs();

    // Check for any orphaned recordings from previous sessions
    await _cleanupOrphanedJobs();

    _isInitialized = true;
  }

  /// Check FFmpeg availability and return status with instructions
  Future<(bool available, String? error, String instructions)> checkFfmpeg() async {
    await _timeshiftService.checkFfmpegAvailability();

    final available = _timeshiftService.isFfmpegAvailable;
    final error = _timeshiftService.ffmpegError;
    final instructions = TimeshiftService.getInstallInstructions();

    return (available, error, instructions);
  }

  /// Start a new recording job
  Future<RecordingJob?> startRecording({
    required ContentItem content,
    required String playlistId,
    required Duration duration,
  }) async {
    // Check FFmpeg first
    if (!isFfmpegAvailable) {
      await checkFfmpeg();
      if (!isFfmpegAvailable) {
        return null;
      }
    }

    try {
      // Create recordings directory
      final docsDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${docsDir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final id = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = content.name.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final filePath = '${recordingsDir.path}/${safeFileName}_$timestamp.ts';

      final job = RecordingJob(
        id: id,
        contentId: content.id,
        contentName: content.name,
        playlistId: playlistId,
        streamUrl: content.url,
        filePath: filePath,
        startTime: DateTime.now(),
        targetDuration: duration,
        status: RecordingStatus.pending,
      );

      _activeJobs[id] = job;
      notifyListeners();

      // Start the FFmpeg process
      final success = await _startFfmpegProcess(job);

      if (!success) {
        _activeJobs.remove(id);
        notifyListeners();
        return null;
      }

      return _activeJobs[id];
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      return null;
    }
  }

  /// Start the FFmpeg process for a recording job
  Future<bool> _startFfmpegProcess(RecordingJob job) async {
    try {
      final ffmpegCmd = await UserPreferences.getCustomFfmpegPath() ?? 'ffmpeg';

      final process = await Process.start(ffmpegCmd, [
        '-y', // Overwrite output
        '-i', job.streamUrl,
        '-c', 'copy', // Copy codec, no re-encoding
        '-t', job.targetDuration.inSeconds.toString(), // Duration limit
        '-f', 'mpegts', // MPEG-TS format for live streams
        job.filePath,
      ]);

      _processes[job.id] = process;

      // Update job with process ID and status
      _activeJobs[job.id] = job.copyWith(
        status: RecordingStatus.recording,
        processId: process.pid,
      );
      notifyListeners();

      // Listen for FFmpeg output/errors
      final errorBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((data) {
        errorBuffer.write(data);
        // Parse FFmpeg progress from stderr
        _parseProgress(job.id, data);
      });

      // Handle process completion
      process.exitCode.then((exitCode) {
        _handleProcessComplete(job.id, exitCode, errorBuffer.toString());
      });

      // Start progress timer
      _startProgressTimer(job.id);

      return true;
    } on ProcessException catch (e) {
      debugPrint('Failed to start FFmpeg process: ${e.message}');
      _activeJobs[job.id] = job.copyWith(
        status: RecordingStatus.failed,
        errorMessage: 'Failed to start FFmpeg: ${e.message}',
      );
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Failed to start FFmpeg process: $e');
      _activeJobs[job.id] = job.copyWith(
        status: RecordingStatus.failed,
        errorMessage: 'Failed to start recording: $e',
      );
      notifyListeners();
      return false;
    }
  }

  /// Parse FFmpeg progress output
  void _parseProgress(String jobId, String output) {
    // FFmpeg outputs progress info like: time=00:01:23.45
    final timeMatch = RegExp(r'time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})').firstMatch(output);
    if (timeMatch != null) {
      final hours = int.parse(timeMatch.group(1)!);
      final minutes = int.parse(timeMatch.group(2)!);
      final seconds = int.parse(timeMatch.group(3)!);

      final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);

      final job = _activeJobs[jobId];
      if (job != null && job.status == RecordingStatus.recording) {
        _activeJobs[jobId] = job.copyWith(recordedDuration: duration);
        notifyListeners();
      }
    }
  }

  /// Start a timer to update progress based on elapsed time
  void _startProgressTimer(String jobId) {
    _progressTimers[jobId]?.cancel();
    _progressTimers[jobId] = Timer.periodic(const Duration(seconds: 1), (_) {
      final job = _activeJobs[jobId];
      if (job == null || job.status != RecordingStatus.recording) {
        _progressTimers[jobId]?.cancel();
        return;
      }

      // Calculate elapsed time
      final elapsed = DateTime.now().difference(job.startTime);
      final cappedElapsed = elapsed > job.targetDuration ? job.targetDuration : elapsed;

      _activeJobs[jobId] = job.copyWith(recordedDuration: cappedElapsed);
      notifyListeners();
    });
  }

  /// Handle FFmpeg process completion
  void _handleProcessComplete(String jobId, int exitCode, String errorOutput) {
    _progressTimers[jobId]?.cancel();
    _processes.remove(jobId);

    final job = _activeJobs[jobId];
    if (job == null) return;

    if (exitCode == 0 || job.status == RecordingStatus.cancelled) {
      // Success or user cancelled
      final finalStatus = job.status == RecordingStatus.cancelled
          ? RecordingStatus.cancelled
          : RecordingStatus.completed;

      final completedJob = job.copyWith(
        status: finalStatus,
        endTime: DateTime.now(),
        recordedDuration: job.status == RecordingStatus.cancelled
            ? job.recordedDuration
            : job.targetDuration,
      );

      _activeJobs.remove(jobId);
      if (finalStatus == RecordingStatus.completed) {
        _completedJobs.insert(0, completedJob);
        _saveCompletedJobs();
      }
    } else {
      // Failed
      String errorMsg = 'Recording failed (exit code: $exitCode)';

      // Try to extract meaningful error from FFmpeg output
      if (errorOutput.contains('Connection refused')) {
        errorMsg = 'Connection refused - stream may be offline';
      } else if (errorOutput.contains('Invalid data')) {
        errorMsg = 'Invalid stream data received';
      } else if (errorOutput.contains('timeout')) {
        errorMsg = 'Stream connection timed out';
      }

      final failedJob = job.copyWith(
        status: RecordingStatus.failed,
        errorMessage: errorMsg,
        endTime: DateTime.now(),
      );

      _activeJobs.remove(jobId);
      _completedJobs.insert(0, failedJob);
      _saveCompletedJobs();
    }

    notifyListeners();
  }

  /// Stop a recording job
  Future<void> stopRecording(String jobId) async {
    final job = _activeJobs[jobId];
    if (job == null || !job.canCancel) return;

    // Update status to cancelled before killing process
    _activeJobs[jobId] = job.copyWith(status: RecordingStatus.cancelled);
    notifyListeners();

    // Kill the FFmpeg process
    final process = _processes[jobId];
    if (process != null) {
      process.kill(ProcessSignal.sigterm);
    }
  }

  /// Extend a recording by additional duration
  Future<bool> extendRecording(String jobId, Duration additionalDuration) async {
    final job = _activeJobs[jobId];
    if (job == null || !job.canExtend) return false;

    // Stop current recording
    final process = _processes[jobId];
    if (process != null) {
      process.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Calculate remaining time from original target plus extension
    final elapsed = DateTime.now().difference(job.startTime);
    final newTargetDuration = job.targetDuration + additionalDuration;

    // Update job with new target
    final updatedJob = job.copyWith(
      targetDuration: newTargetDuration,
      status: RecordingStatus.pending,
    );
    _activeJobs[jobId] = updatedJob;
    notifyListeners();

    // Restart FFmpeg with new duration
    // We need to append to existing file, so use a temp file and concat later
    final success = await _continueRecording(updatedJob, elapsed);

    return success;
  }

  /// Continue recording (append to existing file)
  Future<bool> _continueRecording(RecordingJob job, Duration alreadyRecorded) async {
    try {
      final ffmpegCmd = await UserPreferences.getCustomFfmpegPath() ?? 'ffmpeg';
      final remainingDuration = job.targetDuration - alreadyRecorded;

      if (remainingDuration.inSeconds <= 0) {
        // Already completed
        _handleProcessComplete(job.id, 0, '');
        return true;
      }

      // Create temp file for new segment
      final tempPath = '${job.filePath}.temp.ts';

      final process = await Process.start(ffmpegCmd, [
        '-y',
        '-i', job.streamUrl,
        '-c', 'copy',
        '-t', remainingDuration.inSeconds.toString(),
        '-f', 'mpegts',
        tempPath,
      ]);

      _processes[job.id] = process;
      _activeJobs[job.id] = job.copyWith(
        status: RecordingStatus.recording,
        processId: process.pid,
        recordedDuration: alreadyRecorded,
      );
      notifyListeners();

      // Listen for completion
      final errorBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((data) {
        errorBuffer.write(data);
      });

      process.exitCode.then((exitCode) async {
        if (exitCode == 0) {
          // Concat the files
          await _concatFiles(job.filePath, tempPath);
        }
        _handleProcessComplete(job.id, exitCode, errorBuffer.toString());
      });

      _startProgressTimer(job.id);

      return true;
    } catch (e) {
      debugPrint('Failed to continue recording: $e');
      return false;
    }
  }

  /// Concatenate two TS files
  Future<void> _concatFiles(String originalPath, String tempPath) async {
    try {
      final ffmpegCmd = await UserPreferences.getCustomFfmpegPath() ?? 'ffmpeg';
      final concatPath = '$originalPath.concat.ts';

      // Create concat file list
      final listPath = '$originalPath.list.txt';
      final listFile = File(listPath);
      await listFile.writeAsString("file '$originalPath'\nfile '$tempPath'\n");

      // Concat using FFmpeg
      final result = await Process.run(ffmpegCmd, [
        '-y',
        '-f', 'concat',
        '-safe', '0',
        '-i', listPath,
        '-c', 'copy',
        concatPath,
      ]);

      if (result.exitCode == 0) {
        // Replace original with concatenated file
        await File(originalPath).delete();
        await File(concatPath).rename(originalPath);
      }

      // Clean up
      await File(tempPath).delete().catchError((_) => File(tempPath));
      await listFile.delete().catchError((_) => listFile);
    } catch (e) {
      debugPrint('Failed to concat files: $e');
    }
  }

  /// Get a specific job by ID
  RecordingJob? getJob(String jobId) => _activeJobs[jobId];

  /// Check if a content item is currently being recorded
  bool isRecording(String contentId) {
    return _activeJobs.values.any((job) =>
        job.contentId == contentId && job.isActive);
  }

  /// Get the recording job for a content item
  RecordingJob? getRecordingForContent(String contentId) {
    try {
      return _activeJobs.values.firstWhere((job) =>
          job.contentId == contentId && job.isActive);
    } catch (e) {
      return null;
    }
  }

  /// Delete a completed recording
  Future<void> deleteRecording(String jobId) async {
    final index = _completedJobs.indexWhere((j) => j.id == jobId);
    if (index == -1) return;

    final job = _completedJobs[index];

    // Delete the file
    try {
      final file = File(job.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete recording file: $e');
    }

    _completedJobs.removeAt(index);
    await _saveCompletedJobs();
    notifyListeners();
  }

  /// Clear all completed recordings
  Future<void> clearCompletedRecordings() async {
    for (final job in _completedJobs) {
      try {
        final file = File(job.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore
      }
    }
    _completedJobs.clear();
    await _saveCompletedJobs();
    notifyListeners();
  }

  /// Load completed jobs from preferences
  Future<void> _loadCompletedJobs() async {
    try {
      final jsonList = await UserPreferences.getRecordingJobs();
      _completedJobs.clear();
      for (final json in jsonList) {
        try {
          final job = RecordingJob.fromJson(json);
          // Only add if file still exists and job is completed/failed
          if (!job.isActive && await job.fileExists()) {
            _completedJobs.add(job);
          }
        } catch (e) {
          debugPrint('Failed to load recording job: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load completed jobs: $e');
    }
  }

  /// Save completed jobs to preferences
  Future<void> _saveCompletedJobs() async {
    try {
      final jsonList = _completedJobs.map((j) => j.toJson()).toList();
      await UserPreferences.setRecordingJobs(jsonList);
    } catch (e) {
      debugPrint('Failed to save completed jobs: $e');
    }
  }

  /// Clean up any orphaned jobs from previous sessions
  Future<void> _cleanupOrphanedJobs() async {
    // Any jobs that were "recording" when we load are actually failed
    for (int i = 0; i < _completedJobs.length; i++) {
      final job = _completedJobs[i];
      if (job.isActive) {
        _completedJobs[i] = job.copyWith(
          status: RecordingStatus.failed,
          errorMessage: 'Recording interrupted by app shutdown',
        );
      }
    }
    await _saveCompletedJobs();
  }

  /// Get total storage used by recordings
  Future<int> getStorageUsed() async {
    int total = 0;
    for (final job in _completedJobs) {
      total += await job.getFileSize();
    }
    return total;
  }

  @override
  void dispose() {
    // Kill all active processes
    for (final process in _processes.values) {
      process.kill();
    }
    _processes.clear();

    // Cancel all timers
    for (final timer in _progressTimers.values) {
      timer.cancel();
    }
    _progressTimers.clear();

    super.dispose();
  }
}
