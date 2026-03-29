import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('removeSplashFromWeb')
external void _removeSplash();

void removeWebSplash() {
  try {
    _removeSplash();
  } catch (e) {
    // Ignore error if function is missing or not on web
  }
}

void handleWebFirebaseError(dynamic e) {
  debugPrint("Firebase Init Error (Raw): $e");
  if (e is JSObject) {
    try {
      final jsObj = e;
      if (jsObj.hasProperty('message'.toJS).toDart) {
        final msg = jsObj.getProperty('message'.toJS);
        debugPrint("Firebase Init Error (JS Detail): $msg");
      }
      if (jsObj.hasProperty('code'.toJS).toDart) {
        final code = jsObj.getProperty('code'.toJS);
        debugPrint("Firebase Init Error (JS Code): $code");
      }
    } catch (err) {
      debugPrint("Error extracting JS details: $err");
    }
  }
}
