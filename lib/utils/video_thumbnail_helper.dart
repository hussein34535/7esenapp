// lib/utils/video_thumbnail_helper.dart
// Conditional import setup

import 'dart:typed_data';

import 'video_thumbnail_helper_io.dart'
    if (dart.library.js_interop) 'video_thumbnail_helper_web.dart';

class VideoThumbnailHelper {
  /// Generates a thumbnail for a video URL.
  /// Returns Uint8List on success, null on failure/web.
  static Future<Uint8List?> getThumbnail(String videoUrl) {
    return VideoThumbnailImpl.getThumbnail(videoUrl);
  }
}
