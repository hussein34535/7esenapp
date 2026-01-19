const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = (req, res) => {
    // Handling CORS for all requests
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, POST, PUT, DELETE, HEAD');
    res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Authorization, Origin, Accept');

    // Handle Preflight Request (OPTIONS) and Probe Request (HEAD)
    if (req.method === 'OPTIONS' || req.method === 'HEAD') {
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
        // If it's just a path, assume the original API base
        target = `https://st9.onrender.com${target.startsWith('/') ? '' : '/'}${target}`;
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
