(function () {
    const OriginalXHR = window.XMLHttpRequest;
    const PROXY_PREFIX = 'https://hi.husseinh2711.workers.dev/?url=';

    class ProxyXHR extends OriginalXHR {
        constructor() {
            super();
            this._url = '';
            this._isProxyRequest = false;
        }

        open(method, url, ...args) {
            if (typeof url === 'string') {
                const isLocal = url.includes('localhost') || url.includes('127.0.0.1');
                
                // 🛡️ SAFETY: If already proxied, do not proxy again
                if (url.startsWith(PROXY_PREFIX)) {
                    this._url = url;
                    return super.open(method, url, ...args);
                }

                // Bypass Firebase early
                if (url.includes('firebase') || url.includes('googleapis') || url.includes('firestore')) {
                    this._url = url;
                    return super.open(method, url, ...args);
                }

                if (url.startsWith('http://') && !isLocal) {
                    console.log('[XHR Interceptor] Auto-proxying insecure URL (open):', url);
                    url = PROXY_PREFIX + encodeURIComponent(url) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';
                } else if (url.startsWith(PROXY_PREFIX) && !url.includes('%3A%2F%2F')) {
                    const rawPart = url.substring(PROXY_PREFIX.length).split('&ua=')[0];
                    console.log('[XHR Interceptor] Fixing unencoded proxy URL:', rawPart);
                    url = PROXY_PREFIX + encodeURIComponent(rawPart) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';
                }

                if (url.includes('ipwho.is') || url.includes('exchangerate-api.com') || url.includes('7esentvbackend.vercel.app') || url.includes('7esentv-match.vercel.app') || url.includes('okru-api.vercel.app') || url.includes('ok.ru')) {
                    if (!url.startsWith(PROXY_PREFIX)) {
                        console.log('[XHR Interceptor] Proxying Service (open):', url);
                        url = PROXY_PREFIX + encodeURIComponent(url) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';
                    }
                }

                this._url = url;
                if (url.includes('proxy-live-stream') || (window.isProxyMode && (url.startsWith('blob:') || url.startsWith('http')))) {
                    this._isProxyRequest = true;
                }
            }
            return super.open(method, url, ...args);
        }

        send(body) {
            let interceptRewrite = false;
            
            if (this._isProxyRequest) {
                if (this._url.includes('proxy-live-stream') || this._url.includes('.m3u8') || this._url.includes('m3u8')) {
                    interceptRewrite = true;
                }
            }

            // If not rewriting, pass through (e.g., TS segments)
            if (!interceptRewrite) {
                return super.send(body);
            }

            let targetUrl = window.currentStreamUrl;
            if (!targetUrl) return super.send(body);

            console.log('[XHR Interceptor] Intercepting manifest fetch for:', targetUrl);

            // If the URL is already a proxied URL but it's a child playlist, we must extract the TRUE URL!
            if (this._url !== 'https://proxy-live-stream/index.m3u8' && this._url.startsWith(PROXY_PREFIX)) {
                try {
                    const encodedPart = this._url.substring(PROXY_PREFIX.length).split('&ua=')[0];
                    targetUrl = decodeURIComponent(encodedPart);
                } catch(e) {
                    targetUrl = this._url;
                }
            }

            if (!targetUrl) {
                console.warn('[XHR Interceptor] No target URL found, passing through:', this._url);
                return super.send(body);
            }

            // RECOVER RAW URL IF PROXIED
            if (targetUrl.startsWith(PROXY_PREFIX)) {
                try {
                    const encodedPart = targetUrl.substring(PROXY_PREFIX.length).split('&ua=')[0];
                    targetUrl = decodeURIComponent(encodedPart);
                } catch (e) {
                    targetUrl = targetUrl.substring(PROXY_PREFIX.length).split('&ua=')[0];
                }
            }

            console.log('[XHR Interceptor] Proxy Mode Active. RAW URL:', targetUrl);
            const proxyUrl = PROXY_PREFIX + encodeURIComponent(targetUrl) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';

            fetch(proxyUrl)
                .then(res => {
                    if (!res.ok) throw new Error('Proxy error ' + res.status);
                    return res.text();
                })
                .then(text => {
                    const baseUrl = targetUrl.substring(0, targetUrl.lastIndexOf('/') + 1);
                    const queryParams = new URL(proxyUrl).search;
                    const refMatch = queryParams.match(/[&?]ref=([^&]+)/);
                    const refParam = refMatch ? '&ref=' + refMatch[1] : '';
                    const uaSuffix = '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';

                    const isM3u8 = text.includes('#EXTM3U');
                    let responseData = text;

                    if (isM3u8) {
                        const lines = text.split(/\r?\n/);
                        const rewritten = [];
                        lines.forEach(line => {
                            line = line.trim();
                            if (!line) return;
                            if (line.startsWith('#')) {
                                // Broaden to cover #EXT-X-MAP, #EXT-X-MEDIA, #EXT-X-I-FRAME-STREAM-INF, etc.
                                if (line.includes('URI="')) {
                                    line = line.replace(/URI="([^"]+)"/g, (m, uri) => {
                                        // Ignore data URIs
                                        if (uri.startsWith('data:')) return m;
                                        if (!uri.startsWith('http')) uri = new URL(uri, baseUrl).toString();
                                        return 'URI="' + PROXY_PREFIX + encodeURIComponent(uri) + uaSuffix + refParam + '"';
                                    });
                                }
                                rewritten.push(line);
                            } else {
                                let seg = line;
                                if (!seg.startsWith('http') && !seg.startsWith('data:')) {
                                    seg = new URL(seg, baseUrl).toString();
                                }
                                if (!seg.startsWith('data:')) {
                                    rewritten.push(PROXY_PREFIX + encodeURIComponent(seg) + uaSuffix + refParam);
                                } else {
                                    rewritten.push(seg);
                                }
                            }
                        });
                        responseData = rewritten.join('\n');
                    }

                    Object.defineProperty(this, 'status', { value: 200, writable: true });
                    Object.defineProperty(this, 'statusText', { value: 'OK', writable: true });
                    Object.defineProperty(this, 'responseText', { value: responseData, writable: true });
                    Object.defineProperty(this, 'response', { value: responseData, writable: true });
                    Object.defineProperty(this, 'readyState', { value: 4, writable: true });
                    Object.defineProperty(this, 'responseURL', { value: this._url, writable: true });

                    this.dispatchEvent(new Event('readystatechange'));
                    this.dispatchEvent(new Event('load'));
                    if (this.onreadystatechange) this.onreadystatechange();
                    if (this.onload) this.onload();
                })
                .catch(err => {
                    console.error('[XHR Interceptor] Failed:', err);
                    this.dispatchEvent(new Event('error'));
                    if (this.onerror) this.onerror(err);
                });
        }
    }

    window.XMLHttpRequest = ProxyXHR;
    console.log('[XHR Interceptor] Installed - using Cloudflare Worker Proxy');

    const originalFetch = window.fetch;
    window.fetch = async function (input, init) {
        let url = '';
        if (typeof input === 'string') {
            url = input;
        } else if (input instanceof Request) {
            url = input.url;
        } else if (input && input.href) { // Sometimes URL objects are passed
            url = input.href;
        } else if (input && typeof input.toString === 'function') {
            url = input.toString(); // Fallback for custom objects
        }
        
        console.log('[Fetch Interceptor] incoming request. type:', typeof input, 'url resolved to:', url);

        const isLocal = url && (url.includes('localhost') || url.includes('127.0.0.1'));
        
        // 🔴 CRITICAL: Bypass all Firebase/Google services to prevent breaking Auth/Firestore
        if (url && (url.includes('firebase') || url.includes('googleapis') || url.includes('firestore'))) {
            return originalFetch(input, init);
        }

        if (url && url.startsWith('http://') && !isLocal) {
            console.log('[Fetch Interceptor] Auto-proxying insecure URL:', url);
            return originalFetch(PROXY_PREFIX + encodeURIComponent(url) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18', init);
        }

        if (url && (url.includes('ipwho.is') || url.includes('exchangerate-api.com') || url.includes('7esentvbackend.vercel.app') || url.includes('7esentv-match.vercel.app') || url.includes('okru-api.vercel.app') || url.includes('ok.ru'))) {
            if (!url.startsWith(PROXY_PREFIX)) {
                console.log('[Fetch Interceptor] Proxying Service:', url);
                return originalFetch(PROXY_PREFIX + encodeURIComponent(url) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18', init);
            }
        }

        return originalFetch(input, init);
    };
})();
