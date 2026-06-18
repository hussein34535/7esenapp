import 'package:video_player/video_player.dart';
import 'video_player_creator_stub.dart'
    if (dart.library.js_interop) 'video_player_creator_web.dart'
    if (dart.library.io) 'video_player_creator_io.dart' as impl;

VideoPlayerController createVideoPlayerController(
  String videoUrlToLoad, {
  Map<String, String>? httpHeaders,
  VideoFormat? formatHint,
}) {
  return impl.createVideoPlayerController(videoUrlToLoad,
      httpHeaders: httpHeaders, formatHint: formatHint);
}
