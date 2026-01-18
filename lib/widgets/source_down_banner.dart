import 'dart:async';
import 'package:flutter/material.dart';
import '../services/source_health_service.dart';

/// Banner widget that displays when IPTV sources are unavailable
class SourceDownBanner extends StatefulWidget {
  const SourceDownBanner({super.key});

  @override
  State<SourceDownBanner> createState() => _SourceDownBannerState();
}

class _SourceDownBannerState extends State<SourceDownBanner> {
  final SourceHealthService _healthService = SourceHealthService();
  List<SourceHealthStatus> _unavailableSources = [];
  StreamSubscription? _statusSubscription;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUnavailableSources();
    _statusSubscription = _healthService.statusStream.listen((status) {
      _loadUnavailableSources();
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _loadUnavailableSources() {
    if (!mounted) return;
    setState(() {
      _unavailableSources = _healthService.getUnavailableSources();
    });
  }

  String _formatTimeSince(DateTime? time) {
    if (time == null) return 'Unknown';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _triggerRecoveryCheck(String sourceId) {
    _healthService.triggerRecoveryCheck(sourceId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking source availability...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailableSources.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade800,
              Colors.red.shade700,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main banner row
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _unavailableSources.length == 1
                                  ? 'Source Unavailable'
                                  : '${_unavailableSources.length} Sources Unavailable',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (!_isExpanded && _unavailableSources.length == 1)
                              Text(
                                _unavailableSources.first.sourceName,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded details
              if (_isExpanded)
                Container(
                  color: Colors.black.withOpacity(0.1),
                  child: Column(
                    children: _unavailableSources.map((source) {
                      return _buildSourceItem(source);
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceItem(SourceHealthStatus source) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.sourceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source.lastErrorMessage ?? 'Connection failed',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 11,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Down since ${_formatTimeSince(source.lastError)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.error_outline,
                      size: 11,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${source.errorCount} errors',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: () => _triggerRecoveryCheck(source.sourceId),
            tooltip: 'Check availability',
          ),
        ],
      ),
    );
  }
}

/// A compact inline version of the source down indicator
/// for use in list items and cards
class SourceDownIndicator extends StatelessWidget {
  final String sourceId;
  final double size;

  const SourceDownIndicator({
    super.key,
    required this.sourceId,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final healthService = SourceHealthService();
    final isAvailable = healthService.isSourceAvailable(sourceId);

    if (isAvailable) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'Source unavailable',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.block,
          color: Colors.white,
          size: size * 0.7,
        ),
      ),
    );
  }
}
