// No imports needed for now

class WebProxyService {
  // Worker للـ API (قوائم وبيانات)

  // الرابط الأساسي للبروكسي
  static const String _workerUrl = 'https://hi.husseinh2711.workers.dev/?url=';

  /// يعيد الرابط مبركساً مع تشفير كامل للرابط الأصلي لضمان عمل الـ Tokens والـ Query Params
  static String getProxiedUrl(String url) {
    if (url.isEmpty) return url;

    // تشفير الرابط ضروري جداً لتجنب قطع الروابط التي تحتوي على & أو ?
    final encodedUrl = Uri.encodeComponent(url);

    // إضافة User-Agent لضمان عدم الحظر من السيرفرات
    const workerSuffix = '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';

    return '$_workerUrl$encodedUrl$workerSuffix';
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

  /// (Deprecated) Returns the first proxy
  static String proxiedUrl(String url) {
    return url; // Don't auto-proxy anything anymore
  }
}
