import 'dart:convert';
import 'package:http/http.dart' as http;

/// Uploads decoy images to Cloudinary using the unsigned upload preset
/// `oracle_decoy` on the cloud `dusneyzup`. Returns the public secure_url
/// on success, or null on failure.
class CloudinaryService {
  static const String _cloudName = 'dusneyzup';
  static const String _uploadPreset = 'oracle_decoy';

  static Future<String?> uploadDecoyImage(String filePath) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String?;
    } catch (_) {
      return null;
    }
  }
}
