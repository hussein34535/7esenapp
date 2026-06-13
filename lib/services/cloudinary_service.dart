import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static const String _cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'djxkwged9',
  );
  static const String _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  static Future<String> uploadImage(XFile imageFile) async {
    if (_uploadPreset.isEmpty) {
      throw Exception(
        'Cloudinary upload preset is not configured. Set CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = 'hesen_tv/profiles';

    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: imageFile.name,
    ));

    final response = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final responseData = await response.stream.bytesToString().timeout(
      const Duration(seconds: 10),
    );
    final jsonResponse = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonResponse['secure_url'] as String;
    } else {
      final error = jsonResponse['error']?['message']?.toString() ?? responseData;
      debugPrint('Cloudinary Upload Failed: $error');
      throw Exception('Cloudinary Upload Failed: $error');
    }
  }
}
