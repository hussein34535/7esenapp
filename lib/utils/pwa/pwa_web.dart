import 'dart:js' as js;
import 'package:flutter/foundation.dart';

bool isPwaStandalone() {
  if (!kIsWeb) return true;
  // Check if running in standalone mode (PWA)
  // Check if running in standalone mode (PWA)
  try {
    final mq = js.context.callMethod('matchMedia', ['(display-mode: standalone)']);
    final bool isStandalone = mq['matches'] == true;
    final bool isIosStandalone = js.context['navigator']['standalone'] == true;
    return isStandalone || isIosStandalone;
  } catch (e) {
    return false;
  }
    return false;
  }
}

bool isIOS() {
  if (!kIsWeb) return false;
  try {
    final userAgent =
        js.context['navigator']['userAgent'].toString().toLowerCase();
    return userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
  } catch (e) {
    return false;
  }
}

void triggerInstallPrompt() {
  try {
    js.context.callMethod('triggerInstallPrompt');
  } catch (e) {
    print("Install Prompt Error: $e");
  }
}
