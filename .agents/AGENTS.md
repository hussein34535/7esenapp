# Flutter High-Performance & Architectural Rules

Always adhere to the following advanced optimization patterns and coding rules across the codebase:

---

## 1. Rebuild Optimization & Widget Caching
- **The Rule:** Prevent unnecessary sub-tree rebuilds during high-level parent `setState` calls by caching widget instances (Reference Caching).
- **Explanation:** If a widget instance reference remains identical between builds, Flutter's diffing engine skips its `build()` method entirely.
- **Pattern:**
  ```dart
  // 1. Declare the cache variable and a tab-change/trigger flag
  List<Widget>? _cachedSections;
  bool _isTabSwitching = false;

  // 2. Generate cache only when data actually changes (not on tab switch)
  if (_cachedSections == null || !_isTabSwitching) {
    _cachedSections = [
      _buildSectionContent(0),
      _buildSectionContent(1),
    ];
  }
  _isTabSwitching = false; // Reset the flag
  ```

---

## 2. Off-Thread Data Processing (Isolates)
- **The Rule:** Never parse large JSON payloads, sort massive lists, or handle cryptography/decryption on the main UI thread. 
- **Explanation:** Dart is single-threaded. Running CPU-bound tasks on the main thread delays frame rendering, causing skipped frames and jank (lag).
- **Pattern:** Use the top-level `compute()` helper function to offload processing to a background Isolate.
  ```dart
  // Define top-level parsing function (outside any class)
  List<Match> parseMatches(List<dynamic> rawJson) {
    return rawJson.map((item) => Match.fromJson(item)).toList();
  }

  // Inside the stateful widget / mixin
  final rawData = await ApiService.fetchMatches();
  final parsedMatches = await compute(parseMatches, rawData);
  setState(() {
    matches = parsedMatches;
  });
  ```

---

## 3. Repaint Boundaries for Heavy Components
- **The Rule:** Wrap heavy, frequently-updating, or animating components (like video players, loaders, custom painter overlays) in a `RepaintBoundary`.
- **Explanation:** By default, Flutter repaints the entire screen if any child requests a repaint. `RepaintBoundary` forces the engine to paint the component on an isolated layer.
- **Pattern:**
  ```dart
  RepaintBoundary(
    child: ShimmerEffectLoader(),
  )
  ```

---

## 4. Lazy Loading Tab Views (Lazy IndexedStack)
- **The Rule:** Do not initialize all tab screens simultaneously. Defer screen initialization until the tab is first clicked.
- **Explanation:** Standard `IndexedStack` runs the `build()` method and initializes states for all children on startup.
- **Pattern:** Use a lazy wrapper or dynamic lists that build placeholders until visited:
  ```dart
  class LazyIndexedStack extends StatefulWidget { ... } // Use lazy loading library or custom implementation
  ```

---

## 5. Stable Heights & Animated Changes for Navigation Elements
- **The Rule:** Navigation bars and standard screen headers must maintain completely stable heights (layout dimensions) during animations.
- **Explanation:** Modifying widget sizes dynamically inside transitions triggers expensive layout recalculated recalculations (layout shift), which breaks animation smoothness.
- **Pattern:** Avoid popping text elements in/out using conditional blocks (`if (isSelected) Text(...)`). Instead, keep the elements always in layout but toggle their visibility or opacity:
  ```dart
  SizedBox(
    height: 50,
    child: Column(
      children: [
        Icon(Icons.home),
        const SizedBox(height: 4),
        AnimatedOpacity(
          opacity: isSelected ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Text('Home'),
        ),
      ],
    ),
  );
  ```

---

## 6. Strict Rules Against Dynamic Actions inside Build Methods
- **The Rule:** NEVER instantiate `Future` or `Stream` getters directly inside the `build(BuildContext context)` method.
- **Explanation:** The `build` method runs frequently. Creating a new Future inside it causes endless duplicate network calls, state resets, and UI infinite loops.
- **Pattern:** Resolve the Future inside `initState` or data-fetch blocks and pass the pre-resolved Future variables to `FutureBuilder`/`StreamBuilder`.

---

## 7. Efficient List Layouts
- **The Rule:** For long scrolling feeds (like Match lists, Channels, News), always use `ListView.builder` and specify `itemExtent` or `prototypeItem` if item sizes are fixed.
- **Explanation:** Specifying sizes avoids dynamic layout height checking during fast scrolling, significantly increasing scroll smoothness.
- **Pattern:**
  ```dart
  ListView.builder(
    itemCount: items.length,
    itemExtent: 85.0, // Predefined fixed height for maximum rendering performance
    itemBuilder: (context, index) => MatchRowWidget(items[index]),
  )
  ```

---

## 8. Prevent Lookups in Loops
- **The Rule:** Do not call context-dependent lookups like `Theme.of(context)` or `Provider.of(context)` inside item builders.
- **Explanation:** Running context queries on every list row item causes massive redundant tree lookups.
- **Pattern:** Resolve styles/themes once before the loop:
  ```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Resolve once
    return ListView.builder(
      itemBuilder: (context, index) {
        return Text('Item', style: theme.textTheme.bodyMedium); // Re-use resolved theme
      },
    );
  }
  ```

---

## 9. GridView mainAxisExtent and Text Scaling
- **The Rule:** Always allocate generous `mainAxisExtent` in `SliverGridDelegateWithMaxCrossAxisExtent` or `SliverGridDelegateWithFixedCrossAxisCount` to accommodate system text scaling and dynamic padding, preventing `RenderFlex overflowed` errors.
- **Explanation:** Users may increase their device's font size (e.g., 1.1x or 1.5x scaling). If a GridView card's height is strictly constrained and too small, Flutter will throw a `RenderFlex overflowed` exception (yellow and black stripes).
- **Pattern:** When defining `mainAxisExtent`, add an extra margin (e.g., 30-40 pixels) beyond the minimum required height, or use layout components like `FittedBox` or `SingleChildScrollView` inside the grid items if content size is highly variable.
  ```dart
  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 600,
    mainAxisExtent: 220, // Generous height instead of exact minimum like 180
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  ```
