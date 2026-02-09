// lib/utils/pip_helper_io.dart
import 'package:flutter/material.dart';
import 'package:android_pip/android_pip.dart';
import 'pip_helper.dart';
import 'dart:io';

class PipHelperImpl implements PipHelper {
  final AndroidPIP _androidPIP;

  PipHelperImpl({
    VoidCallback? onPipEntered,
    VoidCallback? onPipExited,
    Function(String)? onPipAction,
  }) : _androidPIP = AndroidPIP(
          onPipEntered: onPipEntered,
          onPipExited: onPipExited,
          onPipAction: (action) {
            // Map PipAction to String for the consumer
            if (onPipAction != null) {
              onPipAction(action.toString());
            }
          },
        );

  @override
  Future<bool> enterPipMode(int aspectWidth, int aspectHeight) async {
    if (Platform.isAndroid) {
      try {
        final result = await _androidPIP
            .enterPipMode(aspectRatio: [aspectWidth, aspectHeight]);
        return result == true;
      } catch (e) {
        debugPrint("PipHelper Error: $e");
        return false;
      }
    }
    return false;
  }

  @override
  Future<bool> isPipAvailable() async {
    // android_pip only supports Android
    return Platform.isAndroid;
  }
}
