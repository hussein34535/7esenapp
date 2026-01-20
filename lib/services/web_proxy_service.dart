import 'package:flutter/foundation.dart';

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)
  static const String _apiProxy =
      'https://late-dream-51e2.hussona4635.workers.dev';

  // CorsProxy كـ fallback للستريمات الخارجية
  static const String _streamProxy = 'https://corsproxy.io/?';

  static String proxiedUrl(String url) {
    if (!kIsWeb) return url;

    // أ) منع التكرار
    if (url.startsWith(_apiProxy) ||
        url.startsWith(_streamProxy) ||
        url.startsWith('https://7esenlink.vercel.app')) {
      return url;
    }

    // ب) استثناءات Direct Play
    if (url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('ok.ru/videoembed')) {
      return url;
    }

    // ج) روابط 7esenlink - تذهب مباشرة (لديها streaming proxy)
    if (url.contains('7esenlink.vercel.app')) {
      return url; // الـ API يتعامل مع CORS
    }

    // د) إصلاح روابط IPTV (إضافة .m3u8)
    if ((url.contains(':8080') || url.contains(':80') || !url.contains('.')) &&
        !url.endsWith('.m3u8')) {
      url = '$url.m3u8';
    }

    // هـ) التوجيه الذكي

    // 1. API requests -> Cloudflare Worker
    if (url.contains('onrender.com')) {
      return '$_apiProxy?url=' + Uri.encodeComponent(url);
    }

    // 2. Other streams -> CorsProxy fallback
    return '$_streamProxy' + Uri.encodeComponent(url);
  }
}
