import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../repositories/user_preferences.dart';
import 'event_bus.dart';

/// Represents the current VPN status
class VpnStatus {
  final bool isVpn;
  final String countryCode;
  final String countryName;
  final String ip;
  final DateTime lastChecked;
  final bool isError;
  final String? errorMessage;

  const VpnStatus({
    required this.isVpn,
    required this.countryCode,
    required this.countryName,
    required this.ip,
    required this.lastChecked,
    this.isError = false,
    this.errorMessage,
  });

  factory VpnStatus.initial() {
    return VpnStatus(
      isVpn: false,
      countryCode: '--',
      countryName: 'Unknown',
      ip: '',
      lastChecked: DateTime.now(),
      isError: false,
    );
  }

  factory VpnStatus.error(String message) {
    return VpnStatus(
      isVpn: false,
      countryCode: '--',
      countryName: 'Unknown',
      ip: '',
      lastChecked: DateTime.now(),
      isError: true,
      errorMessage: message,
    );
  }

  VpnStatus copyWith({
    bool? isVpn,
    String? countryCode,
    String? countryName,
    String? ip,
    DateTime? lastChecked,
    bool? isError,
    String? errorMessage,
  }) {
    return VpnStatus(
      isVpn: isVpn ?? this.isVpn,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      ip: ip ?? this.ip,
      lastChecked: lastChecked ?? this.lastChecked,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Event emitted when VPN status changes
class VpnStatusChangedEvent {
  final VpnStatus status;
  VpnStatusChangedEvent(this.status);
}

/// Service to detect VPN connection and manage kill switch
class VpnDetectionService {
  static final VpnDetectionService _instance = VpnDetectionService._internal();
  factory VpnDetectionService() => _instance;
  VpnDetectionService._internal();

  // Configuration
  Duration _checkInterval = const Duration(minutes: 5);
  bool _killSwitchEnabled = false;
  bool _vpnCheckEnabled = false;

  // State
  VpnStatus _currentStatus = VpnStatus.initial();
  Timer? _checkTimer;
  bool _isChecking = false;

  // Stream controller for status changes
  final _statusController = StreamController<VpnStatus>.broadcast();
  Stream<VpnStatus> get statusStream => _statusController.stream;

  VpnStatus get currentStatus => _currentStatus;
  bool get isVpnConnected => _currentStatus.isVpn;
  bool get killSwitchEnabled => _killSwitchEnabled;
  bool get vpnCheckEnabled => _vpnCheckEnabled;

  /// Check if network access should be blocked
  bool get shouldBlockNetwork => _vpnCheckEnabled && _killSwitchEnabled && !_currentStatus.isVpn;

  /// Initialize the service and load configuration
  Future<void> initialize() async {
    _vpnCheckEnabled = await UserPreferences.getVpnCheckEnabled();
    _killSwitchEnabled = await UserPreferences.getVpnKillSwitchEnabled();
    final intervalMinutes = await UserPreferences.getVpnCheckIntervalMinutes();
    _checkInterval = Duration(minutes: intervalMinutes);

    if (_vpnCheckEnabled) {
      await checkVpnStatus();
      _startPeriodicCheck();
    }
  }

  /// Manually check VPN status
  Future<VpnStatus> checkVpnStatus() async {
    if (_isChecking) return _currentStatus;
    _isChecking = true;

    try {
      // Try primary API (ipapi.co)
      final status = await _checkWithIpApi();
      _updateStatus(status);
      return status;
    } catch (e) {
      // Try fallback API (ip-api.com)
      try {
        final status = await _checkWithIpApiCom();
        _updateStatus(status);
        return status;
      } catch (e2) {
        final errorStatus = VpnStatus.error('Failed to check VPN status: $e2');
        _updateStatus(errorStatus);
        return errorStatus;
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Check VPN status using ipapi.co
  Future<VpnStatus> _checkWithIpApi() async {
    final response = await http.get(
      Uri.parse('https://ipapi.co/json/'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // ipapi.co provides 'org' field which often contains VPN provider names
      // and 'asn' which can help identify VPN/datacenter IPs
      final org = (data['org'] ?? '').toString().toLowerCase();
      final asn = (data['asn'] ?? '').toString().toLowerCase();

      // Common VPN/proxy indicators in org/asn
      final vpnIndicators = [
        'vpn', 'proxy', 'hosting', 'datacenter', 'data center',
        'cloud', 'digital ocean', 'amazon', 'aws', 'azure',
        'google cloud', 'linode', 'vultr', 'ovh', 'hetzner',
        'nordvpn', 'expressvpn', 'surfshark', 'cyberghost',
        'private internet access', 'pia', 'mullvad', 'protonvpn',
      ];

      bool isVpn = vpnIndicators.any((indicator) =>
        org.contains(indicator) || asn.contains(indicator));

      return VpnStatus(
        isVpn: isVpn,
        countryCode: data['country_code'] ?? '--',
        countryName: data['country_name'] ?? 'Unknown',
        ip: data['ip'] ?? '',
        lastChecked: DateTime.now(),
      );
    } else {
      throw Exception('API returned ${response.statusCode}');
    }
  }

  /// Check VPN status using ip-api.com (fallback)
  Future<VpnStatus> _checkWithIpApiCom() async {
    final response = await http.get(
      Uri.parse('http://ip-api.com/json/?fields=status,country,countryCode,query,proxy,hosting'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // ip-api.com provides proxy and hosting flags
        final isProxy = data['proxy'] == true;
        final isHosting = data['hosting'] == true;

        return VpnStatus(
          isVpn: isProxy || isHosting,
          countryCode: data['countryCode'] ?? '--',
          countryName: data['country'] ?? 'Unknown',
          ip: data['query'] ?? '',
          lastChecked: DateTime.now(),
        );
      }
    }
    throw Exception('Fallback API failed');
  }

  void _updateStatus(VpnStatus status) {
    final previousStatus = _currentStatus;
    _currentStatus = status;
    _statusController.add(status);

    // Emit event for UI updates
    EventBus().emit('vpn_status_changed', status);

    // Log status change
    if (previousStatus.isVpn != status.isVpn) {
      debugPrint('VPN Status Changed: ${status.isVpn ? "Connected" : "Disconnected"} (${status.countryCode})');
    }
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_checkInterval, (_) {
      checkVpnStatus();
    });
  }

  void _stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Enable or disable VPN checking
  Future<void> setVpnCheckEnabled(bool enabled) async {
    _vpnCheckEnabled = enabled;
    await UserPreferences.setVpnCheckEnabled(enabled);

    if (enabled) {
      await checkVpnStatus();
      _startPeriodicCheck();
    } else {
      _stopPeriodicCheck();
    }
  }

  /// Enable or disable kill switch
  Future<void> setKillSwitchEnabled(bool enabled) async {
    _killSwitchEnabled = enabled;
    await UserPreferences.setVpnKillSwitchEnabled(enabled);
    EventBus().emit('vpn_kill_switch_changed', enabled);
  }

  /// Set check interval in minutes
  Future<void> setCheckInterval(int minutes) async {
    _checkInterval = Duration(minutes: minutes);
    await UserPreferences.setVpnCheckIntervalMinutes(minutes);

    if (_vpnCheckEnabled) {
      _startPeriodicCheck();
    }
  }

  /// Force an immediate VPN check
  Future<VpnStatus> forceCheck() async {
    return await checkVpnStatus();
  }

  void dispose() {
    _checkTimer?.cancel();
    _statusController.close();
  }
}
