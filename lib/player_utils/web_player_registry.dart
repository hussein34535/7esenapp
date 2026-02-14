import 'video_player_stub.dart'
    if (dart.library.js_interop) 'video_player_wasm.dart'
    if (dart.library.html) 'video_player_web.dart' as impl;

void registerVidstackPlayer() {
  impl.registerWebVideoPlayerFactory();
}
