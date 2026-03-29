import 'dart:html' as html;
import 'dart:typed_data';

Future<Map<String, dynamic>> webGet(String url,
    {Map<String, String>? headers}) async {
  final xhr = await html.HttpRequest.request(
    url,
    method: 'GET',
    requestHeaders: headers ?? {},
    responseType: 'arraybuffer',
  );
  
  final ByteBuffer buffer = xhr.response as ByteBuffer;
  final Uint8List bytes = buffer.asUint8List();

  return {
    'statusCode': xhr.status ?? 0,
    'bodyBytes': bytes,
  };
}

Future<Map<String, dynamic>> webPost(String url,
    {Map<String, String>? headers, String? body}) async {
  final xhr = await html.HttpRequest.request(
    url,
    method: 'POST',
    requestHeaders: headers ?? {},
    sendData: body,
    responseType: 'arraybuffer',
  );
  
  final ByteBuffer buffer = xhr.response as ByteBuffer;
  final Uint8List bytes = buffer.asUint8List();

  return {
    'statusCode': xhr.status ?? 0,
    'bodyBytes': bytes,
  };
}
