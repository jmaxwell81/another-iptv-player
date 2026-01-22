import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache failed domains/URLs to avoid repeated requests
/// to hosts that are known to be down.
class FailedDomainCache {
  static final FailedDomainCache _instance = FailedDomainCache._internal();
  factory FailedDomainCache() => _instance;
  FailedDomainCache._internal();

  // In-memory cache for fast lookups
  final Map<String, DateTime> _failedDomains = {};

  // Cache duration (24 hours by default)
  static const Duration cacheDuration = Duration(hours: 24);

  // Storage key prefix
  static const String _storageKey = 'failed_domains_cache';

  bool _initialized = false;

  /// Initialize the cache from persistent storage
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getStringList(_storageKey) ?? [];

      final now = DateTime.now();
      for (final entry in storedData) {
        final parts = entry.split('|');
        if (parts.length == 2) {
          final domain = parts[0];
          final expiryTime = DateTime.tryParse(parts[1]);

          // Only add if not expired
          if (expiryTime != null && expiryTime.isAfter(now)) {
            _failedDomains[domain] = expiryTime;
          }
        }
      }

      _initialized = true;
      debugPrint('FailedDomainCache: Loaded ${_failedDomains.length} cached domains');
    } catch (e) {
      debugPrint('FailedDomainCache: Error loading cache: $e');
      _initialized = true;
    }
  }

  /// Check if a URL's domain is known to be down
  bool isDomainBlocked(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return false;

      final expiry = _failedDomains[host];
      if (expiry == null) return false;

      // Check if still valid
      if (DateTime.now().isBefore(expiry)) {
        return true;
      } else {
        // Expired, remove from cache
        _failedDomains.remove(host);
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Mark a URL's domain as failed
  Future<void> markDomainFailed(String url) async {
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return;

      // Only add if not already cached
      if (_failedDomains.containsKey(host)) return;

      final expiry = DateTime.now().add(cacheDuration);
      _failedDomains[host] = expiry;

      debugPrint('FailedDomainCache: Marked domain as failed: $host (expires: $expiry)');

      // Persist to storage
      await _saveToStorage();
    } catch (e) {
      debugPrint('FailedDomainCache: Error marking domain: $e');
    }
  }

  /// Clear all cached failed domains
  Future<void> clearCache() async {
    _failedDomains.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      debugPrint('FailedDomainCache: Cache cleared');
    } catch (e) {
      debugPrint('FailedDomainCache: Error clearing cache: $e');
    }
  }

  /// Get the count of blocked domains
  int get blockedDomainCount => _failedDomains.length;

  /// Get list of blocked domains (for display in settings)
  List<String> get blockedDomains => _failedDomains.keys.toList();

  /// Save cache to persistent storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _failedDomains.entries
          .map((e) => '${e.key}|${e.value.toIso8601String()}')
          .toList();
      await prefs.setStringList(_storageKey, entries);
    } catch (e) {
      debugPrint('FailedDomainCache: Error saving cache: $e');
    }
  }

  /// Remove expired entries and save
  Future<void> cleanupExpired() async {
    final now = DateTime.now();
    _failedDomains.removeWhere((_, expiry) => expiry.isBefore(now));
    await _saveToStorage();
  }
}
