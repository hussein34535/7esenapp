# Building Hesen TV PWA for iOS

To ensure the best performance and smoothest scrolling experience on iOS devices, we must use the **WASM** renderer (which provides performance equivalent to or better than the old CanvasKit).

## Optimized Build Command

Use this command to build the web version for production deployment:

```bash
flutter build web --wasm --release --pwa-strategy=offline-first
```

### Breakdown of Flags:
-   `--wasm`: Compiles the application to WebAssembly. This uses the Skwasm renderer for high-performance graphics and smoother animations/scrolling on supported browsers (including modern Safari).
-   `--release`: Builds in release mode with optimizations.
-   `--pwa-strategy=offline-first`: Ensures the service worker caches core assets for offline capability and faster subsequent loads.

## Verification
1.  Deploy the output from `build/web`.
2.  Open on an iPhone (Safari).
3.  Add to Home Screen.
4.  Launch and verify smooth 60fps scrolling.
ش