import 'dash_helper_stub.dart'
    if (dart.library.js_interop) 'dash_helper_web.dart'
    if (dart.library.io) 'dash_helper_io.dart' as impl;

Future<String> writeDashManifestToTemp(String dataUrl) {
  return impl.writeDashManifestToTemp(dataUrl);
}
