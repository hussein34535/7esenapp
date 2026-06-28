// lib/utils/pip_helper_io.dart
import 'package:flutter/material.dart';
import 'pip_helper.dart';

class PipHelperImpl implements PipHelper {
  PipHelperImpl({
    VoidCallback? onPipEntered,
    VoidCallback? onPipExited,
    Function(String)? onPipAction,
  });

  @override
  Future<bool> enterPipMode(int aspectWidth, int aspectHeight) async {
    return false;
  }

  @override
  Future<bool> isPipAvailable() async {
    return false;
  }
}
