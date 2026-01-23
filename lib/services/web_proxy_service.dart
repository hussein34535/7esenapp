import 'package:flutter/foundation.dart';

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)
  static const String _apiProxy =
      'https://late-dream-51e2.hussona4635.workers.dev';

  // القائمة الذهبية للبروكسيات (تم التحقق منها)
  static final List<String> _proxyTemplates = [
    '/api/proxy?url=', // Internal Vercel Proxy (Priority #1 - Same Origin)
    '$_apiProxy?url=', // Custom Worker (Priority #2)
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
    List<String> results = [];

    // Custom Logic for specific IPTV streams that require a unique User-Agent
    // We will race MULTIPLE strategies to find the one that works
    List<String> suffixes = ['']; // Default (empty)

    if (url.contains('cyou.') ||
        url.contains(':8080') ||
        url.contains('fastes.sbs')) {
      // Strategy 1: Dynamic Token (3 Hours Exact)
      // Pattern observed: 1768615609-1768604809 (Diff: 10800s)
      final now = DateTime.now().toUtc();
      // Start slightly in the past (-300s) to allow for server clock skew
      // Duration: 3 hours + small buffer? No, let's try exact 3h window logic
      // observed in logs.
      // Actually, let's generate a "fresh" 3 hour valid window.
      // Expiry = Now + 3h. Creation = Now.
      final creation = now;
      final expiry = now.add(const Duration(hours: 3));

      final startTs = (creation.millisecondsSinceEpoch / 1000).floor();
      final endTs = (expiry.millisecondsSinceEpoch / 1000).floor();

      suffixes = [
        '&ua=$endTs-$startTs', // 1. Dynamic Token (Priority)
        '&ua=IPTVSmartersPro', // 2. Known App
        '&ua=VLC/3.0.16 LibVLC/3.0.16', // 3. Standard Player
        '&ua=okhttp/3.12.1', // 4. Android Standard
        '' // 5. Fallback (Browser UA)
      ];
    }

    // Generate Cartesian Product: Templates x Suffixes
    for (var tpl in _proxyTemplates) {
      if (tpl.contains('workers.dev') || tpl.startsWith('/api/proxy')) {
        // Only internal/worker proxies support &ua= param
        for (var suffix in suffixes) {
          results.add('$tpl$encoded$suffix');
        }
      } else {
        // External proxies usually don't support custom params this way, or we don't know the format
        results.add('$tpl$encoded');
      }
    }

    return results;
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
