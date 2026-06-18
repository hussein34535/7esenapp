import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart'; // MediaKit
import 'package:flutter/material.dart';
import 'package:hesen/web_utils.dart'
    if (dart.library.io) 'package:hesen/web_utils_stub.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hesen/firebase_api.dart';
import 'package:hesen/services/currency_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart'; // Re-added for fallback
import 'package:hesen/screens/pwa_install_screen.dart'; // PWA Install Screen
import 'package:hesen/services/api_service.dart';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/models/highlight_model.dart';
import 'package:uuid/uuid.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
// import 'package:day_night_switch/day_night_switch.dart'; // Removed as unused
import 'package:hesen/video_player_screen.dart';
import 'package:hesen/widgets.dart';
import 'dart:async';
import 'package:hesen/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hesen/player_utils/web_player_registry.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/subscription_screen.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:hesen/notification_page.dart';
import 'package:hesen/screens/profile_screen.dart'; // Added
import 'package:hesen/theme_customization_screen.dart'; // Added, contains ThemeProvider
import 'package:hesen/telegram_dialog.dart'; // Added
import 'package:provider/provider.dart'; // Added
// import 'dart:io'; // Removed for web compatibility
import 'package:flutter/foundation.dart'; // Added
import 'package:hesen/services/resend_service.dart'; // Added
import 'package:hesen/services/data_processor.dart';
import 'package:hesen/navigation.dart';
import 'package:hesen/screens/home_page.dart';
import 'package:hesen/app.dart';

final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

SharedPreferences? prefs;

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit safely
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint("MediaKit Init Error: $e");
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // WINDOW MANAGER INIT (Desktop)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    try {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1280, 720),
        center: true,
        backgroundColor: Colors.black,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.maximize(); // Force maximize on start
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint("WindowManager Init Failed (Native mixin missing?): $e");
    }
  }

  // Initialize Currency Service
  CurrencyService.init();

  // 0. LOAD FONTS FIRST
  try {
    // Already preloaded in index.html for Web, local assets used for Native
    // await GoogleFonts.pendingFonts([GoogleFonts.cairo()]);
  } catch (e) {
    debugPrint("Font Loading Error: $e");
  }

  // 1. Initialize Firebase & Services FIRST (Required for authenticated data fetch on startup)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Windows Platform Threading Error Fix: Disable persistence which can unstabilize the bridge
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    }

    AuthService.isFirebaseInitialized = true;
    debugPrint("Firebase initialized successfully.");
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      AuthService.isFirebaseInitialized = true;
      debugPrint("Firebase already initialized (duplicate handled).");
    } else {
      handleWebFirebaseError(e);
      debugPrint("Firebase Init Error: $e");
    }
  }

  // Dashboard / Telemetry
  final initFuture = initializeDeviceId();

  // Initialize other services that depend on Firebase
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
    try {
      final firebaseApi = FirebaseApi();
      firebaseApi.initNotification();
    } catch (e) {
      debugPrint("Notification Init Error: $e");
    }
  }

  // 2. Initialize Sentry and Run App
  // 2. Initialize Sentry and Run App Safe
  try {
    if (!Sentry.isEnabled) {
      await SentryFlutter.init(
        (options) {
          options.dsn =
              'https://497e74778a74137c33499f17b57c3efa@o4510853875826688.ingest.de.sentry.io/4510853923012688';
          options.tracesSampleRate = 1.0;
        },
      );
    }
    // 2. Run App (Outside appRunner to avoid Zone Mismatch)
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MyApp(initFuture: initFuture),
      ),
    );

    // 3. Remove Web Splash Immediately
    if (kIsWeb) {
      try {
        registerVidstackPlayer();
        removeWebSplash();
      } catch (e) {
        debugPrint("Vidstack Reg/Splash Remove Error: $e");
      }
    }
  } catch (e) {
    debugPrint("Sentry Init Failed (Running App Anyway): $e");
    // Fallback if Sentry fails
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MyApp(initFuture: initFuture),
      ),
    );
    if (kIsWeb) {
      registerVidstackPlayer();
      removeWebSplash();
    }
  }
}
