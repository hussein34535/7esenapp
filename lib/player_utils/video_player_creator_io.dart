import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController createVideoPlayerController(
  String videoUrlToLoad, {
  Map<String, String>? httpHeaders,
  VideoFormat? formatHint,
}) {
  if (videoUrlToLoad.startsWith('file://') || !videoUrlToLoad.startsWith('http')) {
    final cleanPath = videoUrlToLoad.replaceFirst('file://', '');
    return VideoPlayerController.file(
      File(cleanPath),
    );
  }
  return VideoPlayerController.networkUrl(
    Uri.parse(videoUrlToLoad),
    httpHeaders: httpHeaders ?? {},
    formatHint: formatHint,
  );
}
