void removeWebSplash() {
  // No-op for non-web platforms
}

void handleWebFirebaseError(dynamic e) {
  // No-op for non-web platforms
}

bool get isIosStandalonePwa => false;

bool shouldEnableDebugLogger() => false;

String capturedInitialPath() => '/';