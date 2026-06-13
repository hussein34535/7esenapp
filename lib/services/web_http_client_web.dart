import 'dart:html' as html;
import 'dart:typed_data';

Future<Map<String, dynamic>> webGet(String url,
    {Map<String, String>? headers}) async {
  final xhr = html.HttpRequest();
  xhr.open('GET', url);
  xhr.responseType = 'arraybuffer';
  xhr.timeout = 15000;
  if (headers != null) {
    headers.forEach((k, v) => xhr.setRequestHeader(k, v));
  }
  xhr.send();
  await xhr.onLoadEnd.first;

  if (xhr.status == null || xhr.status! < 200 || xhr.status! >= 300) {
    throw Exception('HTTP ${xhr.status ?? "network error"} for GET $url');
  }

  final buffer = xhr.response;
  if (buffer is! ByteBuffer) {
    throw Exception('Expected ByteBuffer response, got ${buffer.runtimeType}');
  }
  final bytes = buffer.asUint8List();

  return {
    'statusCode': xhr.status ?? 0,
    'bodyBytes': bytes,
  };
}

Future<Map<String, dynamic>> webPost(String url,
    {Map<String, String>? headers, String? body}) async {
  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  xhr.responseType = 'arraybuffer';
  xhr.timeout = 15000;
  if (headers != null) {
    headers.forEach((k, v) => xhr.setRequestHeader(k, v));
  }
  xhr.send(body);

  await xhr.onLoadEnd.first;

  if (xhr.status == null || xhr.status! < 200 || xhr.status! >= 300) {
    throw Exception('HTTP ${xhr.status ?? "network error"} for POST $url');
  }

  final buffer = xhr.response;
  if (buffer is! ByteBuffer) {
    throw Exception('Expected ByteBuffer response, got ${buffer.runtimeType}');
  }
  final bytes = buffer.asUint8List();

  return {
    'statusCode': xhr.status ?? 0,
    'bodyBytes': bytes,
  };
}
