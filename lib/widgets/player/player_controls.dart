import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hesen/video_player_screen.dart'; // For VideoSize enum

class PlayerControls extends StatelessWidget {
  final Animation<double> opacityAnimation;
  final bool isControlsVisible;
  final bool isLoading;
  final bool hasError;
  final bool isFullScreen;
  final bool isCurrentStreamApi;
  final int selectedStreamIndex;
  final int selectedApiQualityIndex;
  final List<Map<String, dynamic>> validStreamLinks;
  final List<Map<String, dynamic>> fetchedApiQualities;
  final String? currentStreamUrl;
  final Duration position;
  final Duration duration;
  final double bufferedMs;
  final bool isDesktop;
  final bool isLive;
  final bool isPlaying;
  final Color progressBarColor;
  final VideoSize currentVideoSize;

  // Callbacks
  final VoidCallback onPlayPauseToggle;
  final VoidCallback onBackPress;
  final ValueChanged<int> onStreamChanged;
  final ValueChanged<int> onQualityChanged;
  final VoidCallback onAspectRatioChanged;
  final VoidCallback onFullScreenToggle;
  final VoidCallback onPipToggle;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;

  const PlayerControls({
    Key? key,
    required this.opacityAnimation,
    required this.isControlsVisible,
    required this.isLoading,
    required this.hasError,
    required this.isFullScreen,
    required this.isCurrentStreamApi,
    required this.selectedStreamIndex,
    required this.selectedApiQualityIndex,
    required this.validStreamLinks,
    required this.fetchedApiQualities,
    required this.currentStreamUrl,
    required this.position,
    required this.duration,
    required this.bufferedMs,
    required this.isDesktop,
    required this.isLive,
    required this.isPlaying,
    required this.progressBarColor,
    required this.currentVideoSize,
    required this.onPlayPauseToggle,
    required this.onBackPress,
    required this.onStreamChanged,
    required this.onQualityChanged,
    required this.onAspectRatioChanged,
    required this.onFullScreenToggle,
    required this.onPipToggle,
    required this.onSeek,
    required this.onSeekStart,
    required this.onSeekEnd,
  }) : super(key: key);

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return "00:00";
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
    } else {
      return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
    }
  }

  Widget _buildStreamSelector() {
    if (validStreamLinks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(25)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: validStreamLinks.asMap().entries.map<Widget>((entry) {
            final index = entry.key;
            final streamName = (entry.value['name'] as String?) ?? 'Stream';
            final isActive = index == selectedStreamIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                onTap: isActive ? null : () => onStreamChanged(index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                      color: isActive
                          ? progressBarColor
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: isActive
                          ? Border.all(color: Colors.white, width: 2)
                          : null),
                  child: Text(streamName,
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showQualitySelectionDialog(BuildContext context) {
    if (!isCurrentStreamApi || fetchedApiQualities.isEmpty) {
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Text('اختر الجودة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold))),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: fetchedApiQualities.asMap().entries.map((entry) {
                      final qualityKey = entry.key;
                      final qualityName =
                          entry.value['name']?.toString() ?? 'Unknown';
                      final bool isSelected =
                          qualityKey == selectedApiQualityIndex;
                      return ListTile(
                        title: Text(qualityName,
                            style: TextStyle(
                                color: isSelected
                                    ? progressBarColor
                                    : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        trailing: isSelected
                            ? Icon(Icons.check, color: progressBarColor)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          if (!isSelected) {
                            onQualityChanged(qualityKey);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    // --- Buttons ---
    Widget qualityButton = const SizedBox.shrink();
    if (isCurrentStreamApi && fetchedApiQualities.length > 1) {
      String name = 'Auto';
      if (selectedApiQualityIndex >= 0 &&
          selectedApiQualityIndex < fetchedApiQualities.length) {
        name = fetchedApiQualities[selectedApiQualityIndex]['name']
                ?.toString() ??
            'Auto';
      }
      qualityButton = TextButton(
        onPressed: () {
          _showQualitySelectionDialog(context);
          onSeekEnd(); // equivalent to restarting hide controls timer
        },
        child: Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      );
    }

    Widget pipButton = const SizedBox.shrink();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      pipButton = IconButton(
        icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
        onPressed: onPipToggle,
      );
    }

    final double durationMs =
        (!isLive && duration.inMilliseconds > 0)
            ? duration.inMilliseconds.toDouble()
            : 1.0;
    final double positionMs = !isLive
        ? position.inMilliseconds.clamp(0.0, durationMs).toDouble()
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black87],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
          if (isLive) ...[
            const Text('● LIVE',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
          ] else ...[
            Text(_formatDuration(position),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14.0),
                  activeTrackColor: progressBarColor,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor:
                      progressBarColor.withValues(alpha: 0.3),
                ),
                child: Slider(
                  value: positionMs,
                  min: 0.0,
                  max: durationMs,
                  secondaryTrackValue: bufferedMs,
                  onChanged: (value) => onSeek(value),
                  onChangeStart: (_) => onSeekStart(),
                  onChangeEnd: (_) => onSeekEnd(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(_formatDuration(duration),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          qualityButton,
          pipButton,
          IconButton(
            icon: const Icon(Icons.aspect_ratio, color: Colors.white),
            onPressed: onAspectRatioChanged,
          ),
          if (isDesktop)
            IconButton(
              icon: Icon(
                isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: onFullScreenToggle,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: opacityAnimation,
      child: IgnorePointer(
        ignoring: !isControlsVisible,
        child: Stack(
          children: [
            // Back Button (Top Left)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBackPress,
                ),
              ),
            ),

            // Top Stream Selector (Center)
            if (validStreamLinks.isNotEmpty)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 60, // Offset for back button
                right: 0,
                child: Center(child: _buildStreamSelector()),
              ),

            // Center play/pause button
            Center(
              child: (isLoading && !hasError)
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: onPlayPauseToggle,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
            ),

            // Bottom controls bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(context),
            ),
          ],
        ),
      ),
    );
  }
}
