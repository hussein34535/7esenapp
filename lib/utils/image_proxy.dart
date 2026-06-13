import 'package:flutter/foundation.dart';

class ImageProxy {
  static String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // Clean up any stray quotes (sometimes APIs return URLs wrapped in quotes)
    String cleanUrl = url.trim();
    if (cleanUrl.startsWith('"') && cleanUrl.endsWith('"')) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    } else if (cleanUrl.startsWith("'") && cleanUrl.endsWith("'")) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    }
    
    // Only use proxy for Web to bypass CORS for external images like github.com
    if (!kIsWeb) return cleanUrl;
    
    // Skip data URIs, local assets, or non-http paths
    if (cleanUrl.startsWith('data:') || cleanUrl.startsWith('assets/') || !cleanUrl.startsWith('http')) return cleanUrl;
    
    // Skip if it's already proxied
    if (cleanUrl.contains('hi.husseinh2711.workers.dev')) return cleanUrl;

    // Use the Cloudflare proxy to add Access-Control-Allow-Origin: *
    final encodedUrl = Uri.encodeQueryComponent(cleanUrl);
    return 'https://hi.husseinh2711.workers.dev/?url=$encodedUrl';
  }
}
