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
  if (e is JSObject) {
    try {
      final msg = e.getProperty('message'.toJS);
      debugPrint("Firebase Init Error (JS Detail): $msg");
    } catch (_) {}
  }
}
