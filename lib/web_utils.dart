import 'dart:js_interop';

@JS('removeSplashFromWeb')
external void _removeSplash();

void removeWebSplash() {
  try {
    _removeSplash();
  } catch (e) {
    // Ignore error if function is missing or not on web
  }
}
