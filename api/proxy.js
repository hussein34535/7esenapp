const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = (req, res) => {
    // Handling CORS for all requests
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, POST, PUT, DELETE, HEAD');
    res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Authorization, Origin, Accept');

    // Handle Preflight Request (OPTIONS) -> Direct 200
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
    if (!target.startsWith('http')) {
        target = `https://st9.onrender.com${target.startsWith('/') ? '' : '/'}${target}`;
    }

    // Handle HEAD requests by performing a GET request to upstream (but only consuming headers)
    if (req.method === 'HEAD') {
        try {
            const parsedUrl = new URL(target);
            const lib = parsedUrl.protocol === 'https:' ? require('https') : require('http');

            const proxyReq = lib.request(target, {
                method: 'GET', // Use GET instead of HEAD to avoid 405
                headers: {
                    'User-Agent': req.headers['user-agent'] || 'Mozilla/5.0',
                    'Accept': '*/*',
                    // Forward other relevant headers?
                }
            }, (proxyRes) => {
                // Copy headers from upstream response
                Object.keys(proxyRes.headers).forEach(key => {
                    if (key.toLowerCase() === 'location') {
                        let originalLocation = proxyRes.headers[key];
                        // Rewrite redirect location to keep it within the proxy
                        if (originalLocation.startsWith('http')) {
                            const encodedLocation = encodeURIComponent(originalLocation);
                            res.setHeader(key, `/api/proxy?url=${encodedLocation}`);
                        } else {
                            res.setHeader(key, originalLocation);
                        }
                    } else {
                        res.setHeader(key, proxyRes.headers[key]);
                    }
                });

                // Ensure CORS headers are set (overwriting upstream if necessary)
                res.setHeader('Access-Control-Allow-Origin', '*');
                res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, POST, PUT, DELETE, HEAD');
                res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Authorization, Origin, Accept');

                // Return upstream status code
                res.status(proxyRes.statusCode);

                // End response without body
                res.end();

                // Destroy upstream request to stop downloading body
                proxyRes.destroy();
            });

            proxyReq.on('error', (err) => {
                console.error('Proxy HEAD Error:', err);
                res.status(502).end();
            });

            proxyReq.end();
            return;
        } catch (e) {
            console.error('Proxy HEAD Exception:', e);
            res.status(500).end();
            return;
        }
    }

    // Create the proxy middleware
    const proxy = createProxyMiddleware({
        target: target,
        changeOrigin: true,
        pathRewrite: (path, req) => {
            // We are proxying the 'url' param, so the target IS the url.
            return '';
        },
        router: () => target, // Force router to use the calculated target
        onProxyRes: (proxyRes, req, res) => {
            // Add CORS headers to the response from the target as well
            proxyRes.headers['Access-Control-Allow-Origin'] = '*';
            proxyRes.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS, POST, PUT, DELETE, HEAD';
            proxyRes.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, Content-Type, Authorization, Origin, Accept';

            // Handle Redirects (3xx) -> Rewrite Location header to keep using proxy
            if (proxyRes.headers['location']) {
                let originalLocation = proxyRes.headers['location'];

                // If the redirect location is absolute, wrap it in our proxy
                if (originalLocation.startsWith('http')) {
                    const encodedLocation = encodeURIComponent(originalLocation);
                    // Rewrite Location to point back to our proxy
                    proxyRes.headers['location'] = `/api/proxy?url=${encodedLocation}`;
                }
            }
        },
    });

    return proxy(req, res);
};
