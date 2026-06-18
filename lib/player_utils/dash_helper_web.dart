Future<String> writeDashManifestToTemp(String dataUrl) async {
  // Web doesn't need to write to a temp file, return the base64 URL directly
  return dataUrl;
}
