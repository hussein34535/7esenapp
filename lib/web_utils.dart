import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('removeSplashFromWeb')
external void _removeSplash();

@JS('eval')
external JSString? _jsEvalString(String code);

@JS('navigator.standalone')
external JSBoolean? get _navigatorStandalone;

/// True when running as an installed home-screen PWA on iOS.
/// Standalone iOS apps hard-block popups and have an isolated cookie jar,
/// so OAuth must use the redirect flow there.
bool get isIosStandalonePwa {
  try {
    return _navigatorStandalone?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

/// Enables the on-device debug logger only when ?debug=1 or ?debug=true is
/// present in the current URL.
bool shouldEnableDebugLogger() {
  try {
    final Uri uri = Uri.base;
    return uri.queryParameters['debug'] == '1' ||
        uri.queryParameters['debug'] == 'true';
  } catch (_) {
    return false;
  }
}

/// The URL path captured by index.html before the Flutter engine booted and
/// rewrote it to '/' (see __hesenInitialPath in web/index.html).
String capturedInitialPath() {
  try {
    final v = _jsEvalString('window.__hesenInitialPath');
    return v?.toDart ?? '/';
  } catch (_) {
    return '/';
  }
}

void removeWebSplash() {
  try {
    _removeSplash();
  } catch (e) {
    // Ignore error if function is missing or not on web
  }
}

void handleWebFirebaseError(dynamic e) {
  debugPrint("Firebase Init Error (Raw): $e");
  try {
    final jsObj = e as JSObject;
    if (jsObj.hasProperty('message'.toJS).toDart) {
      final msg = jsObj.getProperty('message'.toJS);
      debugPrint("Firebase Init Error (JS Detail): $msg");
    }
    if (jsObj.hasProperty('code'.toJS).toDart) {
      final code = jsObj.getProperty('code'.toJS);
      debugPrint("Firebase Init Error (JS Code): $code");
    }
  } catch (err) {
    // Ignore if not a JS object or error occurs during property access
  }
}
