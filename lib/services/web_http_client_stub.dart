/// Stub implementation for non-web platforms.
/// On native platforms, we use package:http directly, so these are never called.

Future<Map<String, dynamic>> webGet(String url,
    {Map<String, String>? headers}) async {
  throw UnsupportedError('webGet is only available on web');
}

Future<Map<String, dynamic>> webPost(String url,
    {Map<String, String>? headers, String? body}) async {
  throw UnsupportedError('webPost is only available on web');
}
