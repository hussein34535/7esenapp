class StreamDetails {
  final String? videoUrlToLoad;
  final List<Map<String, dynamic>> fetchedQualities;
  final int selectedQualityIndex;

  StreamDetails({
    this.videoUrlToLoad,
    this.fetchedQualities = const [],
    this.selectedQualityIndex = -1,
  });
}
