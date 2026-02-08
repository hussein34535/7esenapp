
(function () {
    const OriginalXHR = window.XMLHttpRequest;

    class ProxyXHR extends OriginalXHR {
        constructor() {
            super();
            this._url = '';
            this._isProxyRequest = false;
        }

        open(method, url, ...args) {
            if (typeof url === 'string') {
                this._url = url;
                // Intercept our dummy URL or any blob URL if we are in proxy mode
                if (url.includes('proxy-live-stream') || (window.isProxyMode && url.startsWith('blob:'))) {
                    this._isProxyRequest = true;
                }
            }
            return super.open(method, url, ...args);
        }

        send(body) {
            if (!this._isProxyRequest) {
                return super.send(body);
            }

            const targetUrl = window.currentStreamUrl;
            if (!targetUrl) {
                console.warn('[XHR Interceptor] No target URL found, passing through:', this._url);
                return super.send(body);
            }

            // console.log('[XHR Interceptor] ⚡ Hijacking request');
            // console.log('[XHR Interceptor] 🌍 Fetching real content');

            const proxyUrl = 'https://api.codetabs.com/v1/proxy?quest=' + encodeURIComponent(targetUrl);

            fetch(proxyUrl)
                .then(res => {
                    if (!res.ok) throw new Error('Proxy error ' + res.status);
                    return res.text();
                })
                .then(text => {
                    // Rewrite Manifest
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
                                    return 'URI="https://api.codetabs.com/v1/proxy?quest=' + encodeURIComponent(uri) + '"';
                                });
                            }
                            rewritten.push(line);
                        } else {
                            let seg = line;
                            if (!seg.startsWith('http')) seg = new URL(seg, baseUrl).toString();
                            // Wrap segment in proxy
                            rewritten.push('https://api.codetabs.com/v1/proxy?quest=' + encodeURIComponent(seg));
                        }
                    });

                    const responseData = rewritten.join('\n');

                    // Mock Response properties
                    Object.defineProperty(this, 'status', { value: 200, writable: true });
                    Object.defineProperty(this, 'statusText', { value: 'OK', writable: true });
                    Object.defineProperty(this, 'responseText', { value: responseData, writable: true });
                    Object.defineProperty(this, 'response', { value: responseData, writable: true });
                    Object.defineProperty(this, 'readyState', { value: 4, writable: true });
                    Object.defineProperty(this, 'responseURL', { value: this._url, writable: true }); // Trick HLS into thinking it got what it asked for

                    // Trigger events
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
    // console.log('[XHR Interceptor] 🚀 Installed and ready.');
})();
