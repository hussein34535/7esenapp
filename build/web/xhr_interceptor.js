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
                if (url.startsWith('http://')) {
                    console.log('[XHR Interceptor] Auto-proxying insecure URL (open):', url);
                    url = PROXY_PREFIX + encodeURIComponent(url) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';
                } else if (url.startsWith(PROXY_PREFIX) && !url.includes('%3A%2F%2F')) {
                    const rawPart = url.substring(PROXY_PREFIX.length).split('&ua=')[0];
                    console.log('[XHR Interceptor] Fixing unencoded proxy URL:', rawPart);
                    url = PROXY_PREFIX + encodeURIComponent(rawPart) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18';
                }
                this._url = url;
                if (url.includes('proxy-live-stream') || (window.isProxyMode && (url.startsWith('blob:') || url.startsWith('http')))) {
                    this._isProxyRequest = true;
                }
            }
            return super.open(method, url, ...args);
        }

        send(body) {
            if (!this._isProxyRequest || !this._url.includes('proxy-live-stream')) {
                return super.send(body);
            }

            let targetUrl = window.currentStreamUrl;
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
                    const lines = text.split(/\r?\n/);
                    const rewritten = [];
                    lines.forEach(line => {
                        line = line.trim();
                        if (!line) return;
                        if (line.startsWith('#')) {
                            if (line.startsWith('#EXT-X-KEY') && line.includes('URI="')) {
                                line = line.replace(/URI="([^"]+)"/, (m, uri) => {
                                    if (!uri.startsWith('http')) uri = new URL(uri, baseUrl).toString();
                                    return 'URI="' + PROXY_PREFIX + encodeURIComponent(uri) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18"';
                                });
                            }
                            rewritten.push(line);
                        } else {
                            let seg = line;
                            if (!seg.startsWith('http')) seg = new URL(seg, baseUrl).toString();
                            rewritten.push(PROXY_PREFIX + encodeURIComponent(seg) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18');
                        }
                    });

                    const responseData = rewritten.join('\n');
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
        let url = typeof input === 'string' ? input : (input instanceof Request ? input.url : '');

        if (url && url.startsWith('http://')) {
            console.log('[Fetch Interceptor] Auto-proxying insecure URL:', url);
            return originalFetch(PROXY_PREFIX + encodeURIComponent(url) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18', init);
        }

        if (url && (url.includes('ipwho.is') || url.includes('exchangerate-api.com'))) {
            console.log('[Fetch Interceptor] Proxying Service:', url);
            return originalFetch(PROXY_PREFIX + encodeURIComponent(url) + '&ua=VLC%2F3.0.18%20LibVLC%2F3.0.18', init);
        }

        return originalFetch(input, init);
    };
})();
