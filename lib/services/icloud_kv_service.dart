import 'dart:async';
import 'package:flutter/services.dart';

/// Service for syncing data via iCloud Key-Value Store (NSUbiquitousKeyValueStore).
/// Falls back silently if iCloud is not available.
class ICloudKVService {
  static const _channel = MethodChannel('com.sj.oracle/icloud_kv');

  static final _externalChangeController = StreamController<void>.broadcast();
  static bool _handlerSet = false;

  /// Stream fired when iCloud detects external changes (another device pushed).
  static Stream<void> get onExternalChange {
    _ensureHandler();
    return _externalChangeController.stream;
  }

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onExternalChange') {
        _externalChangeController.add(null);
      }
      return null;
    });
  }

  /// Store a string value in iCloud KV
  static Future<bool> setString(String key, String value) async {
    try {
      return await _channel.invokeMethod('setString', {'key': key, 'value': value}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get a string value from iCloud KV
  static Future<String?> getString(String key) async {
    try {
      return await _channel.invokeMethod<String>('getString', {'key': key});
    } catch (_) {
      return null;
    }
  }

  /// Remove a key from iCloud KV
  static Future<bool> remove(String key) async {
    try {
      return await _channel.invokeMethod('remove', {'key': key}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Force sync with iCloud
  static Future<bool> synchronize() async {
    try {
      return await _channel.invokeMethod('synchronize') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check if iCloud is available
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }
}
