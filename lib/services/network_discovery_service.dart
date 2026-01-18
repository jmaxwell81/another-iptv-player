import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nsd/nsd.dart';

class NetworkDiscoveryService {
  static const String serviceType = '_iptv-stream._tcp';
  static const String serviceName = 'Another IPTV Player';

  Registration? _registration;
  bool _isRegistered = false;
  Discovery? _discovery;

  bool get isRegistered => _isRegistered;

  Future<void> registerService({
    required String name,
    required int port,
    String? host,
  }) async {
    if (_isRegistered) {
      await unregisterService();
    }

    try {
      // Only register on supported platforms
      if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
        return;
      }

      final service = Service(
        name: name,
        type: serviceType,
        port: port,
        host: host,
        txt: {
          'version': utf8.encode('1.0'),
          'app': utf8.encode('another-iptv-player'),
        },
      );

      _registration = await register(service);
      _isRegistered = true;
    } catch (e) {
      _isRegistered = false;
    }
  }

  Future<void> unregisterService() async {
    if (_registration != null) {
      try {
        await unregister(_registration!);
      } catch (e) {
        // Silently handle errors during unregistration
      }
      _registration = null;
    }
    _isRegistered = false;
  }

  Future<List<Service>> discoverServices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final discoveredServices = <Service>[];
    final completer = Completer<List<Service>>();

    try {
      _discovery = await startDiscovery(serviceType);

      _discovery!.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          discoveredServices.add(service);
        }
      });

      // Wait for timeout
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(discoveredServices);
        }
      });

      return await completer.future;
    } catch (e) {
      return discoveredServices;
    } finally {
      await stopDiscovery(_discovery!);
    }
  }

  Future<void> dispose() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
    }
    await unregisterService();
  }
}
