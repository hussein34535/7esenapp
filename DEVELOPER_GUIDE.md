# دليل المطور (Developer Guide) - مشروع Hesen TV

هذا المستند يشرح التعديلات التقنية المتقدمة التي تم إجراؤها على نسخة الويب (Web) من تطبيق Hesen TV، لضمان استمرارية العمل وفهم الهيكلية للمبرمجين المستقبليين.

---

## 1. هيكلية المشروع الكاملة (Full Project Structure)

شرح تفصيلي لجميع المجلدات والملفات الرئيسية في المشروع لسهولة التنقل:

```
/flutterproject/hesen/
├── android/            # ملفات مشروع أندرويد (Gradle, Manifest)
├── ios/                # ملفات مشروع iOS (Runner, Info.plist)
├── web/                # ملفات نسخة الويب (شرح مفصل أدناه)
│   ├── index.html          # الصفحة الرئيسية (تم تعديلها)
│   ├── install_prompt.js   # سكربت حائط التثبيت الإجباري (PWA)
│   ├── xhr_interceptor.js  # سكربت البروكسي لتشغيل الفيديو
│   ├── anti_debug.js       # سكربت الحماية ومنع الفحص
│   └── icons/              # أيقونات التطبيق و PWA
│
├── lib/                # الكود المصدري للتطبيق (Dart Code)
│   ├── main.dart           # نقطة البداية (Entry Point) + تهيئة التطبيق
│   ├── firebase_api.dart   # إعدادات الإشعارات ورسائل Firebase
│   ├── web_utils.dart      # دوال خاصة بالويب (مثل إزالة Splash)
│   │
│   ├── api/                # ملفات الاتصال بالسيرفر
│   │   └── api_service.dart    # جلب القنوات، الأخبار، والمباريات
│   │
│   ├── models/             # نماذج البيانات (Data Models)
│   │   ├── channel_model.dart  # نموذج القناة
│   │   └── match_model.dart    # نموذج المباراة
│   │
│   ├── screens/            # شاشات التطبيق
│   │   ├── home_screen.dart    # الشاشة الرئيسية
│   │   ├── video_player_screen.dart # شاشة المشغل (Vidstack)
│   │   └── pwa_install_screen.dart  # شاشة تعليمات التثبيت
│   │
│   ├── player_utils/       # أدوات المشغل (Vidstack & VideoPlayer)
│   │   ├── vidstack_player_impl_web.dart # تنفيذ المشغل للويب
│   │   └── video_player_web.dart         # ربط المشغل بـ HTML
│   │
│   ├── services/           # خدمات مساعدة
│   │   ├── ad_service.dart     # إدارة الإعلانات
│   │   └── promo_code_service.dart # خدمة أكواد التفعيل
│   │
│   └── widgets/            # عناصر الواجهة القابلة لإعادة الاستخدام
│
├── assets/             # الصور والخطوط المحلية
├── pubspec.yaml        # إدارة المكتبات والإصدارات
└── README.md           # ملف تعريفي بسيط
```

---

## 2. تفاصيل التعديلات البرمجية (Core Modifications)

### أ. تشغيل الفيديو والبروكسي (`xhr_interceptor.js`)
مشكلة الفيديو الرئيسية كانت في تشفير القنوات وقيود الـ CORS.
*   **الحل:** قمنا بعمل Monkey Patching للكائن `XMLHttpRequest`.
*   **الآلية:** أي طلب يحتوي على `proxy-live-stream` يتم اعتراضه، وتوجيهه عبر بروكسي خارجي (`api.codetabs.com`) لجلب المحتوى وتمريره للمشغل (Vidstack).
*   **تنبيه:** إذا توقف الفيديو مستقبلاً، تأكد من أن خدمة البروكسي لا تزال تعمل، أو استبدل `api.codetabs.com` ببروكسي خاص بك.

### ب. حائط التثبيت الإجباري (`install_prompt.js`)
المطلوب هو عدم فتح الموقع كصفحة ويب عادية، بل إجبار المستخدم على تثبيته كتطبيق (PWA).
*   **الآلية:**
    1. السكربت يفحص هل التطبيق يعمل في وضع `standalone` (مثبت) أم لا.
    2. إذا كان **غير مثبت** (في المتصفح)، يتم عرض شاشة سوداء كاملة (Overlay) فوق التطبيق.
    3. **في Android/Desktop:** يظهر زر "تثبيت التطبيق" (يستدعي `deferredPrompt`).
    4. **في iOS (iPhone/iPad):**
        * يكتشف نوع المتصفح تلقائياً:
            * **Safari:** يعرض تعليمات "المشاركة في الأسفل".
            * **Chrome:** يعرض تعليمات "المشاركة في الأعلى".
*   **ملاحظة:** تم ربط المتغير `window.deferredPrompt` في `index.html` لضمان عمل زر التثبيت في أندرويد.

### ج. تحسين سرعة الفتح (Startup Optimization)
كانت هناك مشكلة "تحميل مزدوج" (Double Loading) حيث يظهر شعار HTML ثم شعار Flutter.
*   **الحل:**
    1. في `lib/main.dart` (الدالة `_HomePageState`)، تم إزالة `CircularProgressIndicator` واستبداله بـ `SizedBox.shrink()` (شاشة فارغة) عند التحميل في الويب.
    2. الاعتماد كلياً على **شاشة البداية الخاصة بالـ HTML** (`splash` div في `index.html`) لتبقى ظاهرة حتى انتهاء جلب البيانات تماماً.
    3. يتم إخفاء الشاشة يدوياً باستدعاء `removeWebSplash()` في `main.dart` بعد التأكد من جاهزية البيانات.

---

## 3. تعليمات البناء والرفع (Build & Deploy)

بما أن المشروع يستخدم تعديلات خاصة في الويب، يفضل استخدام الأمر التالي للبناء لضمان التوافق:

```bash
flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=html
```

### الرفع للسيرفر (Deploy)
يتم رفع الملفات عادة إلى المسار `/var/www/hesen` على سيرفر Ubuntu.
أوامر الرفع المعتادة (SSH/SCP):

1. **ضبط الصلاحيات (ليتمكن المستخدم من الرفع):**
   ```bash
   ssh -i "path/to/key.key" ubuntu@IP "sudo chown -R ubuntu:ubuntu /var/www/hesen"
   ```

2. **نسخ الملفات (SCP):**
   ```bash
   scp -r -i "path/to/key.key" "build/web/*" ubuntu@IP:/var/www/hesen/
   ```

3. **إعادة الصلاحيات للويب سيرفر (Nginx/Apache):**
   ```bash
   ssh -i "path/to/key.key" ubuntu@IP "sudo chown -R www-data:www-data /var/www/hesen && sudo chmod -R 755 /var/www/hesen"
   ```

---

## 4. ملاحظات هامة للمطور القادم
*   **أيقونات التطبيق:** تأكد دائماً من وجود `apple-touch-icon.png` في مجلد `web/` لأن `install_prompt.js` يعتمد عليها كصورة أساسية في شاشة التثبيت.
*   **تحديث الروابط:** إذا تغير الدومين، تأكد من تحديث `manifest.json` وقيم `start_url` و `scope`.
*   **Debugging:** إذا أردت تجاوز حائط التثبيت أثناء التطوير، أضف `?pwa=true` لرابط الموقع (مفعل في `install_prompt.js` لأغراض الفحص).

---
**تم كتابة هذا الملف لتوثيق الحالة الحالية للمشروع بتاريخ 25-01-2026.**

---

## 5. ملاحظات النشر والتحديثات الأخيرة (Jan 2026 Updates)

### أ. نشر التطبيق على سيرفر Oracle (Deployment Instructions)
للتعامل مع سيرفر Oracle الخاص بالمشروع (`141.147.40.102`)، استخدم الأوامر التالية بدقة:

1. **تحضير الصلاحيات (بما أن المستخدم `ubuntu` هو المسموح له بالدخول):**
   ```powershell
   ssh -i "C:\Users\husso\Downloads\ssh-key-2025-10-30 (1).key" ubuntu@141.147.40.102 "sudo chown -R ubuntu:ubuntu /var/www/hesen"
   ```

2. **رفع ملفات الويب (`scp`):**
   تأكد أنك قمت ببناء المشروع أولاً (`flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=html`).
   ```powershell
   scp -r -i "C:\Users\husso\Downloads\ssh-key-2025-10-30 (1).key" "D:\flutterproject\hesen\build\web\*" ubuntu@141.147.40.102:/var/www/hesen/
   ```

3. **إعادة ضبط الصلاحيات (لخادم الويب Nginx/Apache):**
   ```powershell
   ssh -i "C:\Users\husso\Downloads\ssh-key-2025-10-30 (1).key" ubuntu@141.147.40.102 "sudo chown -R www-data:www-data /var/www/hesen && sudo chmod -R 755 /var/www/hesen"
   ```

### ب. تصميم واجهة المباريات (MatchBox Layout) - **هام جداً**
تم تعديل تصميم `MatchBox` (نسخة الـ Desktop) ليكون "Scoreboard".
*   **تحذير للمطور:** لا تقم أبداً بوضع `Expanded` داخل `SingleChildScrollView` في هذا الـ Widget، لأن ذلك يسبب خطأ `RenderBox was not laid out`. التصميم الحالي يعتمد على `Column` يملأ المساحة (`MainAxisSize.max`) بدون تمرير.

### ج. واجهة برمجة التطبيقات (Backend API)
تم الانتقال إلى Backend جديد.
*   **Base URL:** `https://7esentvbackend.vercel.app`
*   **المميزات الجديدة:**
    *   دعم `is_premium` للروابط والمباريات.
    *   تحويل أسماء الحقول إلى `snake_case` (مثل `stream_link` بدلاً من `streamLink`).
    *   نظام التحقق من الاشتراكات (`AuthService.unlockPremiumContent`).

### د. نسخة الويندوز (Windows Build)
*   يتم استخدام مشغل `media_kit` (MPV backend) لنسخة الويندوز لضمان تشغيل روابط `m3u8` بكفاءة.
*   تم حل مشاكل الذاكرة (Memory Leak) عند الخروج من الفيديو، لذا تأكد دائماً من استدعاء `player.dispose()` عند تدمير الـ Widget.

