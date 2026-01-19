import 'dart:js' as js;
import 'package:flutter/foundation.dart';

// PWA Web Implementation
bool isPwaStandalone() {
  if (!kIsWeb) return true;

  try {
    // Check matchMedia for standalone detection
    final mq =
        js.context.callMethod('matchMedia', ['(display-mode: standalone)']);
    final bool matchesStandalone = mq['matches'] == true;

    // Check iOS navigator.standalone
    final bool isIosStandalone = js.context['navigator']['standalone'] == true;

    return matchesStandalone || isIosStandalone;
  } catch (e) {
    // Fallback: If checking fails, assume browser (false) to force install
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
