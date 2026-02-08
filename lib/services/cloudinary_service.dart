import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String _cloudName = 'djxkwged9';
  static const String _apiKey = '995382833695689';
  static const String _apiSecret = 'Y4zFQM1fFjBpNjSv7PpswVMhA8Q';

  static Future<String> uploadImage(XFile imageFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Generate Signature
    final paramsToSign = 'timestamp=$timestamp$_apiSecret';
    final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

    // 2. Prepare Request
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);

    request.fields['api_key'] = _apiKey;
    request.fields['timestamp'] = timestamp.toString();
    request.fields['signature'] = signature;

    // Add the file (Web-compatible: use bytes)
    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: imageFile.name,
    ));

    // 3. Send
    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final jsonResponse = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonResponse['secure_url'];
    } else {
      throw Exception(
          'Cloudinary Upload Failed: ${jsonResponse['error']['message']}');
    }
  }
}
