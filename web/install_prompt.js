(function () {
  // DEBUG MODE: Add ?pwa=true to URL to test the overlay
  const urlParams = new URLSearchParams(window.location.search);
  const isDebug = urlParams.get('pwa') === 'true';

  // 1. Check if already in standalone mode (App is installed and running)
  const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true;

  if (isStandalone && !isDebug) return;

  // 2. Detect Platform
  const ua = window.navigator.userAgent;
  const isIOS = /iPad|iPhone|iPod/.test(ua) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const isAndroid = /Android/.test(ua);

  // 3. Inject CSS
  const style = document.createElement('style');
  style.innerHTML = `
    .pwa-wall-overlay {
      position: fixed;
      top: 0; left: 0; width: 100%; height: 100%;
      background: #000000; /* OPAQUE BLACK - Hides the app completely */
      z-index: 2147483647; /* Max Z-Index */
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      font-family: 'Cairo', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      text-align: center;
      padding: 20px;
      box-sizing: border-box;
      color: #fff;
    }

    .pwa-logo {
      width: 100px;
      height: 100px;
      border-radius: 22px;
      margin-bottom: 24px;
      box-shadow: 0 8px 30px rgba(124, 82, 216, 0.4);
      object-fit: cover;
    }

    .pwa-title {
      font-size: 24px;
      font-weight: 700;
      margin-bottom: 12px;
      color: #fff;
    }

    .pwa-subtitle {
      font-size: 16px;
      color: #aaa;
      margin-bottom: 40px;
      line-height: 1.6;
      max-width: 320px;
    }

    /* iOS Steps */
    .ios-steps {
      background: #1c1c1e;
      border-radius: 16px;
      padding: 20px;
      width: 100%;
      max-width: 320px;
      text-align: right;
    }

    .step-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 16px;
      border-bottom: 1px solid #333;
      padding-bottom: 12px;
    }
    .step-row:last-child { margin-bottom: 0; border: none; padding-bottom: 0; }
    
    .step-text { font-size: 15px; color: #fff; flex: 1; margin-right: 12px; }
    .step-icon { color: #007aff; }

    /* Android Button */
    .install-btn {
      background: #7C52D8;
      color: white;
      border: none;
      padding: 16px 32px;
      border-radius: 12px;
      font-size: 18px;
      font-weight: bold;
      width: 100%;
      max-width: 300px;
      cursor: pointer;
      box-shadow: 0 4px 15px rgba(124, 82, 216, 0.4);
      transition: transform 0.2s;
    }
    .install-btn:active { transform: scale(0.96); }

    /* Animation */
    .fade-in { animation: fadeIn 0.4s ease-out; }
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
  `;
  document.head.appendChild(style);

  // 4. Build HTML
  const overlay = document.createElement('div');
  overlay.className = 'pwa-wall-overlay fade-in';

  // Specific Content based on Platform
  let actionContent = '';

  if (isIOS) {
    // Detect Chrome on iOS to adjust instructions
    const isChromeIOS = /CriOS/.test(ua);
    const locationText = isChromeIOS ? 'في الأعلى' : 'في الأسفل';

    // IOS Instructions
    actionContent = `
      <div class="ios-steps">
        <div class="step-row">
          <div class="step-text">1. اضغط على زر <b>المشاركة</b> ${locationText}</div>
          <div class="step-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
               <path d="M12 3V15" stroke="#007AFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
               <path d="M7 8L12 3L17 8" stroke="#007AFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
               <path d="M6 13V15.5C6 17.5 7.5 19 9.5 19H14.5C16.5 19 18 17.5 18 15.5V13" stroke="#007AFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
        </div>
        <div class="step-row">
          <div class="step-text">2. اختر <b>إضافة إلى الصفحة الرئيسية</b></div>
          <div class="step-icon">
             <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
               <rect x="3" y="3" width="18" height="18" rx="4" ry="4" stroke="#fff"/>
               <line x1="12" y1="8" x2="12" y2="16" stroke="#fff"/>
               <line x1="8" y1="12" x2="16" y2="12" stroke="#fff"/>
            </svg>
          </div>
        </div>
        <div class="step-row" style="text-align: center; justify-content: center; margin-top: 10px;">
           <span style="font-size: 12px; color: #666;">اضغط "إضافة" في الأعلى لإنهاء التثبيت</span>
        </div>
      </div>
    `;
  } else {
    // Android / Desktop - Install Button
    // Initially hidden, revealed when 'beforeinstallprompt' fires
    actionContent = `
      <div id="android-install-area" style="display: none; width: 100%; display: flex; flex-direction: column; align-items: center;">
        <button class="install-btn" onclick="window.triggerInstallPrompt()">
          تثبيت التطبيق
        </button>
      </div>
      <div id="android-manual-hint" style="margin-top: 16px; font-size: 14px; color: #aaa;">
        جاري التحقق من إمكانية التثبيت...<br>
        أو استخدم خيارات المتصفح (⋮) للإضافة إلى الشاشة الرئيسية.
      </div>
    `;
  }

  overlay.innerHTML = `
    <img src="apple-touch-icon.png" class="pwa-logo" alt="Hesen TV">
    <div class="pwa-title">تثبيت التطبيق مطلوب</div>
    <div class="pwa-subtitle">
      للحصول على أفضل تجربة مشاهدة، يرجى تثبيت التطبيق على جهازك.
    </div>
    ${actionContent}
  `;

  // 5. Append to Body (Blocking Interaction)
  function showOverlay() {
    document.body.appendChild(overlay);

    // Android: Listen for install prompt availability
    if (!isIOS) {
      const btnArea = document.getElementById('android-install-area');
      const hintText = document.getElementById('android-manual-hint');

      function enableButton() {
        if (btnArea) btnArea.style.display = 'flex';
        if (hintText) hintText.innerHTML = 'اضغط أعلاه للتثبيت<br>أو استخدم خيارات المتصفح.';
      }

      // Check if already available (from index.html)
      if (window.deferredPrompt) {
        enableButton();
      }

      // Listen for future availability
      window.addEventListener('beforeinstallprompt', () => {
        enableButton();
      });

      // Fallback: If no prompt after 3 seconds, show manual instructions only
      setTimeout(() => {
        if (!window.deferredPrompt && hintText) {
          hintText.innerHTML = 'الرجاء التثبيت يدوياً عبر خيارات المتصفح (⋮)<br>واختيار "تثبيت التطبيت" أو "الإضافة للشاشة الرئيسية"';
        }
      }, 3000);
    }
  }

  if (document.body) {
    showOverlay();
  } else {
    window.onload = () => showOverlay();
  }

})();