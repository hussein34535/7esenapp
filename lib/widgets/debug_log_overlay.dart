import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hesen/navigation.dart';
import 'package:hesen/services/debug_logger.dart';

/// Floating debug button that opens an on-device log viewer.
/// Rendered above the Navigator, so it uses [navigatorKey] to present the
/// sheet (its own context has no Navigator ancestor).
class DebugLogOverlay extends StatefulWidget {
  const DebugLogOverlay({super.key});

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  bool _autoScroll = true;
  int _seen = 0;

  void _openLogs() {
    final BuildContext? navContext = navigatorKey.currentContext;
    if (navContext == null) return;

    setState(() => _seen = DebugLogger.lines.length);

    showModalBottomSheet<void>(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0B12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _LogSheet(
        autoScroll: _autoScroll,
        onToggleAutoScroll: (v) => setState(() => _autoScroll = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      bottom: 110,
      child: ValueListenableBuilder<int>(
        valueListenable: DebugLogger.revision,
        builder: (context, rev, _) {
          final int total = DebugLogger.lines.length;
          final bool hasNew = total > _seen;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openLogs,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C52D8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C52D8).withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.bug_report_rounded,
                        color: Colors.white, size: 25),
                    if (hasNew)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF7C52D8), width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogSheet extends StatefulWidget {
  final bool autoScroll;
  final ValueChanged<bool> onToggleAutoScroll;

  const _LogSheet({
    required this.autoScroll,
    required this.onToggleAutoScroll,
  });

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  final ScrollController _scroll = ScrollController();
  late bool _autoScroll = widget.autoScroll;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, _) {
        return ValueListenableBuilder<int>(
          valueListenable: DebugLogger.revision,
          builder: (context, rev, __) {
            final lines = DebugLogger.lines;
            _jumpToEnd();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 6, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.bug_report_rounded,
                          color: Colors.orangeAccent, size: 19),
                      const SizedBox(width: 8),
                      const Text(
                        'Debug Logs',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${lines.length}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: Colors.white70, size: 19),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: DebugLogger.exportText()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded,
                            color: Colors.white70, size: 19),
                        onPressed: () => DebugLogger.clear(),
                      ),
                      IconButton(
                        icon: Icon(
                          _autoScroll
                              ? Icons.vertical_align_bottom_rounded
                              : Icons.pause_circle_outline_rounded,
                          color: _autoScroll
                              ? const Color(0xFFB388FF)
                              : Colors.white70,
                          size: 19,
                        ),
                        onPressed: () {
                          setState(() => _autoScroll = !_autoScroll);
                          widget.onToggleAutoScroll(_autoScroll);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: lines.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد لوجات بعد — جرّب تفتح قناة',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(10),
                          itemCount: lines.length,
                          itemBuilder: (context, index) {
                            final line = lines[index];
                            final Color color = line.contains('error')
                                ? const Color(0xFFFF6B6B)
                                : line.contains('warn')
                                    ? const Color(0xFFFFD166)
                                    : line.contains('VIDSTACK')
                                        ? const Color(0xFF7DD3FC)
                                        : Colors.white70;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: SelectableText(
                                line,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                  height: 1.35,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
