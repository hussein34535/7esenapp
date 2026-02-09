import 'dart:convert';

class Highlight {
  final int id;
  final String title;
  final String? imageUrl;
  final String primaryUrl;
  final List<SourceServer> sources;
  final bool isPremium;

  Highlight({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.primaryUrl,
    required this.sources,
    required this.isPremium,
  });

  factory Highlight.fromJson(Map<String, dynamic> json) {
    var sourceList = json['sources'] as List? ?? [];
    List<SourceServer> servers = sourceList
        .map((i) => SourceServer.fromJson(i))
        .toList();

    String? extractLogoUrl(dynamic logoData) {
      if (logoData == null) return null;
      if (logoData is String) {
        if (logoData.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(logoData);
            if (decoded is Map && decoded.containsKey('url')) {
              return decoded['url'] as String?;
            }
          } catch (e) {
            // Not JSON
          }
        }
        return logoData;
      }
      if (logoData is Map<String, dynamic>) {
        return (logoData['url'] ?? logoData['imageUrl']) as String?;
      }
      return null;
    }

    // Handle ID as String or Int
    int parsedId = 0;
    if (json['id'] != null) {
      if (json['id'] is int) {
        parsedId = json['id'];
      } else {
        parsedId = int.tryParse(json['id'].toString()) ?? 0;
      }
    }

    return Highlight(
      id: parsedId,
      title: json['title'] ?? '',
      imageUrl: extractLogoUrl(json['image']),
      primaryUrl: json['url'] ?? "",
      sources: servers,
      isPremium: json['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': imageUrl,
      'url': primaryUrl,
      'sources': sources.map((e) => e.toJson()).toList(),
      'is_premium': isPremium,
    };
  }
}

class SourceServer {
  final String name;
  final String url;

  SourceServer({required this.name, required this.url});

  factory SourceServer.fromJson(Map<String, dynamic> json) {
    return SourceServer(name: json['name'] ?? '', url: json['url'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'url': url};
  }
}
