import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

/// Global registry for Vidstack views to bypass shadow DOM isolation issues.
final Map<int, html.Element> vidstackViews = {};

/// Registers the 'vidstack-player' factory for Web.
void registerWebVideoPlayerFactory() {
  ui_web.platformViewRegistry.registerViewFactory('vidstack-player',
      (int viewId) {
    print('[VIDSTACK_FACTORY] Creating viewId: $viewId');
    final div = html.DivElement()
      ..id = 'vidstack-container-$viewId'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'black';

    // Store reference for access in widget
    vidstackViews[viewId] = div;

    // The actual <media-player> element will be injected dynamically
    // when the widget explicitly sets the source, or we can structure it here.
    // For Vidstack, it's often cleaner to build the structure here if we want
    // a persistent player shell, but allowing dynamic source changes suggests
    // we might want to just provide the container and let the widget handle the inner HTML
    // or use a helper to update it.

    // For simplicity with HtmlElementView, providing a clean container is best.
    return div;
  });
}
