// lib/utils/pip_helper.dart
import 'package:flutter/material.dart';

import 'pip_helper_io.dart' if (dart.library.js_interop) 'pip_helper_web.dart';

abstract class PipHelper {
  factory PipHelper({
    VoidCallback? onPipEntered,
    VoidCallback? onPipExited,
    Function(String)? onPipAction,
  }) = PipHelperImpl;

  Future<bool> enterPipMode(int aspectWidth, int aspectHeight);
  Future<bool> isPipAvailable();
}
