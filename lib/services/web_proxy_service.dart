import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WebProxyService {
  // 1. Worker للـ API (لأنه يعمل بنجاح مع القوائم)
  static const String _apiProxy =
      'https://late-dream-51e2.hussona4635.workers.dev';

  // 2. CorsProxy للستريم (لأنه أقوى في فك الحظر والـ Redirects حالياً)
  static const String _streamProxy = 'https://corsproxy.io/?';

  // 🔴 جديد: دالة async تجلب الرابط الأصلي من 7esenlink
  static Future<String> resolveStreamUrl(String url) async {
    if (!kIsWeb) return url;

    // إذا كان رابط 7esenlink، نجلب الـ JSON ونستخرج الرابط الأصلي
    if (url.contains('7esenlink.vercel.app')) {
      try {
        // حذف .m3u8 من نهاية الرابط لأن الـ API لا يحتاجه
        final apiUrl = url.replaceAll('.m3u8', '');
        print('[7ESENLINK] Fetching original URL from: $apiUrl');

        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final originalUrl = data['url'] as String?;

          if (originalUrl != null && originalUrl.isNotEmpty) {
            print('[7ESENLINK] Got original URL: $originalUrl');
            return originalUrl; // إرجاع الرابط الأصلي مباشرة
          }
        }
        print('[7ESENLINK] Failed to get URL, status: ${response.statusCode}');
      } catch (e) {
        print('[7ESENLINK] Error fetching URL: $e');
      }
      // في حالة الفشل، نرجع الرابط الأصلي
      return url;
    }

    // للروابط الأخرى، نستخدم الـ proxy العادي
    return proxiedUrl(url);
  }

  // الدالة القديمة للتوافق
  static String proxiedUrl(String url) {
    if (!kIsWeb) return url;

    // أ) منع التكرار
    if (url.startsWith(_apiProxy) || url.startsWith(_streamProxy)) {
      return url;
    }

    // ب) استثناءات لا تحتاج بروكسي
    if (url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('ok.ru/videoembed')) {
      return url;
    }

    // ج) إصلاح روابط IPTV (إضافة .m3u8)
    if ((url.contains(':8080') || url.contains(':80') || !url.contains('.')) &&
        !url.endsWith('.m3u8')) {
      url = '$url.m3u8';
    }

    // د) التوجيه الذكي (Routing)

    // 1. إذا كان API (قوائم وبيانات) -> نستخدم Worker
    if (url.contains('onrender.com')) {
      return '$_apiProxy?url=' + Uri.encodeComponent(url);
    }

    // 2. إذا كان فيديو (Stream) -> نستخدم CorsProxy
    return '$_streamProxy' + Uri.encodeComponent(url);
  }
}
