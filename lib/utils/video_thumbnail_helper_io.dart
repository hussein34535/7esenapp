// lib/utils/video_thumbnail_helper_io.dart
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:flutter/foundation.dart';
import 'dart:io';

class VideoThumbnailImpl {
  static Future<Uint8List?> getThumbnail(String videoUrl) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await vt.VideoThumbnail.thumbnailData(
          video: videoUrl,
          imageFormat: vt.ImageFormat.JPEG,
          maxWidth: 640,
          quality: 75,
        ).timeout(const Duration(seconds: 10), onTimeout: () => null);
      }
      // Windows logic was custom in the original file, handling separately or via media_kit there.
      // For now, we strictly wrap the `video_thumbnail` package usage.
      return null;
    } catch (e) {
      debugPrint("VideoThumbnailHelper Error: $e");
      return null;
    }
  }
}
