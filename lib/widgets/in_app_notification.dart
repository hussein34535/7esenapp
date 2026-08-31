import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

enum NotificationType { success, error, info }

class InAppNotification {
  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext context,
    required String message,
    NotificationType type = NotificationType.info,
    IconData icon = Icons.notifications_none_rounded,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentEntry?.remove();

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        message: message,
        type: type,
        icon: icon,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _NotificationBanner extends StatefulWidget {
  final String message;
  final NotificationType type;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.message,
    required this.type,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _progressController;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    ));

    _progress = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    _controller.forward();
    _progressController.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF4CAF50);
      case NotificationType.error:
        return const Color(0xFFEF5350);
      case NotificationType.info:
        return const Color(0xFF7C52D8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final color = _color;

    return Align(
      alignment: Alignment.topCenter,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 450),
            margin: EdgeInsets.only(top: topPad + 12, left: 16, right: 16),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              // Web (especially iOS Safari): BackdropFilter blur is very expensive.
              // Use a solid translucent background there instead of live blur.
              child: kIsWeb
                  ? _bannerBody(color)
                  : BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: _bannerBody(color),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _bannerBody(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: kIsWeb
            ? Colors.black.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _progress,
            builder: (context, child) {
              return SizedBox(
                height: 2,
                width: double.infinity,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
