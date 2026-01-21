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
    if (url.startsWith(_apiProxy) || url.startsWith(_streamProxy)) {
      return url;
    }

    // ب) استثناءات Direct Play
    if (url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('ok.ru/videoembed')) {
      return url;
    }

    // ج) روابط 7esenlink - نسمح لها بالمرور بدون بروكسي مبدئياً
    // لأننا سنقوم بمعالجتها يدوياً في VidstackPlayerImpl لطلب JSON
    if (url.contains('7esenlink.vercel.app')) {
      return url;
    }

    // د) تم نقل معالجة روابط IPTV إلى VidstackPlayerImpl
    // لإضافة /live/ وتحويلها إلى HLS بشكل ذكي.

    // هـ) التوجيه الذكي

    // 1. API requests -> Cloudflare Worker
    if (url.contains('onrender.com')) {
      return '$_apiProxy?url=' + Uri.encodeComponent(url);
    }

    // 2. Fallback: Use Private Next.js Proxy (7esenlink)
    // Most reliable method. Bypasses Blocks & Fixes CORS.
    // Ensure you deploy the Next.js updates!
    return 'https://7esenlink.vercel.app/api/proxy?url=${Uri.encodeComponent(url)}';
  }
}
