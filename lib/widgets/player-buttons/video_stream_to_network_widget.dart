import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/network_discovery_service.dart';
import '../../services/service_locator.dart';
import '../../services/stream_server.dart';

class VideoStreamToNetworkWidget extends StatefulWidget {
  const VideoStreamToNetworkWidget({super.key});

  @override
  State<VideoStreamToNetworkWidget> createState() =>
      _VideoStreamToNetworkWidgetState();
}

class _VideoStreamToNetworkWidgetState
    extends State<VideoStreamToNetworkWidget> {
  StreamServer get _streamServer => getIt<StreamServer>();
  NetworkDiscoveryService get _discoveryService =>
      getIt<NetworkDiscoveryService>();

  bool _isStreaming = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isStreaming = _streamServer.isRunning;
  }

  Future<void> _toggleStreaming() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isStreaming) {
        await _stopStreaming();
      } else {
        await _startStreaming();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startStreaming() async {
    // Update stream info from current player state
    _streamServer.updateFromPlayerState();

    // Start the HTTP server
    await _streamServer.start();

    // Register mDNS service
    await _discoveryService.registerService(
      name: NetworkDiscoveryService.serviceName,
      port: _streamServer.port,
    );

    setState(() {
      _isStreaming = true;
    });

    if (mounted) {
      _showStreamingDialog();
    }
  }

  Future<void> _stopStreaming() async {
    await _discoveryService.unregisterService();
    await _streamServer.stop();

    setState(() {
      _isStreaming = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stream stopped'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showStreamingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.cast, color: Colors.green[400]),
            const SizedBox(width: 8),
            const Text(
              'Streaming Active',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your stream is now available on the local network.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stream URL:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _streamServer.serverUrl,
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Open the companion app on your Apple TV or enter this URL on any device.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/stream-server');
            },
            child: const Text('Show QR Code'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show on desktop platforms
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              _isStreaming ? Icons.cast_connected : Icons.cast,
              color: _isStreaming ? Colors.green[400] : Colors.white,
            ),
      onPressed: _isLoading ? null : _toggleStreaming,
      tooltip: _isStreaming ? 'Stop Streaming' : 'Stream to Network',
    );
  }
}
