// lib/utils/video_thumbnail_helper_web.dart
import 'dart:typed_data';

class VideoThumbnailImpl {
  static Future<Uint8List?> getThumbnail(String videoUrl) async {
    // Web implementation: return null as video_thumbnail is not supported
    // You could implement a canvas-based solution here later if needed
    return null;
  }
}
