import 'package:flutter/services.dart';

/// Service for storing binary files (images) in the iCloud ubiquity container.
/// Scoped per Apple ID. Files are materialized on demand on other devices.
class ICloudFileService {
  static const _channel = MethodChannel('com.sj.oracle/icloud_files');

  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Copy a local file into the ubiquity container at `relPath`.
  static Future<bool> writeFile({required String relPath, required String srcPath}) async {
    try {
      return await _channel.invokeMethod<bool>('writeFile', {
        'relPath': relPath,
        'srcPath': srcPath,
      }) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Copy a file from the ubiquity container to `dstPath` (triggers download if needed).
  static Future<bool> readFileTo({required String relPath, required String dstPath}) async {
    try {
      return await _channel.invokeMethod<bool>('readFileTo', {
        'relPath': relPath,
        'dstPath': dstPath,
      }) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> fileExists(String relPath) async {
    try {
      return await _channel.invokeMethod<bool>('fileExists', {'relPath': relPath}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteFile(String relPath) async {
    try {
      return await _channel.invokeMethod<bool>('deleteFile', {'relPath': relPath}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
