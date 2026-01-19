import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:another_iptv_player/models/recording.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

class RecordingService extends ChangeNotifier {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  final Map<String, Recording> _recordings = {};
  final Map<String, Process> _activeProcesses = {};
  Timer? _schedulerTimer;
  bool _isInitialized = false;

  List<Recording> get recordings => _recordings.values.toList()
    ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

  List<Recording> get scheduledRecordings =>
      recordings.where((r) => r.isScheduled).toList();

  List<Recording> get activeRecordings =>
      recordings.where((r) => r.isRecording).toList();

  List<Recording> get completedRecordings =>
      recordings.where((r) => r.isCompleted).toList();

  List<Recording> get failedRecordings =>
      recordings.where((r) => r.isFailed).toList();

  bool get hasActiveRecording => activeRecordings.isNotEmpty;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadRecordings();
    _startScheduler();
    _isInitialized = true;
  }

  Future<void> _loadRecordings() async {
    final savedRecordings = await UserPreferences.getRecordings();
    for (final recording in savedRecordings) {
      _recordings[recording.id] = recording;
    }
    notifyListeners();
  }

  Future<void> _saveRecordings() async {
    await UserPreferences.saveRecordings(_recordings.values.toList());
  }

  void _startScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkScheduledRecordings();
    });
    // Check immediately
    _checkScheduledRecordings();
  }

  void _checkScheduledRecordings() {
    final now = DateTime.now();

    for (final recording in scheduledRecordings) {
      // Start recording if scheduled time has arrived
      if (recording.scheduledStart.isBefore(now) ||
          recording.scheduledStart.difference(now).inSeconds < 30) {
        _startRecording(recording);
      }
    }

    // Check for recordings that should end
    for (final recording in activeRecordings) {
      if (recording.scheduledEnd.isBefore(now)) {
        stopRecording(recording.id);
      }
    }
  }

  Future<String> _getRecordingDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingDir = Directory(path.join(appDir.path, 'recordings'));
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }
    return recordingDir.path;
  }

  Future<Recording> scheduleRecording({
    required String playlistId,
    required String streamId,
    required String channelName,
    String? programTitle,
    String? programDescription,
    required String streamUrl,
    String? channelIcon,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    ContentType contentType = ContentType.liveStream,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    // Determine if this should start immediately or be scheduled
    final shouldStartNow = scheduledStart.isBefore(now) ||
        scheduledStart.difference(now).inMinutes < 1;

    final recording = Recording(
      id: id,
      playlistId: playlistId,
      streamId: streamId,
      channelName: channelName,
      programTitle: programTitle,
      programDescription: programDescription,
      streamUrl: streamUrl,
      channelIcon: channelIcon,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: shouldStartNow ? RecordingStatus.recording : RecordingStatus.scheduled,
      contentType: contentType,
      createdAt: now,
      updatedAt: now,
    );

    _recordings[id] = recording;
    await _saveRecordings();
    notifyListeners();

    if (shouldStartNow) {
      _startRecording(recording);
    }

    return recording;
  }

  Future<Recording> recordNow({
    required String playlistId,
    required String streamId,
    required String channelName,
    String? programTitle,
    required String streamUrl,
    String? channelIcon,
    required Duration duration,
    ContentType contentType = ContentType.liveStream,
  }) async {
    final now = DateTime.now();
    return scheduleRecording(
      playlistId: playlistId,
      streamId: streamId,
      channelName: channelName,
      programTitle: programTitle,
      streamUrl: streamUrl,
      channelIcon: channelIcon,
      scheduledStart: now,
      scheduledEnd: now.add(duration),
      contentType: contentType,
    );
  }

  Future<void> _startRecording(Recording recording) async {
    if (_activeProcesses.containsKey(recording.id)) return;

    try {
      final recordingDir = await _getRecordingDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = _sanitizeFileName(
          '${recording.channelName}_$timestamp.mp4');
      final filePath = path.join(recordingDir, fileName);

      // Update status to recording
      final updated = recording.copyWith(
        status: RecordingStatus.recording,
        actualStart: DateTime.now(),
        filePath: filePath,
        updatedAt: DateTime.now(),
      );
      _recordings[recording.id] = updated;
      await _saveRecordings();
      notifyListeners();

      // Start FFmpeg process
      // Using ffmpeg to record the stream
      final process = await Process.start(
        'ffmpeg',
        [
          '-i', recording.streamUrl,
          '-c', 'copy',
          '-t', recording.scheduledEnd.difference(DateTime.now()).inSeconds.toString(),
          '-y',
          filePath,
        ],
        mode: ProcessStartMode.detached,
      );

      _activeProcesses[recording.id] = process;

      // Monitor process completion
      process.exitCode.then((exitCode) async {
        _activeProcesses.remove(recording.id);

        final current = _recordings[recording.id];
        if (current == null) return;

        if (exitCode == 0 || exitCode == 255) {
          // Success or killed (normal stop)
          final file = File(filePath);
          final fileSize = await file.exists() ? await file.length() : 0;

          final completed = current.copyWith(
            status: RecordingStatus.completed,
            actualEnd: DateTime.now(),
            fileSize: fileSize,
            updatedAt: DateTime.now(),
          );
          _recordings[recording.id] = completed;
        } else {
          final failed = current.copyWith(
            status: RecordingStatus.failed,
            actualEnd: DateTime.now(),
            errorMessage: 'FFmpeg exited with code $exitCode',
            updatedAt: DateTime.now(),
          );
          _recordings[recording.id] = failed;
        }

        await _saveRecordings();
        notifyListeners();
      });
    } catch (e) {
      final failed = recording.copyWith(
        status: RecordingStatus.failed,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      );
      _recordings[recording.id] = failed;
      await _saveRecordings();
      notifyListeners();
    }
  }

  Future<void> stopRecording(String id) async {
    final process = _activeProcesses[id];
    if (process != null) {
      // Send SIGINT to gracefully stop FFmpeg
      process.kill(ProcessSignal.sigint);
      _activeProcesses.remove(id);
    }

    final recording = _recordings[id];
    if (recording != null && recording.isRecording) {
      // Wait a moment for file to be finalized
      await Future.delayed(const Duration(seconds: 2));

      final file = recording.filePath != null ? File(recording.filePath!) : null;
      final fileSize = file != null && await file.exists()
          ? await file.length()
          : 0;

      final completed = recording.copyWith(
        status: RecordingStatus.completed,
        actualEnd: DateTime.now(),
        fileSize: fileSize,
        updatedAt: DateTime.now(),
      );
      _recordings[id] = completed;
      await _saveRecordings();
      notifyListeners();
    }
  }

  Future<void> cancelRecording(String id) async {
    final process = _activeProcesses[id];
    if (process != null) {
      process.kill(ProcessSignal.sigkill);
      _activeProcesses.remove(id);
    }

    final recording = _recordings[id];
    if (recording != null) {
      // Delete partial file
      if (recording.filePath != null) {
        final file = File(recording.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final cancelled = recording.copyWith(
        status: RecordingStatus.cancelled,
        actualEnd: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _recordings[id] = cancelled;
      await _saveRecordings();
      notifyListeners();
    }
  }

  Future<void> deleteRecording(String id, {bool deleteFile = true}) async {
    await cancelRecording(id);

    final recording = _recordings[id];
    if (recording != null && deleteFile && recording.filePath != null) {
      final file = File(recording.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _recordings.remove(id);
    await _saveRecordings();
    notifyListeners();
  }

  Recording? getRecording(String id) => _recordings[id];

  Recording? getActiveRecordingForStream(String streamId) {
    try {
      return activeRecordings.firstWhere((r) => r.streamId == streamId);
    } catch (_) {
      return null;
    }
  }

  bool isStreamBeingRecorded(String streamId) {
    return activeRecordings.any((r) => r.streamId == streamId);
  }

  List<Recording> getRecordingsForChannel(String streamId) {
    return recordings.where((r) => r.streamId == streamId).toList();
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<void> clearCompletedRecordings({bool deleteFiles = false}) async {
    final completed = completedRecordings.toList();
    for (final recording in completed) {
      if (deleteFiles && recording.filePath != null) {
        final file = File(recording.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _recordings.remove(recording.id);
    }
    await _saveRecordings();
    notifyListeners();
  }

  @override
  void dispose() {
    _schedulerTimer?.cancel();
    // Stop all active recordings
    for (final process in _activeProcesses.values) {
      process.kill(ProcessSignal.sigint);
    }
    _activeProcesses.clear();
    super.dispose();
  }
}
