import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'icloud_file_service.dart';

/// Stores bank images locally AND in the iCloud ubiquity container so they
/// sync across devices. Filenames are content-addressed (sha1 of bytes) so
/// the same image picked on another device converges to the same path.
class BankImageStore {
  static const _subdir = 'bank_images';

  /// Imports a file from any source path into the store and returns the
  /// local cache path to persist in the preset's `bankImages` map.
  /// The path is a valid local file URL (points to Application Documents).
  static Future<String> importFromSource(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final ext = p.extension(sourcePath).toLowerCase().isEmpty
        ? '.png'
        : p.extension(sourcePath).toLowerCase();
    final hash = sha1.convert(bytes).toString();
    final filename = '$hash$ext';

    final docs = await getApplicationDocumentsDirectory();
    final localDir = Directory(p.join(docs.path, _subdir));
    if (!localDir.existsSync()) localDir.createSync(recursive: true);
    final localPath = p.join(localDir.path, filename);

    if (!File(localPath).existsSync()) {
      await File(sourcePath).copy(localPath);
    }

    // Push to iCloud container (best-effort).
    await ICloudFileService.writeFile(
      relPath: '$_subdir/$filename',
      srcPath: localPath,
    );

    return localPath;
  }

  /// Resolves an image path for rendering. If the stored path is missing
  /// locally, attempts to restore it from the iCloud container.
  /// Returns the resolved local path (may equal input) or null if unresolved.
  static Future<String?> resolveForRead(String storedPath) async {
    if (File(storedPath).existsSync()) return storedPath;

    // Try to find by filename in iCloud container.
    final filename = p.basename(storedPath);
    final relPath = '$_subdir/$filename';
    if (!await ICloudFileService.fileExists(relPath)) return null;

    final docs = await getApplicationDocumentsDirectory();
    final localDir = Directory(p.join(docs.path, _subdir));
    if (!localDir.existsSync()) localDir.createSync(recursive: true);
    final dstPath = p.join(localDir.path, filename);

    final ok = await ICloudFileService.readFileTo(
      relPath: relPath,
      dstPath: dstPath,
    );
    return ok ? dstPath : null;
  }

  /// Computes the relative path used in the iCloud container for a local path.
  static String? relPathForLocal(String localPath) {
    final filename = p.basename(localPath);
    if (filename.isEmpty) return null;
    return '$_subdir/$filename';
  }

  /// Unused — exported in case future cleanup wants to enumerate.
  static String jsonEncodeForDebug(Map<String, String> m) => jsonEncode(m);
}
