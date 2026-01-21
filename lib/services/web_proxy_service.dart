import 'package:flutter/foundation.dart';

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)
  static const String _apiProxy =
      'https://late-dream-51e2.hussona4635.workers.dev';

  // القائمة الذهبية للبروكسيات (تم التحقق منها)
  static final List<String> _proxyTemplates = [
    '$_apiProxy?url=', // Custom Worker (Priority #1)
    'https://api.codetabs.com/v1/proxy?quest=', // Stable
    'https://corsproxy.io/?', // Reliable
    'https://api.allorigins.win/raw?url=', // Good backup
    'https://cors-anywhere.herokuapp.com/', // Popular
    'https://proxy.cors.sh/', // User Validated
    'https://cors.bridged.cc/', // User Validated
    'https://api.cloudflare.com/client/v4/workers/proxy?url=', // User Validated
    'https://anyorigin.herokuapp.com/get?url=', // User Validated
    'https://httpsme.herokuapp.com/', // User Validated
    'https://cors-proxy.htmldriven.com/?url=', // User Validated
  ];

  static List<String> get proxyTemplates => _proxyTemplates;

  /// يعيد قائمة بكل الروابط المحتملة عبر البروكسيات المختلفة
  static List<String> getAllProxiedUrls(String url) {
    if (url.isEmpty) return [];

    // إزالة القيد الحصري عن onrender.com للسماح بالـ Fallback
    // سيتم استخدام الـ Worker أولاً لأنه في رأس القائمة

    final encoded = Uri.encodeComponent(url);
    return _proxyTemplates.map((tpl) => '$tpl$encoded').toList();
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
