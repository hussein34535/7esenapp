import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

Future<String> writeDashManifestToTemp(String dataUrl) async {
  try {
    if (!dataUrl.startsWith('data:application/dash+xml;base64,')) {
      return dataUrl;
    }
    final String base64Content = dataUrl.substring('data:application/dash+xml;base64,'.length);
    final List<int> xmlBytes = base64.decode(base64Content.trim());
    
    final tempDir = Directory.systemTemp;
    final file = File(p.join(tempDir.path, 'youtube_manifest.mpd'));
    await file.writeAsBytes(xmlBytes, flush: true);
    
    debugPrint('[DASH HELPER] Wrote YouTube DASH manifest to temp file: ${file.path}');
    return file.path;
  } catch (e) {
    debugPrint('[DASH HELPER] Error writing DASH manifest to temp file: $e');
    return dataUrl;
  }
}
