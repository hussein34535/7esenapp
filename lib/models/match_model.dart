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
              String name = '';
              if (child['children'] != null && child['children'].length > 1) {
                name = child['children'][0]['text'] ?? '';
                quality = child['children'][1]['text'] ?? '';
              } else if (child['children'] != null &&
                  child['children'].isNotEmpty) {
                name = child['children'][0]['text'] ?? '';
              }
              links.add(
                  StreamLink(url: child['url'], quality: quality, name: name));
            }
          }
        }
      }
      return links;
    }

    String? extractLogoUrl(Map<String, dynamic>? logoData) {
      if (logoData == null) {
        return null;
      }

      final url = logoData['url'];

      if (url is String) {
        return url;
      } else {
        return null;
      }
    }

    final data = json['attributes'] ?? json;

    return Match(
      teamA: data['teamA'] ?? '',
      teamB: data['teamB'] ?? '',
      matchTime: data['matchTime'] ?? '',
      commentator: data['commentator'] ?? '',
      channel: data['channel'] ?? '',
      champion: data['champion'] ?? '',
      logoAUrl: extractLogoUrl(data['logoA']),
      logoBUrl: extractLogoUrl(data['logoB']),
      streamLinks: data['streamLink'] != null
          ? parseStreamLinks(data['streamLink'])
          : [],
    );
  }
}

class StreamLink {
  final String url;
  final String quality;
  final String name;

  StreamLink({
    required this.url,
    required this.quality,
    required this.name,
  });

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      url: json['url'] ?? '',
      quality: json['quality'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, String> toJson() {
    return {
      'url': url,
      'quality': quality,
      'name': name,
    };
  }
}
