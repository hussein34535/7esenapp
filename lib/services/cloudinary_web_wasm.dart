import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

Future<String> uploadMultipartWeb(
  String cloudName,
  String uploadPreset,
  XFile imageFile,
) async {
  final bytes = await imageFile.readAsBytes();

  // Create native JS Blob from bytes
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: imageFile.mimeType ?? 'image/jpeg'),
  );

  final formData = web.FormData();
  formData.append('upload_preset', uploadPreset.toJS);
  formData.append('folder', 'hesen_tv/profiles'.toJS);
  formData.append('file', blob, imageFile.name);

  web.console.log('[Cloudinary Web WASM] Uploading image...'.toJS);
  web.console.log('[Cloudinary Web WASM] Cloud Name: $cloudName'.toJS);
  web.console.log('[Cloudinary Web WASM] Upload Preset: $uploadPreset'.toJS);

  final url = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  final requestInit = web.RequestInit(
    method: 'POST',
    body: formData,
  );

  final response = await web.window.fetch(url.toJS, requestInit).toDart;
  final responseText = (await response.text().toDart).toDart;

  if (response.status == 200 || response.status == 201) {
    final Map<String, dynamic> data = json.decode(responseText);
    return data['secure_url'] as String;
  } else {
    throw Exception(
      'Cloudinary Upload Failed: HTTP ${response.status} - $responseText',
    );
  }
}
