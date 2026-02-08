# Building Hesen TV PWA for iOS

To ensure the best performance and smoothest scrolling experience on iOS devices, we must use the **CanvasKit** renderer.

## Optimized Build Command

Use this command to build the web version for production deployment:

```bash
flutter build web --web-renderer canvaskit --release --pwa-strategy=offline-first
```

### Breakdown of Flags:
-   `--web-renderer canvaskit`: Forces the use of CanvasKit (bundled Skia Wasm) instead of HTML. This provides better performance and consistency across devices, crucial for iOS.
-   `--release`: Builds in release mode with minification and tree-shaking.
-   `--pwa-strategy=offline-first`: Ensures the service worker caches core assets for offline capability and faster subsequent loads.

## Verification
1.  Deploy the output from `build/web`.
2.  Open on an iPhone (Safari).
3.  Add to Home Screen.
4.  Launch and verify smooth 60fps scrolling.
