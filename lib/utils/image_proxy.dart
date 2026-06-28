import 'package:flutter/foundation.dart';

class ImageProxy {
  // ✅ هذه المصادر عندها CORS مفتوح وما تحتاج بروكسي
  static const List<String> _trustedDomains = [
    'res.cloudinary.com',     // Cloudinary CDN
    'cloudinary.com',
    'gstatic.com',            // Google CDN (fonts, etc.)
    'googleapis.com',
    'fonts.gstatic.com',
    's1.dmcdn.net',           // Dailymotion CDN
    'dm-thumbs.dmcdn.net',
    'github.com',
    'raw.githubusercontent.com',
    'githubusercontent.com',
    'hi.husseinh2711.workers.dev', // Already proxied
    '7esentv.com',            // Our own domain
    '7esentvbackend.vercel.app',
  ];

  static bool _isTrusted(String url) {
    for (final domain in _trustedDomains) {
      if (url.contains(domain)) return true;
    }
    return false;
  }

  static String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // Clean up any stray quotes (sometimes APIs return URLs wrapped in quotes)
    String cleanUrl = url.trim();
    if (cleanUrl.startsWith('"') && cleanUrl.endsWith('"')) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    } else if (cleanUrl.startsWith("'") && cleanUrl.endsWith("'")) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    }
    
    // Only use proxy for Web to bypass CORS for external images
    if (!kIsWeb) return cleanUrl;
    
    // Skip data URIs, local assets, or non-http paths
    if (cleanUrl.startsWith('data:') || cleanUrl.startsWith('assets/') || !cleanUrl.startsWith('http')) return cleanUrl;
    
    // ✅ Skip if it's already proxied or from a trusted CDN
    if (_isTrusted(cleanUrl)) return cleanUrl;

    // Use the Cloudflare proxy only for unknown external sources
    final encodedUrl = Uri.encodeQueryComponent(cleanUrl);
    return 'https://hi.husseinh2711.workers.dev/?url=$encodedUrl';
  }
}
