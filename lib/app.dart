import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hesen/navigation.dart';
import 'package:hesen/screens/pwa_install_screen.dart';
import 'package:hesen/screens/app_intro_screen.dart';
import 'package:hesen/notification_page.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:hesen/refund_policy_page.dart';
import 'package:hesen/terms_of_service_page.dart';
import 'package:hesen/screens/subscription_screen.dart';
import 'package:hesen/theme_customization_screen.dart';
import 'package:hesen/services/debug_logger.dart';
import 'package:hesen/web_utils.dart' if (dart.library.io) 'package:hesen/web_utils_stub.dart';
import 'package:hesen/widgets/debug_log_overlay.dart';
import 'package:provider/provider.dart';

/// Smooth, modern page transitions (fade + subtle forward slide) on every
/// platform â€” lighter than the default zoom/slide transitions on web.
const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
  },
);

class MyApp extends StatelessWidget {
  final Future<void> initFuture;

  const MyApp({super.key, required this.initFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF0D0D1A),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C52D8).withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon/logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.tv,
                            size: 60,
                            color: Color(0xFF7C52D8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C52D8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            // Single source of truth for named routes: used both by `routes:`
            // and by `onGenerateInitialRoutes` below. The intro screen is the
            // '/' entry; `home:` cannot be used alongside
            // `onGenerateInitialRoutes` (WidgetsApp assert).
            final Map<String, WidgetBuilder> appRoutes = {
              '/': (context) => AppIntroScreen(
                    themeProvider: themeProvider,
                    onThemeChanged: (isDarkMode) {
                      themeProvider.setThemeMode(
                        isDarkMode ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
              '/pwa_install': (context) => const PwaInstallScreen(),
              '/Notification_screen': (context) => const NotificationPage(),
              // Web deep links for Paddle payment verification.
              '/pricing': (context) => const SubscriptionScreen(),
              '/terms': (context) => const TermsOfServicePage(),
              '/privacy': (context) => PrivacyPolicyPage(),
              '/refund': (context) => const RefundPolicyPage(),
            };

            return MaterialApp(
              title: '7eSen TV',
              // Force the URL path as the initial route on web. The engine's
              // defaultRouteName is unreliable here (reports '/' even for
              // deep links), so read the path directly.
              initialRoute: kIsWeb ? Uri.base.path : null,
              debugShowCheckedModeBanner: false,
              // On-device debug overlay (web only, when enabled)
              builder: kIsWeb && DebugLogger.enabled
                  ? (context, appChild) => Stack(
                        children: [
                          if (appChild != null) appChild,
                          const DebugLogOverlay(),
                        ],
                      )
                  : null,
              themeMode: themeProvider.themeMode,
              theme: ThemeData(
                brightness: Brightness.light,
                pageTransitionsTheme: _pageTransitions,
                primaryColor: themeProvider.getPrimaryColor(false),
                scaffoldBackgroundColor:
                    themeProvider.getScaffoldBackgroundColor(false),
                cardColor: themeProvider.getCardColor(false),
                colorScheme: ColorScheme.light(
                  primary: themeProvider.getPrimaryColor(false),
                  secondary: themeProvider.getSecondaryColor(false),
                  surface: Colors.white,
                  error: Colors.red,
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  onSurface: Colors.black,
                  onError: Colors.white,
                  brightness: Brightness.light,
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: themeProvider.getAppBarBackgroundColor(
                    false,
                  ),
                  foregroundColor: Colors.white,
                  iconTheme: const IconThemeData(color: Colors.white),
                  titleTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.black),
                  bodyMedium: TextStyle(color: Colors.black),
                  bodySmall: TextStyle(color: Colors.black),
                ),
                fontFamily: 'sans-serif',
                fontFamilyFallback: const [
                  'Segoe UI',
                  'Tahoma',
                  'Arial',
                  '-apple-system',
                  'BlinkMacSystemFont',
                  'sans-serif',
                ],
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                pageTransitionsTheme: _pageTransitions,
                primaryColor: themeProvider.getPrimaryColor(true),
                scaffoldBackgroundColor:
                    themeProvider.getScaffoldBackgroundColor(true),
                cardColor: themeProvider.getCardColor(true),
                colorScheme: ColorScheme.dark(
                  primary: themeProvider.getPrimaryColor(true),
                  secondary: themeProvider.getSecondaryColor(true),
                  surface: const Color(0xFF1C1C1C),
                  error: Colors.red,
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  onSurface: Colors.white,
                  onError: Colors.white,
                  brightness: Brightness.dark,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  foregroundColor: Colors.white,
                  iconTheme: IconThemeData(color: Colors.white),
                  titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                fontFamily: 'sans-serif',
                fontFamilyFallback: const [
                  'Segoe UI',
                  'Tahoma',
                  'Arial',
                  '-apple-system',
                  'BlinkMacSystemFont',
                  'sans-serif',
                ],
              ),
              // `home:` intentionally omitted â€” the '/' route above is the
              // intro screen, exactly as before.
              routes: appRoutes,
              // Web deep links (e.g. /privacy opened directly) must start on
              // the target page alone. The default initial-route generation
              // would stack the deep-linked page ABOVE AppIntroScreen, whose
              // unconditional pushReplacement(HomePage) after ~2.7s then
              // replaces the deep-linked page with the home page.
              onGenerateInitialRoutes: (String initialRouteName) {
                // The engine rewrites the URL to '/' during startup, so read
                // the entry path captured by index.html BEFORE Flutter booted.
                // Falls back to '/' (normal entry) when unavailable.
                final String initialPath =
                    kIsWeb ? capturedInitialPath() : initialRouteName;
                final WidgetBuilder? deepLinkBuilder =
                    appRoutes[initialPath];
                if (initialPath != '/' && deepLinkBuilder != null) {
                  // Deep link: only the target page, no intro underneath.
                  return <Route<dynamic>>[
                    MaterialPageRoute<dynamic>(
                      builder: deepLinkBuilder,
                      settings: RouteSettings(name: initialPath),
                    ),
                  ];
                }
                // Normal entry ('/' and mobile/desktop): intro screen as
                // before â€” ~2.7s animation then pushReplacement(HomePage).
                return <Route<dynamic>>[
                  MaterialPageRoute<dynamic>(
                    builder: appRoutes['/']!,
                    settings: const RouteSettings(name: '/'),
                  ),
                ];
              },
              navigatorKey: navigatorKey,
            );
          },
        );
      },
    );
  }
}
