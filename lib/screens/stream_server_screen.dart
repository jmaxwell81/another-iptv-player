import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/network_discovery_service.dart';
import '../services/player_state.dart';
import '../services/service_locator.dart';
import '../services/stream_server.dart';

class StreamServerScreen extends StatefulWidget {
  const StreamServerScreen({super.key});

  @override
  State<StreamServerScreen> createState() => _StreamServerScreenState();
}

class _StreamServerScreenState extends State<StreamServerScreen> {
  StreamServer get _streamServer => getIt<StreamServer>();
  NetworkDiscoveryService get _discoveryService =>
      getIt<NetworkDiscoveryService>();

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh UI periodically to update connected clients
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _stopStreaming() async {
    await _discoveryService.unregisterService();
    await _streamServer.stop();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _streamServer.serverUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _streamServer.isRunning;
    final currentContent = PlayerState.currentContent;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Network Streaming'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isRunning)
            TextButton.icon(
              onPressed: _stopStreaming,
              icon: const Icon(Icons.stop, color: Colors.red),
              label: const Text(
                'Stop',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: isRunning
          ? _buildActiveStreamContent(currentContent)
          : _buildInactiveContent(),
    );
  }

  Widget _buildActiveStreamContent(dynamic currentContent) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Streaming Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Current content info
            if (currentContent != null) ...[
              if (currentContent.imagePath != null &&
                  currentContent.imagePath.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    currentContent.imagePath,
                    width: 120,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.white54),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                currentContent.name ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: _streamServer.serverUrl,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // URL display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Stream URL',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SelectableText(
                          _streamServer.serverUrl,
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _copyUrl,
                        icon: const Icon(Icons.copy, color: Colors.white54),
                        tooltip: 'Copy URL',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Network info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'IP Address',
                    _streamServer.localIpAddress,
                    Icons.wifi,
                  ),
                  const Divider(color: Colors.white24),
                  _buildInfoRow(
                    'Port',
                    _streamServer.port.toString(),
                    Icons.settings_ethernet,
                  ),
                  const Divider(color: Colors.white24),
                  _buildInfoRow(
                    'mDNS',
                    _discoveryService.isRegistered
                        ? 'Registered'
                        : 'Not Available',
                    Icons.dns,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Connected clients
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.devices, color: Colors.white54),
                      const SizedBox(width: 8),
                      const Text(
                        'Connected Clients',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_streamServer.connectedClients.length}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_streamServer.connectedClients.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...(_streamServer.connectedClients.map(
                      (client) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_android,
                              color: Colors.white38,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              client,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'No devices connected yet',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to connect:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Open the companion app on your Apple TV\n'
                    '2. Your desktop will be discovered automatically\n'
                    '3. Or scan the QR code with any device\n'
                    '4. Or enter the URL manually in a media player',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white54),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cast,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          const Text(
            'Stream Not Active',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start playback and tap the cast button\nto stream to other devices',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
