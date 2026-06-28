import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

const int _chunkSize = 2 * 1024 * 1024; // 2MB
const int _maxParallel = 6;

class DownloadProgress {
  final int videoTotal;
  final int audioTotal;
  int videoDownloaded = 0;
  int audioDownloaded = 0;
  bool videoFirstChunkDone = false;
  bool audioFirstChunkDone = false;

  DownloadProgress(this.videoTotal, this.audioTotal);

  double get overall => videoTotal + audioTotal > 0
      ? (videoDownloaded + audioDownloaded) / (videoTotal + audioTotal)
      : 0.0;

  bool get ready => videoFirstChunkDone && audioFirstChunkDone;
}

Future<({String videoPath, String audioPath})?> downloadYoutubeQualityFastStart({
  required String videoId,
  required int videoItag,
  required int audioItag,
  void Function(double progress)? onProgress,
  void Function(String videoPath, String audioPath)? onReady,
}) async {
  final yt = YoutubeExplode();
  try {
    debugPrint('[YT DOWNLOADER] Fetching manifest for video $videoId...');
    final manifest = await yt.videos.streamsClient.getManifest(
      VideoId(videoId),
      ytClients: [YoutubeApiClient.android, YoutubeApiClient.safari],
    );

    final videoStream = manifest.video.firstWhere((s) => s.tag == videoItag);
    final audioStream = manifest.audioOnly.firstWhere((s) => s.tag == audioItag);

    final tempDir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final videoFile = File('${tempDir.path}${Platform.pathSeparator}hesen_vid_$ts.mp4');
    final audioFile = File('${tempDir.path}${Platform.pathSeparator}hesen_aud_$ts.mp4');

    final videoUrl = videoStream.url;
    final audioUrl = audioStream.url;
    final videoTotal = videoStream.size.totalBytes;
    final audioTotal = audioStream.size.totalBytes;
    final progress = DownloadProgress(videoTotal, audioTotal);

    // Pre-allocate files
    await videoFile.open(mode: FileMode.write).then((f) => f.close());
    await audioFile.open(mode: FileMode.write).then((f) => f.close());

    // Download first chunk of video (2MB)
    final firstVideoChunk = await _downloadRange(
      url: videoUrl,
      start: 0,
      end: _chunkSize.clamp(0, videoTotal) - 1,
      onBytes: (bytes) => progress.videoDownloaded = bytes,
    );
    await videoFile.writeAsBytes(firstVideoChunk, flush: true);
    progress.videoDownloaded = firstVideoChunk.length;
    progress.videoFirstChunkDone = true;

    // Download first chunk of audio (2MB)
    final firstAudioChunk = await _downloadRange(
      url: audioUrl,
      start: 0,
      end: _chunkSize.clamp(0, audioTotal) - 1,
    );
    await audioFile.writeAsBytes(firstAudioChunk, flush: true);
    progress.audioDownloaded = firstAudioChunk.length;
    progress.audioFirstChunkDone = true;

    // Signal ready for playback
    if (progress.ready) {
      onReady?.call(videoFile.path, audioFile.path);
    }

    // Download remaining chunks in parallel
    await Future.wait([
      _downloadRemainingVideo(videoUrl, videoTotal, videoFile, progress, onProgress),
      _downloadRemainingAudio(audioUrl, audioTotal, audioFile, progress, onProgress),
    ]);

    return (videoPath: videoFile.path, audioPath: audioFile.path);
  } catch (e, s) {
    debugPrint('[YT DOWNLOADER] Error: $e');
    debugPrint('[YT DOWNLOADER] Stack: $s');
    return null;
  } finally {
    yt.close();
  }
}

Future<Uint8List> _downloadRange({
  required Uri url,
  required int start,
  required int end,
  void Function(int bytes)? onBytes,
}) async {
  final req = http.Request('GET', url);
  req.headers['User-Agent'] = _userAgent;
  req.headers['Referer'] = 'https://www.youtube.com/';
  req.headers['Range'] = 'bytes=$start-$end';
  final response = await req.send();
  if (response.statusCode != 206 && response.statusCode != 200) {
    throw HttpException('HTTP ${response.statusCode} for range $start-$end');
  }
  final bytes = await response.stream.toBytes();
  onBytes?.call(bytes.length);
  return bytes;
}

Future<void> _downloadRemainingVideo(
  Uri url,
  int total,
  File file,
  DownloadProgress progress,
  void Function(double)? onProgress,
) async {
  if (total <= _chunkSize) return;
  final raf = await file.open(mode: FileMode.writeOnlyAppend);
  try {
    // Download all remaining chunks sequentially (but with Future.wait per batch for parallel speed)
    final List<int> offsets = [];
    for (int o = _chunkSize; o < total; o += _chunkSize) {
      offsets.add(o);
    }

    int batchStart = 0;
    while (batchStart < offsets.length) {
      final batch = offsets.skip(batchStart).take(_maxParallel).toList();
      batchStart += batch.length;

      // Download batch in parallel
      final Map<int, List<int>> chunkData = {};
      final tasks = batch.map((offset) async {
        final end = (offset + _chunkSize - 1).clamp(0, total - 1);
        final data = await _downloadRange(url: url, start: offset, end: end);
        chunkData[offset] = data;
        progress.videoDownloaded += data.length;
      }).toList();

      await Future.wait(tasks);

      // Write in order by offset
      batch.sort();
      for (final offset in batch) {
        final data = chunkData[offset]!;
        raf.writeFromSync(data);
      }
      await raf.flush();
      onProgress?.call(progress.overall);
    }
  } finally {
    await raf.close();
  }
}

Future<void> _downloadRemainingAudio(
  Uri url,
  int total,
  File file,
  DownloadProgress progress,
  void Function(double)? onProgress,
) async {
  if (total <= _chunkSize) return;
  final raf = await file.open(mode: FileMode.writeOnlyAppend);
  try {
    int offset = _chunkSize;
    while (offset < total) {
      final end = (offset + _chunkSize - 1).clamp(0, total - 1);
      final data = await _downloadRange(url: url, start: offset, end: end);
      raf.writeFromSync(data);
      await raf.flush();
      progress.audioDownloaded += data.length;
      onProgress?.call(progress.overall);
      offset += _chunkSize;
    }
  } finally {
    await raf.close();
  }
}

void cleanupTempFiles() {
  try {
    final tempDir = Directory.systemTemp;
    final entries = tempDir.listSync();
    for (final entry in entries) {
      if (entry is File) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (name.startsWith('hesen_vid_') ||
            name.startsWith('hesen_aud_') ||
            name.startsWith('hesen_audio_')) {
          entry.delete();
        }
      }
    }
    debugPrint('[YT DOWNLOADER] Temp files cleaned up.');
  } catch (_) {}
}
