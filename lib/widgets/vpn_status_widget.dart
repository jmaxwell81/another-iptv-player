import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/user_preferences.dart';
import '../services/vpn_detection_service.dart';

/// Position options for the VPN status widget
enum VpnStatusPosition {
  bottomLeft(0),
  bottomRight(1),
  topLeft(2),
  topRight(3);

  final int value;
  const VpnStatusPosition(this.value);

  static VpnStatusPosition fromInt(int value) {
    return VpnStatusPosition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VpnStatusPosition.bottomLeft,
    );
  }

  String get displayName {
    switch (this) {
      case VpnStatusPosition.bottomLeft:
        return 'Bottom Left';
      case VpnStatusPosition.bottomRight:
        return 'Bottom Right';
      case VpnStatusPosition.topLeft:
        return 'Top Left';
      case VpnStatusPosition.topRight:
        return 'Top Right';
    }
  }
}

/// Widget that displays VPN connection status in a corner of the screen
class VpnStatusWidget extends StatefulWidget {
  const VpnStatusWidget({super.key});

  @override
  State<VpnStatusWidget> createState() => _VpnStatusWidgetState();
}

class _VpnStatusWidgetState extends State<VpnStatusWidget> {
  final VpnDetectionService _vpnService = VpnDetectionService();
  StreamSubscription? _statusSubscription;

  VpnStatus _status = VpnStatus.initial();
  VpnStatusPosition _position = VpnStatusPosition.bottomLeft;
  double _opacity = 0.5;
  bool _showOnlyWhenDisconnected = false;
  bool _vpnCheckEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _statusSubscription = _vpnService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final vpnCheckEnabled = await UserPreferences.getVpnCheckEnabled();
    final position = await UserPreferences.getVpnStatusPosition();
    final opacity = await UserPreferences.getVpnStatusOpacity();
    final showOnlyWhenDisconnected = await UserPreferences.getVpnShowOnlyWhenDisconnected();

    if (mounted) {
      setState(() {
        _vpnCheckEnabled = vpnCheckEnabled;
        _position = VpnStatusPosition.fromInt(position);
        _opacity = opacity;
        _showOnlyWhenDisconnected = showOnlyWhenDisconnected;
        _status = _vpnService.currentStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if VPN check is disabled
    if (!_vpnCheckEnabled) {
      return const SizedBox.shrink();
    }

    // Don't show if option is enabled and VPN is connected
    if (_showOnlyWhenDisconnected && _status.isVpn) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _position == VpnStatusPosition.bottomLeft || _position == VpnStatusPosition.topLeft ? 16 : null,
      right: _position == VpnStatusPosition.bottomRight || _position == VpnStatusPosition.topRight ? 16 : null,
      top: _position == VpnStatusPosition.topLeft || _position == VpnStatusPosition.topRight ? 16 : null,
      bottom: _position == VpnStatusPosition.bottomLeft || _position == VpnStatusPosition.bottomRight ? 16 : null,
      child: Opacity(
        opacity: _opacity,
        child: _buildStatusBadge(context),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isVpn = _status.isVpn;
    final countryCode = _status.countryCode;

    return GestureDetector(
      onTap: () => _showStatusDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isVpn ? Colors.green.shade700 : Colors.red.shade700,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77), // 0.3 opacity = 77/255
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVpn ? Icons.lock : Icons.lock_open,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              countryCode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _status.isVpn ? Icons.vpn_lock : Icons.vpn_lock_outlined,
              color: _status.isVpn ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Text(_status.isVpn ? 'VPN Connected' : 'VPN Not Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status', _status.isVpn ? 'Protected' : 'Unprotected'),
            _buildDetailRow('Country', '${_status.countryName} (${_status.countryCode})'),
            _buildDetailRow('IP Address', _status.ip.isNotEmpty ? _status.ip : 'Unknown'),
            _buildDetailRow('Last Checked', _formatTime(_status.lastChecked)),
            if (_status.isError && _status.errorMessage != null)
              _buildDetailRow('Error', _status.errorMessage!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _vpnService.forceCheck();
            },
            child: const Text('Refresh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

/// Kill switch overlay that blocks interaction when VPN is not connected
class VpnKillSwitchOverlay extends StatefulWidget {
  final Widget child;

  const VpnKillSwitchOverlay({
    super.key,
    required this.child,
  });

  @override
  State<VpnKillSwitchOverlay> createState() => _VpnKillSwitchOverlayState();
}

class _VpnKillSwitchOverlayState extends State<VpnKillSwitchOverlay> {
  final VpnDetectionService _vpnService = VpnDetectionService();
  StreamSubscription? _statusSubscription;
  bool _shouldBlock = false;

  @override
  void initState() {
    super.initState();
    _updateBlockState();
    _statusSubscription = _vpnService.statusStream.listen((_) {
      _updateBlockState();
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _updateBlockState() {
    if (mounted) {
      setState(() {
        _shouldBlock = _vpnService.shouldBlockNetwork;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_shouldBlock)
          Positioned.fill(
            child: Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.vpn_lock,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'VPN Not Connected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Please connect to a VPN before playing content.\nKill switch is enabled for your protection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _vpnService.forceCheck();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple inline VPN status indicator for use in app bars or other compact spaces
class VpnStatusIndicator extends StatefulWidget {
  final double size;

  const VpnStatusIndicator({
    super.key,
    this.size = 20,
  });

  @override
  State<VpnStatusIndicator> createState() => _VpnStatusIndicatorState();
}

class _VpnStatusIndicatorState extends State<VpnStatusIndicator> {
  final VpnDetectionService _vpnService = VpnDetectionService();
  StreamSubscription? _statusSubscription;
  VpnStatus _status = VpnStatus.initial();
  bool _vpnCheckEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _statusSubscription = _vpnService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final vpnCheckEnabled = await UserPreferences.getVpnCheckEnabled();
    if (mounted) {
      setState(() {
        _vpnCheckEnabled = vpnCheckEnabled;
        _status = _vpnService.currentStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_vpnCheckEnabled) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: _status.isVpn
          ? 'VPN Connected (${_status.countryCode})'
          : 'VPN Not Connected',
      child: Icon(
        _status.isVpn ? Icons.lock : Icons.lock_open,
        size: widget.size,
        color: _status.isVpn ? Colors.green : Colors.red,
      ),
    );
  }
}
