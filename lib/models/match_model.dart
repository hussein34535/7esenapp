/// Match model for the 7esen TV API.
/// Supports both premium and free content with nullable URLs.
class Match {
  final int id;
  final String teamA;
  final String teamB;
  final String matchTime;
  final String? commentator;
  final String? channel;
  final String? champion;
  final String? logoAUrl;
  final String? logoBUrl;
  final bool isPremium;
  final List<StreamLink> streamLinks;

  Match({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.matchTime,
    this.commentator,
    this.channel,
    this.champion,
    this.logoAUrl,
    this.logoBUrl,
    this.isPremium = false,
    required this.streamLinks,
  });

  /// Factory constructor for new API (snake_case fields).
  factory Match.fromJson(Map<String, dynamic> json) {
    // Extract logo URL from Cloudinary object or direct string
    String? extractLogoUrl(dynamic logoData) {
      if (logoData == null) return null;
      if (logoData is String) return logoData;
      if (logoData is Map<String, dynamic>) {
        return logoData['url'] as String?;
      }
      return null;
    }

    // Parse stream links array
    List<StreamLink> parseStreamLinks(dynamic streamLinkData) {
      if (streamLinkData == null) return [];
      if (streamLinkData is! List) return [];

      return streamLinkData
          .map((item) => StreamLink.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Match(
      id: parseInt(json['id']),
      teamA: json['team_a'] ?? '',
      teamB: json['team_b'] ?? '',
      matchTime: json['match_time'] ?? '',
      commentator: json['commentator'],
      channel: json['channel'],
      champion: json['champion'],
      logoAUrl: extractLogoUrl(json['logo_a']),
      logoBUrl: extractLogoUrl(json['logo_b']),
      isPremium: json['is_premium'] ?? false,
      streamLinks: parseStreamLinks(json['stream_link']),
    );
  }

  /// Check if match has any playable (non-null URL) stream links.
  bool get hasPlayableStreams => streamLinks.any((s) => s.url != null);

  /// Check if match requires premium unlock.
  bool get requiresPremiumUnlock =>
      isPremium || streamLinks.any((s) => s.isPremium && s.url == null);
}

/// Stream link model with premium support.
/// If `isPremium` is true and `url` is null, the user needs to unlock via Premium API.
class StreamLink {
  final String name;
  final String? url; // null if premium and user not subscribed
  final bool isPremium;
  final String quality; // For backwards compatibility

  StreamLink({
    required this.name,
    this.url,
    this.isPremium = false,
    this.quality = '',
  });

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      name: json['name'] ?? '',
      url: json['url'], // Can be null for premium content
      isPremium: json['is_premium'] ?? false,
      quality: json['quality'] ?? json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'is_premium': isPremium,
      'quality': quality,
    };
  }

  /// Check if this stream link is locked (premium but URL is null).
  bool get isLocked => isPremium && url == null;

  /// Check if this stream link is playable (has a URL).
  bool get isPlayable => url != null && url!.isNotEmpty;
}

/// Channel model for the 7esen TV API.
class Channel {
  final int id;
  final String name;
  final String? logoUrl;
  final List<Category> categories;
  final List<StreamLink> streamLinks;

  Channel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.categories,
    required this.streamLinks,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    String? extractLogoUrl(dynamic logoData) {
      if (logoData == null) return null;
      if (logoData is String) return logoData;
      if (logoData is Map<String, dynamic>) {
        return logoData['url'] as String?;
      }
      return null;
    }

    List<Category> parseCategories(dynamic categoriesData) {
      if (categoriesData == null) return [];
      if (categoriesData is! List) return [];
      return categoriesData
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    List<StreamLink> parseStreamLinks(dynamic streamLinkData) {
      if (streamLinkData == null) return [];
      if (streamLinkData is! List) return [];
      return streamLinkData
          .map((item) => StreamLink.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Channel(
      id: parseInt(json['id']),
      name: json['name'] ?? '',
      logoUrl: extractLogoUrl(json['logo']),
      categories: parseCategories(json['categories']),
      streamLinks: parseStreamLinks(json['stream_link']),
    );
  }

  bool get hasPlayableStreams => streamLinks.any((s) => s.url != null);
  bool get requiresPremiumUnlock =>
      streamLinks.any((s) => s.isPremium && s.url == null);
}

/// Category model for the 7esen TV API.
class Category {
  final int id;
  final String name;
  final bool isPremium;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    this.isPremium = false,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Category(
      id: parseInt(json['id']),
      name: json['name'] ?? '',
      isPremium: json['is_premium'] ?? false,
      sortOrder: parseInt(json['sort_order']),
    );
  }
}
