import 'dart:html' as html;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

Future<String> uploadMultipartWeb(
  String cloudName,
  String uploadPreset,
  XFile imageFile,
) async {
  final bytes = await imageFile.readAsBytes();
  final blob = html.Blob([bytes], imageFile.mimeType ?? 'image/jpeg');

  final formData = html.FormData();
  formData.append('upload_preset', uploadPreset);
  formData.append('folder', 'hesen_tv/profiles');
  formData.appendBlob('file', blob, imageFile.name);

  final url = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  final response = await html.HttpRequest.request(
    url,
    method: 'POST',
    sendData: formData,
  );

  if (response.status == 200 || response.status == 201) {
    final Map<String, dynamic> data = json.decode(response.responseText ?? '{}');
    return data['secure_url'] as String;
  } else {
    throw Exception(
      'Cloudinary Upload Failed: HTTP ${response.status} - ${response.responseText}',
    );
  }
}
