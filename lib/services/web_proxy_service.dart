// No imports needed for now

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)

  // الرابط الأساسي للبروكسي
  static const String _workerUrl = 'https://hi.husseinh2711.workers.dev/?url=';

  /// يعيد الرابط مبركساً مع تشفير كامل للرابط الأصلي لضمان عمل الـ Tokens والـ Query Params
  static String getProxiedUrl(String url, {String? referer}) {
    if (url.isEmpty) return url;

    // 🛡️ GUARD: Prevent double-proxying - if already proxied, return as-is
    if (url.contains('hi.husseinh2711.workers.dev')) return url;

    // تشفير الرابط ضروري جداً لتجنب قطع الروابط التي تحتوي على & أو ?
    final encodedUrl = Uri.encodeComponent(url);

    // إضافة User-Agent لضمان عدم الحظر من السيرفرات
    const workerSuffix = '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';
    
    String finalProxied = '$_workerUrl$encodedUrl$workerSuffix';
    
    if (referer != null && referer.isNotEmpty) {
      finalProxied += '&ref=${Uri.encodeComponent(referer)}';
    }

    return finalProxied;
  }

  // القائمة الذهبية للبروكسيات (للتوافق مع الكود القديم إن وجد)
  static final List<String> _proxyTemplates = [
    _workerUrl,
  ];

  static List<String> get proxyTemplates => _proxyTemplates;

  /// يعيد قائمة بكل الروابط المحتملة عبر البروكسيات المختلفة
  static List<String> getAllProxiedUrls(String url) {
    if (url.isEmpty) return [];
    return [getProxiedUrl(url)];
  }

  /// Returns the proxied URL using the golden worker
  static String proxiedUrl(String url, {String? referer, String? userAgent}) {
    return getProxiedUrl(url, referer: referer);
  }
}
