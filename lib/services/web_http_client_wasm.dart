import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:async';

Future<Map<String, dynamic>> _fetchWithTimeout(
  String url,
  web.RequestInit requestInit, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final controller = web.AbortController();
  final timer = Timer(timeout, () => controller.abort());

  try {
    requestInit.signal = controller.signal;
    final response = await web.window.fetch(url.toJS, requestInit).toDart;
    final arrayBuffer = await response.arrayBuffer().toDart;
    final bytes = arrayBuffer.toDart.asUint8List();

    return {
      'statusCode': response.status,
      'bodyBytes': bytes,
    };
  } finally {
    timer.cancel();
  }
}

Future<Map<String, dynamic>> webGet(String url,
    {Map<String, String>? headers}) async {
  final requestInit = web.RequestInit(method: 'GET');
  if (headers != null) {
    final jsHeaders = web.Headers();
    headers.forEach((key, value) {
      jsHeaders.append(key, value);
    });
    requestInit.headers = jsHeaders;
  }

  return _fetchWithTimeout(url, requestInit);
}

Future<Map<String, dynamic>> webPost(String url,
    {Map<String, String>? headers, String? body}) async {
  final requestInit = web.RequestInit(method: 'POST');
  if (headers != null) {
    final jsHeaders = web.Headers();
    headers.forEach((key, value) {
      jsHeaders.append(key, value);
    });
    requestInit.headers = jsHeaders;
  }
  if (body != null) {
    requestInit.body = body.toJS;
  }

  return _fetchWithTimeout(url, requestInit);
}
