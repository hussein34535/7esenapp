class StreamDetails {
  final String? videoUrlToLoad;
  final String? audioUrlToLoad;
  final List<Map<String, dynamic>> fetchedQualities;
  final int selectedQualityIndex;

  StreamDetails({
    this.videoUrlToLoad,
    this.audioUrlToLoad,
    this.fetchedQualities = const [],
    this.selectedQualityIndex = -1,
  });
}
