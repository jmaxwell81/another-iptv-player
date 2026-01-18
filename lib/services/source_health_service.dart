import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/user_preferences.dart';
import 'event_bus.dart';

/// Types of stream errors that affect source health
enum StreamErrorType {
  dns,        // DNS resolution failed
  http4xx,    // 4xx HTTP errors (client errors)
  http5xx,    // 5xx HTTP errors (server errors)
  timeout,    // Connection timeout
  connection, // General connection errors
}

/// Represents a single stream error
class StreamError {
  final String sourceId;
  final String streamId;
  final StreamErrorType type;
  final String message;
  final DateTime timestamp;

  StreamError({
    required this.sourceId,
    required this.streamId,
    required this.type,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Represents the health status of a source
class SourceHealthStatus {
  final String sourceId;
  final String sourceName;
  final bool isAvailable;
  final int errorCount;
  final DateTime? lastError;
  final DateTime? lastSuccessfulConnection;
  final String? lastErrorMessage;

  SourceHealthStatus({
    required this.sourceId,
    required this.sourceName,
    this.isAvailable = true,
    this.errorCount = 0,
    this.lastError,
    this.lastSuccessfulConnection,
    this.lastErrorMessage,
  });

  SourceHealthStatus copyWith({
    String? sourceId,
    String? sourceName,
    bool? isAvailable,
    int? errorCount,
    DateTime? lastError,
    DateTime? lastSuccessfulConnection,
    String? lastErrorMessage,
  }) {
    return SourceHealthStatus(
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      isAvailable: isAvailable ?? this.isAvailable,
      errorCount: errorCount ?? this.errorCount,
      lastError: lastError ?? this.lastError,
      lastSuccessfulConnection: lastSuccessfulConnection ?? this.lastSuccessfulConnection,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
    );
  }
}

/// Event emitted when source health status changes
class SourceHealthChangedEvent {
  final SourceHealthStatus status;
  SourceHealthChangedEvent(this.status);
}

/// Service to monitor and track IPTV source health
class SourceHealthService {
  static final SourceHealthService _instance = SourceHealthService._internal();
  factory SourceHealthService() => _instance;
  SourceHealthService._internal();

  // Configuration
  int _errorThreshold = 3; // Number of errors before marking source as down
  Duration _errorWindow = const Duration(minutes: 2); // Time window for counting errors
  Duration _recoveryCheckInterval = const Duration(seconds: 60);

  // State
  final Map<String, List<StreamError>> _errorHistory = {};
  final Map<String, SourceHealthStatus> _sourceStatus = {};
  final Map<String, Timer> _recoveryTimers = {};
  final Map<String, String> _sourceNames = {};

  // Stream controller for status changes
  final _statusController = StreamController<SourceHealthStatus>.broadcast();
  Stream<SourceHealthStatus> get statusStream => _statusController.stream;

  /// Initialize the service and load configuration
  Future<void> initialize() async {
    _errorThreshold = await UserPreferences.getSourceErrorThreshold();
    final windowMinutes = await UserPreferences.getSourceErrorWindowMinutes();
    _errorWindow = Duration(minutes: windowMinutes);
  }

  /// Register a source with its name for display purposes
  void registerSource(String sourceId, String sourceName) {
    _sourceNames[sourceId] = sourceName;
    if (!_sourceStatus.containsKey(sourceId)) {
      _sourceStatus[sourceId] = SourceHealthStatus(
        sourceId: sourceId,
        sourceName: sourceName,
        isAvailable: true,
      );
    }
  }

  /// Report a stream error
  void reportError(StreamError error) {
    // Add to error history
    _errorHistory.putIfAbsent(error.sourceId, () => []);
    _errorHistory[error.sourceId]!.add(error);

    // Clean up old errors outside the window
    _cleanupOldErrors(error.sourceId);

    // Check if threshold exceeded
    final recentErrors = _errorHistory[error.sourceId]!;
    final currentStatus = _sourceStatus[error.sourceId];

    if (recentErrors.length >= _errorThreshold && (currentStatus?.isAvailable ?? true)) {
      _markSourceUnavailable(error.sourceId, error.message);
    } else {
      // Update error count without marking as unavailable
      _updateSourceStatus(error.sourceId, errorCount: recentErrors.length, lastErrorMessage: error.message);
    }

    // Emit event for UI updates
    EventBus().emit('stream_error', error);
  }

  /// Report a successful stream connection
  void reportSuccess(String sourceId) {
    _errorHistory[sourceId]?.clear();

    final wasUnavailable = !(_sourceStatus[sourceId]?.isAvailable ?? true);

    _sourceStatus[sourceId] = SourceHealthStatus(
      sourceId: sourceId,
      sourceName: _sourceNames[sourceId] ?? sourceId,
      isAvailable: true,
      errorCount: 0,
      lastSuccessfulConnection: DateTime.now(),
    );

    if (wasUnavailable) {
      _stopRecoveryTimer(sourceId);
      _statusController.add(_sourceStatus[sourceId]!);
      EventBus().emit('source_restored', _sourceStatus[sourceId]);
    }
  }

  /// Get current health status for a source
  SourceHealthStatus? getSourceStatus(String sourceId) {
    return _sourceStatus[sourceId];
  }

  /// Get all source statuses
  Map<String, SourceHealthStatus> getAllSourceStatuses() {
    return Map.unmodifiable(_sourceStatus);
  }

  /// Check if a source is currently available
  bool isSourceAvailable(String sourceId) {
    return _sourceStatus[sourceId]?.isAvailable ?? true;
  }

  /// Get list of unavailable sources
  List<SourceHealthStatus> getUnavailableSources() {
    return _sourceStatus.values
        .where((status) => !status.isAvailable)
        .toList();
  }

  void _cleanupOldErrors(String sourceId) {
    final cutoff = DateTime.now().subtract(_errorWindow);
    _errorHistory[sourceId]?.removeWhere((error) => error.timestamp.isBefore(cutoff));
  }

  void _markSourceUnavailable(String sourceId, String lastError) {
    final status = SourceHealthStatus(
      sourceId: sourceId,
      sourceName: _sourceNames[sourceId] ?? sourceId,
      isAvailable: false,
      errorCount: _errorHistory[sourceId]?.length ?? 0,
      lastError: DateTime.now(),
      lastErrorMessage: lastError,
    );

    _sourceStatus[sourceId] = status;
    _statusController.add(status);
    EventBus().emit('source_unavailable', status);

    // Start recovery timer
    _startRecoveryTimer(sourceId);
  }

  void _updateSourceStatus(String sourceId, {int? errorCount, String? lastErrorMessage}) {
    final current = _sourceStatus[sourceId];
    if (current != null) {
      _sourceStatus[sourceId] = current.copyWith(
        errorCount: errorCount,
        lastError: DateTime.now(),
        lastErrorMessage: lastErrorMessage,
      );
    }
  }

  void _startRecoveryTimer(String sourceId) {
    _stopRecoveryTimer(sourceId);

    _recoveryTimers[sourceId] = Timer.periodic(_recoveryCheckInterval, (timer) {
      _attemptRecovery(sourceId);
    });
  }

  void _stopRecoveryTimer(String sourceId) {
    _recoveryTimers[sourceId]?.cancel();
    _recoveryTimers.remove(sourceId);
  }

  Future<void> _attemptRecovery(String sourceId) async {
    // This will be called by the health check mechanism
    // The actual check is done by trying to connect to the source
    EventBus().emit('source_recovery_attempt', sourceId);
  }

  /// Manually trigger a recovery check for a source
  Future<void> triggerRecoveryCheck(String sourceId) async {
    await _attemptRecovery(sourceId);
  }

  /// Parse error message and determine error type
  static StreamErrorType categorizeError(String errorMessage) {
    final lowerMessage = errorMessage.toLowerCase();

    if (lowerMessage.contains('dns') ||
        lowerMessage.contains('resolve') ||
        lowerMessage.contains('hostname') ||
        lowerMessage.contains('nodename nor servname')) {
      return StreamErrorType.dns;
    }

    if (lowerMessage.contains('404') ||
        lowerMessage.contains('403') ||
        lowerMessage.contains('401') ||
        lowerMessage.contains('400')) {
      return StreamErrorType.http4xx;
    }

    if (lowerMessage.contains('500') ||
        lowerMessage.contains('502') ||
        lowerMessage.contains('503') ||
        lowerMessage.contains('522')) {
      return StreamErrorType.http5xx;
    }

    if (lowerMessage.contains('timeout') ||
        lowerMessage.contains('timed out')) {
      return StreamErrorType.timeout;
    }

    return StreamErrorType.connection;
  }

  /// Get a user-friendly error message
  static String getFriendlyErrorMessage(StreamErrorType type, String? originalMessage) {
    switch (type) {
      case StreamErrorType.dns:
        return 'Unable to reach server - DNS lookup failed';
      case StreamErrorType.http4xx:
        return 'Stream not available - Access denied or not found';
      case StreamErrorType.http5xx:
        return 'Server error - The streaming server is having issues';
      case StreamErrorType.timeout:
        return 'Connection timed out - Server not responding';
      case StreamErrorType.connection:
        return 'Connection failed - Check your network';
    }
  }

  void dispose() {
    for (final timer in _recoveryTimers.values) {
      timer.cancel();
    }
    _recoveryTimers.clear();
    _statusController.close();
  }
}
