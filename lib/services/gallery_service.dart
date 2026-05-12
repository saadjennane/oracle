import 'dart:io';
import 'dart:typed_data';
import 'package:image_gallery_saver/image_gallery_saver.dart';

/// Service for saving images to the photo gallery with optional fake timestamp.
class GalleryService {
  /// Save image file to gallery.
  /// Returns true on success.
  static Future<bool> saveToGallery(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return false;
      final bytes = await file.readAsBytes();
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        name: 'oracle_${DateTime.now().millisecondsSinceEpoch}',
      );
      return result['isSuccess'] == true;
    } catch (_) {
      return false;
    }
  }
}
