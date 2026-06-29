import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Fill these in after creating your free Cloudinary account.
// Sign up at: https://cloudinary.com/users/register/free
// Then: Settings → Upload → Upload presets → Add upload preset
//   - Signing mode: Unsigned
//   - Copy the preset name into kUploadPreset
// Your cloud name is on the Dashboard homepage.
const String kCloudName = 'd0ydih2n';
const String kUploadPreset = 'two_hearts_uploads';

class CloudinaryService {
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// Uploads [bytes] and returns the secure URL.
  static Future<String> uploadImage(Uint8List bytes, {String folder = 'two_hearts'}) async {
    final uri = Uri.parse('$_baseUrl/$kCloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = kUploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

    final response = await request.send();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Cloudinary upload failed: $body');
    }

    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  /// Uploads a video [file] to Cloudinary and returns the secure URL.
  static Future<String> uploadVideo(File file, {String folder = 'two_hearts'}) async {
    final uri = Uri.parse('$_baseUrl/$kCloudName/video/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = kUploadPreset
      ..fields['folder'] = folder
      ..fields['resource_type'] = 'video'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: '${DateTime.now().millisecondsSinceEpoch}.mp4',
      ));

    final response = await request.send();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Cloudinary video upload failed: $body');
    }

    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }
}
