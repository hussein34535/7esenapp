// No imports needed for now

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)
  static const String _apiProxy =
      'https://late-dream-51e2.hussona4635.workers.dev';

  // القائمة الذهبية للبروكسيات - مرتبة حسب الموثوقية من الـ Logs
  static final List<String> _proxyTemplates = [
    'https://web.7esentv.com/proxy?url=',
  ];

  static List<String> get proxyTemplates => _proxyTemplates;

  /// يعيد قائمة بكل الروابط المحتملة عبر البروكسيات المختلفة
  static List<String> getAllProxiedUrls(String url) {
    if (url.isEmpty) return [];

    // DON'T encode the URL - Nginx's $arg_url doesn't auto-decode,
    // causing "invalid URL prefix" 500 errors with encoded URLs.
    // Stream URLs typically don't contain & or = in their paths.

    // إرسال User-Agent دائماً لكل الروابط عبر الـ Worker
    // هذا مهم لتجنب رفض السيرفرات للطلبات
    const workerSuffix = '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';

    return _proxyTemplates.map((tpl) {
      if (tpl.contains('workers.dev')) {
        final encoded = Uri.encodeComponent(url); // Workers need encoding
        return '$tpl$encoded$workerSuffix';
      }
      return '$tpl$url'; // Nginx proxy: pass raw URL
    }).toList();
  }

  /// (Deprecated) Returns the first proxy
  static String proxiedUrl(String url) {
    if (url.isEmpty) return url;

    // debugPrint('WebProxyService: Original URL: $url');

    // أ) منع التكرار (إذا كان الرابط مبركس أصلاً)
    for (var tpl in _proxyTemplates) {
      if (url.startsWith(tpl)) return url;
    }
    if (url.startsWith(_apiProxy)) return url;

    // ب) استثناءات Direct Play (روابط يوتيوب وغيرها التي لا تحتاج بروكسي)
    if (url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('ok.ru/videoembed')) {
      return url;
    }

    // ج) إجبار البروكسي لروابط Vercel وأي روابط أخرى لحل مشاكل الـ CORS
    final result = getAllProxiedUrls(url).first;
    // debugPrint('WebProxyService: Proxied URL: $result');
    return result;
  }
}
