import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class JsUtil {
  /// Replaces dart:js_util.getProperty
  static dynamic getProperty(dynamic o, String p) {
    final obj = o as JSObject;
    return obj.getProperty<JSAny?>(p.toJS)?.dartify();
  }

  /// Replaces dart:js_util.setProperty
  static void setProperty(dynamic o, String p, dynamic v) {
    final obj = o as JSObject;
    obj.setProperty(p.toJS, v.toJS);
  }

  /// Replaces dart:js_util.callMethod
  static dynamic callMethod(dynamic o, String m, List<dynamic> args) {
    final obj = o as JSObject;
    final jsArgs = args.map((e) => e.toJS).toList();
    if (jsArgs.isEmpty) {
      return obj.callMethod<JSAny?>(m.toJS)?.dartify();
    }
    if (jsArgs.length == 1) {
      return obj.callMethod<JSAny?>(m.toJS, jsArgs[0])?.dartify();
    }
    if (jsArgs.length == 2) {
      return obj.callMethod<JSAny?>(m.toJS, jsArgs[0], jsArgs[1])?.dartify();
    }
    if (jsArgs.length == 3) {
      return obj.callMethod<JSAny?>(m.toJS, jsArgs[0], jsArgs[1], jsArgs[2])?.dartify();
    }
    final List<JSAny?> typedArgs = jsArgs.cast<JSAny?>();
    return obj.callMethodVarArgs<JSAny?>(m.toJS, typedArgs)?.dartify();
  }

  /// Replaces dart:js_util.globalThis
  static JSAny get globalThis => globalContext;

  /// Replaces dart:js_util.newObject
  static JSObject newObject() => JSObject();
}
