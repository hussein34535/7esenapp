import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

/// Captures Flutter debugPrint + browser console errors into a ring buffer
/// so they can be inspected on-device (iPhone PWA has no DevTools).
class DebugLogger {
  static final List<String> _lines = [];
  static const int _maxLines = 800;
  static bool _enabled = false;
  static void Function(String?, {int? wrapWidth})? _originalDebugPrint;

  /// Bumped on every log write so the UI overlay can rebuild cheaply.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get enabled => _enabled;
  static List<String> get lines => List.unmodifiable(_lines);

  static void enable() {
    if (_enabled) return;
    _enabled = true;
    _originalDebugPrint = debugPrint;
    debugPrint = _capturingDebugPrint;
    _attachBrowserHandlers();
    _add('info', 'Debug logger enabled');
  }

  static void _add(String level, String msg) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _lines.add('[$ts] $level: $msg');
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
    revision.value++;
  }

  static void log(String msg) {
    if (!_enabled) return;
    _add('log', msg);
  }

  static void _capturingDebugPrint(String? message, {int? wrapWidth}) {
    if (message != null && message.isNotEmpty) _add('flutter', message);
    _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
  }

  static void _attachBrowserHandlers() {
    try {
      final win = globalContext['window'] as JSObject?;
      if (win == null) return;
      final errHandler = (JSAny? a, JSAny? b, JSAny? c, JSAny? d, JSAny? e) {
        _add('browser-error', '${a?.dartify()} | src=${b?.dartify()}');
      }.toJS;
      final rejHandler = (JSAny? e) {
        _add('browser-rejection', '${e?.dartify()}');
      }.toJS;
      win.callMethod('addEventListener'.toJS, 'error'.toJS, errHandler);
      win.callMethod(
        'addEventListener'.toJS,
        'unhandledrejection'.toJS,
        rejHandler,
      );
    } catch (e) {
      _add('warn', 'Could not attach browser handlers: $e');
    }
  }

  static void clear() => _lines.clear();

  static String exportText() => _lines.join('\n');
}
