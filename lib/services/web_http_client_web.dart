/// Web implementation using dart:html's HttpRequest.
/// This bypasses package:http's BrowserClient which has a bug where
/// xhr.response (ArrayBuffer) is sometimes undefined, causing
/// "Cannot read properties of undefined (reading 'length')" errors.
///
/// By using HttpRequest.request() with no explicit responseType,
/// the response is read as text (responseText), which is always reliable.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<Map<String, dynamic>> webGet(String url,
    {Map<String, String>? headers}) async {
  final xhr = await html.HttpRequest.request(
    url,
    method: 'GET',
    requestHeaders: headers ?? {},
  );
  return {
    'statusCode': xhr.status ?? 0,
    'body': xhr.responseText ?? '',
  };
}

Future<Map<String, dynamic>> webPost(String url,
    {Map<String, String>? headers, String? body}) async {
  final xhr = await html.HttpRequest.request(
    url,
    method: 'POST',
    requestHeaders: headers ?? {},
    sendData: body,
  );
  return {
    'statusCode': xhr.status ?? 0,
    'body': xhr.responseText ?? '',
  };
}
