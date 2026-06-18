import 'package:video_player/video_player.dart';

VideoPlayerController createVideoPlayerController(
  String videoUrlToLoad, {
  Map<String, String>? httpHeaders,
  VideoFormat? formatHint,
}) {
  return VideoPlayerController.networkUrl(
    Uri.parse(videoUrlToLoad),
    httpHeaders: httpHeaders ?? {},
    formatHint: formatHint,
  );
}
