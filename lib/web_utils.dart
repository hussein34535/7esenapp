import 'dart:js' as js;

void removeWebSplash() {
  try {
    js.context.callMethod('removeSplashFromWeb');
  } catch (e) {
    // Ignore error if function is missing or not on web
  }
}
