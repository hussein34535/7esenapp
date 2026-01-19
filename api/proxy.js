const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = (req, res) => {
    // 1. Handle Preflight (OPTIONS)
    if (req.method === 'OPTIONS') {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, POST, PUT, DELETE, HEAD');
        res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Authorization, Origin, Accept');
        res.status(200).end();
        return;
    }

    let target = req.query.url;
    if (!target) {
        return res.status(400).json({ error: 'Missing "url" query parameter' });
    }

    // Ensure target is a valid URL
    // Ensure target is a valid URL
    if (!target.startsWith('http')) {
        return res.status(400).json({ error: 'Invalid URL. Must be absolute http/https.' });
    }

    // 2. Handle HEAD requests via upstream GET (headers only)
    if (req.method === 'HEAD') {
        try {
            const parsedUrl = new URL(target);
            const lib = parsedUrl.protocol === 'https:' ? require('https') : require('http');
            const proxyReq = lib.request(target, {
                method: 'GET',
                headers: {
                    'User-Agent': req.headers['user-agent'] || 'Mozilla/5.0',
                    'Accept': '*/*',
                    'Accept-Encoding': 'identity' // Prevent compression so we read headers clearly if needed
                }
            }, (proxyRes) => {
                // Copy headers
                Object.keys(proxyRes.headers).forEach(key => {
                    if (key.toLowerCase() === 'location') {
                        let loc = proxyRes.headers[key];
                        if (loc.startsWith('http')) {
                            res.setHeader(key, `/api/proxy?url=${encodeURIComponent(loc)}`);
                        } else {
                            res.setHeader(key, loc);
                        }
                    } else {
                        res.setHeader(key, proxyRes.headers[key]);
                    }
                });
                res.setHeader('Access-Control-Allow-Origin', '*');
                res.status(proxyRes.statusCode);
                res.end();
                proxyRes.destroy();
            });
            proxyReq.on('error', (e) => res.status(502).end());
            proxyReq.end();
            return;
        } catch (e) {
            return res.status(500).end();
        }
    }

    // 3. Create Proxy for GET/POST/etc
    const proxy = createProxyMiddleware({
        target: target,
        changeOrigin: true,
        selfHandleResponse: true, // We will manually handle response to rewrite m3u8
        pathRewrite: () => '',
        router: () => target,
        onProxyReq: (proxyReq) => {
            // Force uncompressed response so we can easily parse m3u8 text
            proxyReq.setHeader('Accept-Encoding', 'identity');
            // Spoof User-Agent to avoid blocking
            proxyReq.setHeader('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        },
        onProxyRes: (proxyRes, req, res) => {
            // Set CORS
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, POST, PUT, DELETE, HEAD');
            res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Authorization, Origin, Accept');

            // Copy Upstream Headers (handling redirects)
            Object.keys(proxyRes.headers).forEach(key => {
                if (key.toLowerCase() === 'location') {
                    let loc = proxyRes.headers[key];
                    if (loc.startsWith('http')) {
                        res.setHeader(key, `/api/proxy?url=${encodeURIComponent(loc)}`);
                    } else {
                        res.setHeader(key, loc);
                    }
                } else if (key.toLowerCase() === 'content-encoding' || key.toLowerCase() === 'content-length') {
                    // Skip these, we might change body size/encoding
                } else {
                    res.setHeader(key, proxyRes.headers[key]);
                }
            });

            // Check if it is an M3U8 Playlist
            const contentType = proxyRes.headers['content-type'] || '';
            const isM3u8 = contentType.includes('application/vnd.apple.mpegurl') ||
                contentType.includes('application/x-mpegurl') ||
                contentType.includes('text/plain'); // Sometimes served as text

            // Set Status
            res.statusCode = proxyRes.statusCode;

            if (isM3u8 && proxyRes.statusCode >= 200 && proxyRes.statusCode < 300) {
                // Buffer the response
                let bodyChunks = [];
                proxyRes.on('data', chunk => bodyChunks.push(chunk));
                proxyRes.on('end', () => {
                    let body = Buffer.concat(bodyChunks).toString('utf8');

                    // REWRITE LOGIC: Replace http://... with /api/proxy?url=
                    // Regex to find absolute http/https URLs in the m3u8 content
                    // We match (http|https)://[^\s\n]+
                    // But we must be careful not to double-proxy or break things. 
                    // Actually, we mostly care about 'http' causing mixed content.

                    // A robust regex for URI in m3u8 lines (lines not starting with #, or inside #EXT-X-KEY:URI="...")
                    // Simplest Global valid replacement: replace all absolute http:// URLs

                    const replacedBody = body.replace(/(https?:\/\/[^\s"'\n]+)/g, (match) => {
                        return `/api/proxy?url=${encodeURIComponent(match)}`;
                    });

                    res.setHeader('Content-Length', Buffer.byteLength(replacedBody));
                    res.end(replacedBody);
                });
            } else {
                // Pipe directly for non-m3u8 (video chunks, images, etc.)
                // We must pipe data because we set selfHandleResponse: true
                proxyRes.pipe(res);
            }
        },
        onError: (err, req, res) => {
            console.error('Proxy Error:', err);
            res.status(500).end();
        }
    });

    return proxy(req, res);
};
