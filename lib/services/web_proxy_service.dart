import 'package:flutter/foundation.dart';

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)
  static const String _apiProxy =
      'https://late-dream-51e2.hussona4635.workers.dev';

  // القائمة الذهبية للبروكسيات - مرتبة حسب الموثوقية من الـ Logs
  static final List<String> _proxyTemplates = [
    'https://api.codetabs.com/v1/proxy?quest=', // #1 - الأكثر موثوقية من الـ Logs ✅
    'https://api.allorigins.win/raw?url=', // #2 - جيد لكن بطيء أحياناً
    '$_apiProxy?url=', // #3 - Worker (يفشل أحياناً بسبب IP blocking)
    'https://corsproxy.io/?', // #4 - Rate limited
    'https://thingproxy.freeboard.io/fetch/', // #5 - Backup
  ];

  static List<String> get proxyTemplates => _proxyTemplates;

  /// يعيد قائمة بكل الروابط المحتملة عبر البروكسيات المختلفة
  static List<String> getAllProxiedUrls(String url) {
    if (url.isEmpty) return [];

    final encoded = Uri.encodeComponent(url);

    // إرسال User-Agent دائماً لكل الروابط عبر الـ Worker
    // هذا مهم لتجنب رفض السيرفرات للطلبات
    const workerSuffix = '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';

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
