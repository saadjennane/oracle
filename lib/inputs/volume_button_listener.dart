import 'dart:async';
import 'package:flutter/services.dart';
import '../models/stealth_input_method.dart';

/// Listener for hardware volume button presses
///
/// Uses platform channels to intercept volume button events.
/// On iOS and Android, this requires native code to capture the events
/// before they reach the system volume handler.
class VolumeButtonListener {
  static const MethodChannel _channel = MethodChannel('com.oracle_poc/volume_buttons');

  StreamController<VolumeDirection>? _streamController;
  bool _isListening = false;

  /// Stream of volume button press events
  Stream<VolumeDirection> get onVolumeButtonPressed {
    _streamController ??= StreamController<VolumeDirection>.broadcast();
    return _streamController!.stream;
  }

  /// Start listening for volume button presses
  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      final result = await _channel.invokeMethod<bool>('startListening');
      _isListening = result ?? false;
      return _isListening;
    } on PlatformException catch (e) {
      print('Failed to start volume button listener: ${e.message}');
      return false;
    } on MissingPluginException {
      print('Volume button listener not available on this platform');
      return false;
    }
  }

  /// Stop listening for volume button presses
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      _channel.setMethodCallHandler(null);
      await _channel.invokeMethod<void>('stopListening');
      _isListening = false;
    } on PlatformException catch (e) {
      print('Failed to stop volume button listener: ${e.message}');
    } on MissingPluginException {
      // Ignore
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVolumeUp':
        _streamController?.add(VolumeDirection.up);
        break;
      case 'onVolumeDown':
        _streamController?.add(VolumeDirection.down);
        break;
      default:
        throw MissingPluginException('Unknown method: ${call.method}');
    }
  }

  /// Check if volume button listening is available on this platform
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopListening();
    await _streamController?.close();
    _streamController = null;
  }
}
