# Hesen TV — Project Knowledge & Flutter Best Practices

## Project Overview
- Flutter 3.44.2 / Dart 3.12.2
- Streaming video app (IPTV), live matches, news, highlights
- Platforms: Android, Windows, Web (WASM)
- Server: Oracle VPS 141.147.40.102, Nginx with web.7esentv.com
- State management: Provider (ThemeProvider) + mixin-based data (HomePageDataMixin)
- Video player: media-kit (desktop), vidstack (web)
- Notifications: flutter_local_notifications + FCM
- Payments: in-app via packages screen

## Critical Knowledge

### Web WASM Build & Deploy
- Build: `flutter build web --wasm --release` with `--dart-define` for API keys
- Deploy: `sudo chown ubuntu:ubuntu /var/www/hesen -R` → `scp -r build/web/. ubuntu@141.147.40.102:/var/www/hesen` → `sudo chown www-data:www-data /var/www/hesen -R`
- Nginx site config at `/etc/nginx/sites-available/hesen_app`
- WASM needs headers: COEP=require-corp, COOP=same-origin
- Service Worker is disabled in web/index.html for faster PWA startup

### Common Pitfalls
- `MediaQuery.of(context)` inside `AnimatedBuilder` builder must have MaterialApp ancestor
- `AnimatedBuilder` (not `ListenableBuilder`) is correct for Flutter 3.44
- `Color.withValues(alpha:)` requires Flutter 3.27+
- media-kit DASH crash (#973, unfixed) — avoid DASH on desktop
- YouTube 403 for consecutive itag requests
- `Navigator.of(context)` needs proper BuildContext with Navigator ancestor
- `flutter analyze` may timeout on large projects — use `dart analyze <file>` instead

---

## Flutter Performance Best Practices

### 1. Widget Build Optimization (CRITICAL)

#### build-const-widgets — Use const Constructors
Use `const` for static widgets to reuse instances instead of recreating them.
```dart
// Incorrect — new instance every build
Column(children: [Text('Hello'), SizedBox(height: 16)])
// Correct — reused
const Column(children: [Text('Hello'), SizedBox(height: 16)])
```

#### build-split-widgets — Split Large Widgets
Break large widgets into smaller ones so only changed parts rebuild.

#### build-avoid-rebuild — Avoid Unnecessary Rebuilds
Don't call `setState()` when data hasn't changed:
```dart
if (name != newName) setState(() => name = newName);
```

#### build-keys — Use Keys Correctly
```dart
StatefulTile(key: ValueKey(item.id), title: item.name)
```

#### build-repaint-boundary — Isolate Expensive Paints
```dart
RepaintBoundary(child: AnimatedWidget())
```

### 2. List & Scroll Performance (CRITICAL)

#### list-builder — Use ListView.builder
10× memory improvement over `ListView(children:)`.
```dart
ListView.builder(itemCount: items.length, itemBuilder: ...)
```

#### list-item-extent — Specify itemExtent
2-3× faster scrolling for fixed-height items.
```dart
ListView.builder(itemExtent: 72, ...)
```

#### list-sliver — Use Slivers for Complex Layouts
```dart
CustomScrollView(slivers: [SliverAppBar(...), SliverList(...)])
```

### 3. State Management (HIGH)

#### state-selector — Use Selector for Granular Rebuilds
```dart
final userName = context.select<AppState, String>((s) => s.user.name);
```

#### state-notifier — Prefer ValueNotifier for Simple State
```dart
ValueListenableBuilder<int>(valueListenable: _counter, ...)
```

### 4. Image & Asset Optimization (HIGH)

#### image-cached — Use cached_network_image
```dart
CachedNetworkImage(imageUrl: '...', placeholder: ..., errorWidget: ...)
```
Already used in this project for team logos and channel images.

#### image-precache — Precache Images
```dart
precacheImage(const AssetImage('assets/logo.png'), context);
```

### 5. Animation Performance (MEDIUM)

#### anim-transform — Use Transform for Animations
Transform does not trigger layout, only paint.
```dart
// Incorrect — triggers layout every frame
Container(margin: EdgeInsets.only(left: animation.value * 100))
// Correct — only affects paint
Transform.translate(offset: Offset(animation.value * 100, 0), child: child)
```

### 6. Navigation & Routing (MEDIUM)

#### nav-go-router — Use GoRouter for Declarative Routing
```dart
context.push('/details/123');
context.go('/login');
```

### 7. Memory Management (MEDIUM)

#### memory-dispose — Always Dispose Controllers
```dart
@override void dispose() { _controller.dispose(); _subscription.cancel(); super.dispose(); }
```

#### memory-isolates — Use Isolates for Heavy Computation
```dart
final result = await compute(heavyComputation, data);
```

### 8. App Size & Startup (LOW-MEDIUM)
- Enable icon tree shaking in release builds
- Use deferred loading for feature modules
- Configure native splash screen

---

## In-App Notification System

### InAppNotification (lib/widgets/in_app_notification.dart)
```dart
InAppNotification.show(
  context: context,
  message: 'تم تفعيل التنبيه',
  type: NotificationType.success,  // success | error | info
  icon: Icons.notifications_active_rounded,
  duration: Duration(seconds: 3),
);
```
Uses Overlay for top-banner style with BackdropFilter blur. Slides from top, auto-dismisses. Replaces all ScaffoldMessenger SnackBars.

### NotificationService (lib/services/notification_service.dart)
- `scheduleMatchReminder()` uses `zonedSchedule` with `AndroidScheduleMode.inexactAllowWhileIdle`
- Cancel via `cancelReminder(id)`
- Works even when app is closed (OS-level scheduling)
