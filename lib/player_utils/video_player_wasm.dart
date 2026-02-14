import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

/// Global registry for Vidstack views to bypass shadow DOM isolation issues.
final Map<int, web.HTMLElement> vidstackViews = {};

/// Registers the 'vidstack-player' factory for Web (WASM).
void registerWebVideoPlayerFactory() {
  ui_web.platformViewRegistry.registerViewFactory('vidstack-player',
      (int viewId) {
    print('[VIDSTACK_FACTORY] START viewId: $viewId (WASM)');
    try {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      print('[VIDSTACK_FACTORY] Div created');
      div.id = 'vidstack-container-$viewId';
      div.style.width = '100%';
      div.style.height = '100%';
      div.style.backgroundColor = 'black';
      print('[VIDSTACK_FACTORY] Styles applied');

      // Store reference for access in widget
      vidstackViews[viewId] = div;
      print('[VIDSTACK_FACTORY] Stored in map');

      return div;
    } catch (e) {
      print('[VIDSTACK_FACTORY] ERROR: $e');
      rethrow;
    }
  });
}
