import http.server
import socketserver
import mimetypes
import os

PORT = 8000

# Ensure .wasm MIME type is correct
mimetypes.init()
mimetypes.add_type('application/wasm', '.wasm')

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = http.server.SimpleHTTPRequestHandler.extensions_map.copy()
    extensions_map.update({
        '': 'application/octet-stream',
        '.wasm': 'application/wasm',
    })

    def do_GET(self):
        # Proxy API requests to Vercel backend
        if self.path.startswith('/api/'):
            import urllib.request
            import urllib.error
            
            target_url = f"https://7esentvbackend.vercel.app{self.path}"
            print(f"Proxying {self.path} -> {target_url}")
            
            try:
                # Create a request with a browser-like User-Agent to avoid blocking
                req = urllib.request.Request(
                    target_url, 
                    headers={'User-Agent': 'Mozilla/5.0'}
                )
                
                with urllib.request.urlopen(req) as response:
                    self.send_response(response.status)
                    # Forward headers (excluding hop-by-hop)
                    for key, value in response.headers.items():
                        if key.lower() not in ['transfer-encoding', 'content-encoding', 'content-length']:
                            self.send_header(key, value)
                    
                    # Read body
                    body = response.read()
                    self.send_header('Content-Length', str(len(body)))
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(body)
                    return
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self.end_headers()
                self.wfile.write(e.read())
                return
            except Exception as e:
                print(f"Proxy Error: {e}")
                self.send_error(500, str(e))
                return

        super().do_GET()

    def end_headers(self):
        # Add Cross-Origin headers just in case (optional but good for SharedArrayBuffer if needed later)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        
        # Only call super().end_headers() if we are NOT handling the request manually in do_GET
        # But do_GET calls super().do_GET() which calls send_head() which calls end_headers().
        # So this override applies to static files.
        # For proxy, we called end_headers manually.
        http.server.SimpleHTTPRequestHandler.end_headers(self)

print(f"Serving at http://localhost:{PORT} with correct wasm MIME type...")
try:
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()
except OSError as e:
    print(f"Error: {e}")
    print("Try using a different port or stopping the existing server.")
