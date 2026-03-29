import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'dart:async';

Future<Map<String, dynamic>> webGet(String url,
    {Map<String, String>? headers}) async {
  final requestInit = web.RequestInit(method: 'GET');
  if (headers != null) {
    final jsHeaders = JSObject();
    headers.forEach((key, value) {
      jsHeaders.setProperty(key.toJS, value.toJS);
    });
    requestInit.headers = jsHeaders;
  }

  final response = await web.window.fetch(url.toJS, requestInit).toDart;
  final arrayBuffer = await response.arrayBuffer().toDart;
  
  // Return raw bytes to avoid string encoding issues between JS and Dart WASM
  final bytes = arrayBuffer.toDart.asUint8List();

  return {
    'statusCode': response.status,
    'bodyBytes': bytes,
  };
}

Future<Map<String, dynamic>> webPost(String url,
    {Map<String, String>? headers, String? body}) async {
  final requestInit = web.RequestInit(method: 'POST');
  if (headers != null) {
    final jsHeaders = JSObject();
    headers.forEach((key, value) {
      jsHeaders.setProperty(key.toJS, value.toJS);
    });
    requestInit.headers = jsHeaders;
  }
  if (body != null) {
    requestInit.body = body.toJS;
  }

  final response = await web.window.fetch(url.toJS, requestInit).toDart;
  final arrayBuffer = await response.arrayBuffer().toDart;
  
  final bytes = arrayBuffer.toDart.asUint8List();

  return {
    'statusCode': response.status,
    'bodyBytes': bytes,
  };
}
