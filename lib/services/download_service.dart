import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:another_iptv_player/models/download.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Map<String, Download> _downloads = {};
  final Map<String, StreamSubscription> _activeDownloads = {};
  final Map<String, http.Client> _clients = {};

  int _maxConcurrentDownloads = 1;
  bool _isInitialized = false;

  List<Download> get downloads => _downloads.values.toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));

  List<Download> get pendingDownloads =>
      downloads.where((d) => d.isPending).toList();

  List<Download> get activeDownloads =>
      downloads.where((d) => d.isDownloading).toList();

  List<Download> get completedDownloads =>
      downloads.where((d) => d.isCompleted).toList();

  List<Download> get failedDownloads =>
      downloads.where((d) => d.isFailed).toList();

  int get activeCount => activeDownloads.length;
  int get pendingCount => pendingDownloads.length;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _maxConcurrentDownloads = await UserPreferences.getMaxConcurrentDownloads();
    await _loadDownloads();
    _isInitialized = true;
    _processQueue();
  }

  Future<void> _loadDownloads() async {
    final savedDownloads = await UserPreferences.getDownloads();
    for (final download in savedDownloads) {
      _downloads[download.id] = download;
    }
    notifyListeners();
  }

  Future<void> _saveDownloads() async {
    await UserPreferences.saveDownloads(_downloads.values.toList());
  }

  Future<String> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(path.join(appDir.path, 'downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<Download> addDownload({
    required String playlistId,
    required String contentId,
    required String name,
    String? description,
    required String sourceUrl,
    String? thumbnailUrl,
    required ContentType contentType,
    required DownloadType downloadType,
    int? seasonNumber,
    int? episodeNumber,
    String? seriesId,
    String? seriesName,
    int priority = 100,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final download = Download(
      id: id,
      playlistId: playlistId,
      contentId: contentId,
      name: name,
      description: description,
      sourceUrl: sourceUrl,
      thumbnailUrl: thumbnailUrl,
      contentType: contentType,
      downloadType: downloadType,
      status: DownloadStatus.pending,
      priority: priority,
      createdAt: now,
      updatedAt: now,
    );

    _downloads[id] = download;
    await _saveDownloads();
    notifyListeners();

    _processQueue();
    return download;
  }

  Future<List<Download>> addSeriesDownload({
    required String playlistId,
    required String seriesId,
    required String seriesName,
    required List<Map<String, dynamic>> episodes,
    String? thumbnailUrl,
  }) async {
    final downloads = <Download>[];
    int priority = 100;

    for (final episode in episodes) {
      final download = await addDownload(
        playlistId: playlistId,
        contentId: episode['id'] as String,
        name: episode['name'] as String,
        description: episode['description'] as String?,
        sourceUrl: episode['url'] as String,
        thumbnailUrl: episode['thumbnail'] as String? ?? thumbnailUrl,
        contentType: ContentType.series,
        downloadType: DownloadType.episode,
        seasonNumber: episode['season'] as int?,
        episodeNumber: episode['episode'] as int?,
        seriesId: seriesId,
        seriesName: seriesName,
        priority: priority++,
      );
      downloads.add(download);
    }

    return downloads;
  }

  void _processQueue() {
    if (activeCount >= _maxConcurrentDownloads) return;

    final pending = pendingDownloads;
    final slotsAvailable = _maxConcurrentDownloads - activeCount;

    for (var i = 0; i < slotsAvailable && i < pending.length; i++) {
      _startDownload(pending[i]);
    }
  }

  Future<void> _startDownload(Download download) async {
    if (_activeDownloads.containsKey(download.id)) return;

    final updated = download.copyWith(
      status: DownloadStatus.downloading,
      updatedAt: DateTime.now(),
    );
    _downloads[download.id] = updated;
    await _saveDownloads();
    notifyListeners();

    final client = http.Client();
    _clients[download.id] = client;

    try {
      final request = http.Request('GET', Uri.parse(download.sourceUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final downloadDir = await _getDownloadDirectory();
      final fileName = _sanitizeFileName('${download.name}.mp4');
      final filePath = path.join(downloadDir, fileName);
      final file = File(filePath);
      final sink = file.openWrite();

      int downloadedBytes = 0;

      final subscription = response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          final progress = contentLength > 0
              ? downloadedBytes / contentLength
              : 0.0;

          final progressUpdate = _downloads[download.id]!.copyWith(
            downloadedBytes: downloadedBytes,
            fileSize: contentLength > 0 ? contentLength : null,
            progress: progress,
            updatedAt: DateTime.now(),
          );
          _downloads[download.id] = progressUpdate;
          notifyListeners();
        },
        onDone: () async {
          await sink.close();
          _activeDownloads.remove(download.id);
          _clients.remove(download.id);

          final completed = _downloads[download.id]!.copyWith(
            status: DownloadStatus.completed,
            filePath: filePath,
            fileSize: downloadedBytes,
            downloadedBytes: downloadedBytes,
            progress: 1.0,
            updatedAt: DateTime.now(),
          );
          _downloads[download.id] = completed;
          await _saveDownloads();
          notifyListeners();

          _processQueue();
        },
        onError: (error) async {
          await sink.close();
          _activeDownloads.remove(download.id);
          _clients.remove(download.id);

          final failed = _downloads[download.id]!.copyWith(
            status: DownloadStatus.failed,
            errorMessage: error.toString(),
            updatedAt: DateTime.now(),
          );
          _downloads[download.id] = failed;
          await _saveDownloads();
          notifyListeners();

          _processQueue();
        },
        cancelOnError: true,
      );

      _activeDownloads[download.id] = subscription;
    } catch (e) {
      _clients.remove(download.id);
      final failed = _downloads[download.id]!.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      );
      _downloads[download.id] = failed;
      await _saveDownloads();
      notifyListeners();

      _processQueue();
    }
  }

  Future<void> pauseDownload(String id) async {
    final subscription = _activeDownloads[id];
    if (subscription != null) {
      await subscription.cancel();
      _activeDownloads.remove(id);
      _clients[id]?.close();
      _clients.remove(id);

      final download = _downloads[id];
      if (download != null) {
        final paused = download.copyWith(
          status: DownloadStatus.paused,
          updatedAt: DateTime.now(),
        );
        _downloads[id] = paused;
        await _saveDownloads();
        notifyListeners();
      }
    }
  }

  Future<void> resumeDownload(String id) async {
    final download = _downloads[id];
    if (download != null && download.isPaused) {
      final pending = download.copyWith(
        status: DownloadStatus.pending,
        updatedAt: DateTime.now(),
      );
      _downloads[id] = pending;
      await _saveDownloads();
      notifyListeners();

      _processQueue();
    }
  }

  Future<void> cancelDownload(String id) async {
    final subscription = _activeDownloads[id];
    if (subscription != null) {
      await subscription.cancel();
      _activeDownloads.remove(id);
      _clients[id]?.close();
      _clients.remove(id);
    }

    final download = _downloads[id];
    if (download != null) {
      // Delete partial file if exists
      if (download.filePath != null) {
        final file = File(download.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final cancelled = download.copyWith(
        status: DownloadStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      _downloads[id] = cancelled;
      await _saveDownloads();
      notifyListeners();

      _processQueue();
    }
  }

  Future<void> retryDownload(String id) async {
    final download = _downloads[id];
    if (download != null && (download.isFailed || download.isCancelled)) {
      final pending = download.copyWith(
        status: DownloadStatus.pending,
        errorMessage: null,
        progress: 0,
        downloadedBytes: 0,
        updatedAt: DateTime.now(),
      );
      _downloads[id] = pending;
      await _saveDownloads();
      notifyListeners();

      _processQueue();
    }
  }

  Future<void> deleteDownload(String id, {bool deleteFile = true}) async {
    await cancelDownload(id);

    final download = _downloads[id];
    if (download != null && deleteFile && download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _downloads.remove(id);
    await _saveDownloads();
    notifyListeners();
  }

  Future<void> setMaxConcurrentDownloads(int max) async {
    _maxConcurrentDownloads = max.clamp(1, 5);
    await UserPreferences.setMaxConcurrentDownloads(_maxConcurrentDownloads);
    _processQueue();
  }

  Download? getDownload(String id) => _downloads[id];

  List<Download> getDownloadsForSeries(String seriesId) {
    return downloads.where((d) => d.seriesId == seriesId).toList();
  }

  bool isContentDownloaded(String contentId) {
    return downloads.any((d) => d.contentId == contentId && d.isCompleted);
  }

  bool isContentDownloading(String contentId) {
    return downloads.any((d) =>
        d.contentId == contentId &&
        (d.isDownloading || d.isPending));
  }

  Download? getDownloadForContent(String contentId) {
    try {
      return downloads.firstWhere((d) => d.contentId == contentId);
    } catch (_) {
      return null;
    }
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<void> clearCompletedDownloads() async {
    final completed = completedDownloads.map((d) => d.id).toList();
    for (final id in completed) {
      _downloads.remove(id);
    }
    await _saveDownloads();
    notifyListeners();
  }

  Future<void> clearAllDownloads({bool deleteFiles = true}) async {
    // Cancel all active downloads
    for (final id in _activeDownloads.keys.toList()) {
      await cancelDownload(id);
    }

    // Delete files if requested
    if (deleteFiles) {
      for (final download in _downloads.values) {
        if (download.filePath != null) {
          final file = File(download.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    }

    _downloads.clear();
    await _saveDownloads();
    notifyListeners();
  }
}
