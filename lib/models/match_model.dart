class Match {
  final String teamA;
  final String teamB;
  final String matchTime;
  final String commentator;
  final String channel;
  final String champion;
  final String? logoAUrl;
  final String? logoBUrl;
  final List<StreamLink> streamLinks;

  Match({
    required this.teamA,
    required this.teamB,
    required this.matchTime,
    required this.commentator,
    required this.channel,
    required this.champion,
    this.logoAUrl,
    this.logoBUrl,
    required this.streamLinks,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    List<StreamLink> parseStreamLinks(List<dynamic> streamLinkData) {
      List<StreamLink> links = [];
      for (var item in streamLinkData) {
        if (item['children'] != null) {
          for (var child in item['children']) {
            if (child['type'] == 'link' && child['url'] != null) {
              String quality = '';
              if (child['children'] != null && child['children'].isNotEmpty) {
                quality = child['children'][0]['text'] ?? '';
              }
              links.add(StreamLink(url: child['url'], quality: quality));
            }
          }
        }
      }
      return links;
    }

    String? extractLogoUrl(Map<String, dynamic>? logoData) {
      if (logoData == null) return null;
      return logoData['url'] as String?;
    }

    final data = json['data'] ?? json;
    
    return Match(
      teamA: data['teamA'] ?? '',
      teamB: data['teamB'] ?? '',
      matchTime: data['matchTime'] ?? '',
      commentator: data['commentator'] ?? '',
      channel: data['channel'] ?? '',
      champion: data['champion'] ?? '',
      logoAUrl: extractLogoUrl(data['logoA']),
      logoBUrl: extractLogoUrl(data['logoB']),
      streamLinks: data['streamLink'] != null ? parseStreamLinks(data['streamLink']) : [],
    );
  }
}

class StreamLink {
  final String url;
  final String quality;

  StreamLink({
    required this.url,
    required this.quality,
  });

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      url: json['url'] ?? '',
      quality: json['quality'] ?? '',
    );
  }

  Map<String, String> toJson() {
    return {
      'url': url,
      'quality': quality,
    };
  }
}
