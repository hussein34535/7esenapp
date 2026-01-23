import 'package:flutter/foundation.dart';

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)
  static const String _apiProxy =
      'https://late-dream-51e2.hussona4635.workers.dev';

  // القائمة الذهبية للبروكسيات (تم التحقق منها) - الـ Worker الخاص أولاً
  static final List<String> _proxyTemplates = [
    '$_apiProxy?url=', // Custom Worker (TOP PRIORITY - Most Reliable)
    'https://api.allorigins.win/raw?url=', // Very stable for HLS
    'https://api.codetabs.com/v1/proxy?quest=', // Stable & Handles redirects
    'https://corsproxy.io/?', // Reliable but sometimes rate-limited
    'https://thingproxy.freeboard.io/fetch/', // Good backup
    'https://cors-anywhere.herokuapp.com/', // Popular but needs activation
    'https://api.allorigins.win/get?url=', // JSON wrapper variant
  ];

  static List<String> get proxyTemplates => _proxyTemplates;

  /// يعيد قائمة بكل الروابط المحتملة عبر البروكسيات المختلفة
  static List<String> getAllProxiedUrls(String url) {
    if (url.isEmpty) return [];

    final encoded = Uri.encodeComponent(url);

    // Real User-Agent for IPTV streams (looks like a real browser/VLC player)
    // This is critical for streams that check UA headers
    String workerSuffix = '';
    if (url.contains('cyou.') ||
        url.contains(':8080') ||
        url.contains('fastes.sbs') ||
        url.contains('ugeen.live')) {
      // Use VLC-like User-Agent which most IPTV servers accept
      workerSuffix = '&ua=${Uri.encodeComponent("VLC/3.0.18 LibVLC/3.0.18")}';
    }

    return _proxyTemplates.map((tpl) {
      if (tpl.contains('workers.dev')) {
        return '$tpl$encoded$workerSuffix';
      }
      return '$tpl$encoded';
    }).toList();
  }

  /// (Deprecated) Returns the first proxy
  static String proxiedUrl(String url) {
    if (!kIsWeb) return url;

    // أ) منع التكرار
    for (var tpl in _proxyTemplates) {
      if (url.startsWith(tpl)) return url;
    }
    if (url.startsWith(_apiProxy)) return url;

    // ب) استثناءات Direct Play
    if (url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('ok.ru/videoembed') ||
        url.contains('7esenlink.vercel.app')) {
      return url;
    }

    return getAllProxiedUrls(url).first;
  }
}
