import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

/// Global registry for Vidstack views to bypass shadow DOM isolation issues.
final Map<int, web.HTMLElement> vidstackViews = {};

/// Registers the 'vidstack-player' factory for Web (WASM).
void registerWebVideoPlayerFactory() {
  ui_web.platformViewRegistry.registerViewFactory('vidstack-player',
      (int viewId) {
    try {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = 'vidstack-container-$viewId';
      div.style.width = '100%';
      div.style.height = '100%';
      div.style.backgroundColor = 'black';

      // Store reference for access in widget
      vidstackViews[viewId] = div;

      return div;
    } catch (e) {
      rethrow;
    }
  });
}
