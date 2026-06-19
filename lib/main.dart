import 'dart:io';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:hesen/web_utils.dart'
    if (dart.library.io) 'package:hesen/web_utils_stub.dart';
import 'package:hesen/firebase_api.dart';
import 'package:hesen/player_utils/web_player_registry.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/services/currency_service.dart';
import 'package:hesen/services/data_processor.dart';
import 'package:hesen/theme_customization_screen.dart';
import 'package:hesen/screens/home_page.dart';
import 'package:hesen/app.dart';

final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint("MediaKit Init Error: $e");
  }

  if (!kIsWeb) {
    fvp.registerWith();
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

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
        await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint("WindowManager Init Failed: $e");
    }
  }

  CurrencyService.init();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

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

  final initFuture = initializeDeviceId();

  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
    try {
      final firebaseApi = FirebaseApi();
      firebaseApi.initNotification();
    } catch (e) {
      debugPrint("Notification Init Error: $e");
    }
  }

  try {
    if (!Sentry.isEnabled) {
      // Clean up stale crashpad state from previous crashes to prevent
      // interference with the new run.
      try {
        final sentryDir = Directory('.sentry-native');
        if (sentryDir.existsSync()) {
          sentryDir.deleteSync(recursive: true);
        }
      } catch (_) {}

      await SentryFlutter.init(
        (options) {
          options.dsn =
              'https://497e74778a74137c33499f17b57c3efa@o4510853875826688.ingest.de.sentry.io/4510853923012688';
          options.tracesSampleRate = 1.0;
        },
      );
    }
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MyApp(initFuture: initFuture),
      ),
    );

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
