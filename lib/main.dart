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
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

SharedPreferences? prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    await GoogleFonts.pendingFonts([GoogleFonts.cairo()]);
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

    debugPrint("Firebase initialized successfully.");
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  // Dashboard / Telemetry
  final initFuture = _initializeDeviceId();

  // 4. Background Config
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(".env warning (safely ignored).");
  }

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
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://497e74778a74137c33499f17b57c3efa@o4510853875826688.ingest.de.sentry.io/4510853923012688';
        options.tracesSampleRate = 1.0;
      },
    );
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

Future<void> _initializeDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('device_id') == null) {
    await prefs.setString('device_id', const Uuid().v4());
  }
}

// --- Top-level function for background processing ---
Future<Map<String, dynamic>> _processFetchedData(List<dynamic> results) async {
  final uuid = Uuid();

  // 1 & 2: القنوات والأخبار
  final fetchedChannels = results[0] ?? [];
  final fetchedNews = results[1] ?? [];

  // 3. المباريات - تعديل "أمان الأمان" 🛡️
  final List<Match> fetchedMatches = [];
  if (results[2] != null && results[2] is List) {
    for (var item in (results[2] as List)) {
      try {
        // بنحول لـ Map بشكل صريح قبل ما نبعت للـ fromJson
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          item is Match ? item.toJson() : item,
        );
        fetchedMatches.add(Match.fromJson(data));
      } catch (e) {
        debugPrint("Match error: $e");
      }
    }
  }

  // 4. الأهداف
  final List<dynamic> fetchedGoals = (results[3] as List<dynamic>?) ?? [];

  // 5. الملخصات - تعديل "أمان الأمان" 🛡️
  final List<Highlight> fetchedHighlights = [];
  if (results[4] != null && results[4] is List) {
    for (var item in (results[4] as List)) {
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          item is Highlight ? item.toJson() : item,
        );
        fetchedHighlights.add(Highlight.fromJson(data));
      } catch (e) {
        debugPrint("Highlight error: $e");
      }
    }
  }

  final List<dynamic> fetchedCategories = (results[5] as List<dynamic>?) ?? [];

  // --- باقي الكود (معالجة القنوات) زي ما هو بالظبط ---
  Map<String, Map<String, dynamic>> categoryMap = {};

  for (var catData in fetchedCategories) {
    if (catData is! Map) continue;
    final cat = Map<String, dynamic>.from(catData);
    final catId = cat['id']?.toString() ?? uuid.v4();
    categoryMap[catId] = {
      'id': catId,
      'name': cat['name'] ?? 'Unknown',
      'is_premium': cat['is_premium'] ?? false,
      'sort_order': cat['sort_order'] ?? 0,
      'image': cat['image'],
      'channels': <Map<String, dynamic>>[],
    };
  }

  for (var channelData in fetchedChannels) {
    if (channelData is! Map) continue;
    final channel = Map<String, dynamic>.from(channelData);
    final categories = channel['categories'] as List<dynamic>? ?? [];

    if (categories.isEmpty) {
      const unCatId = 'uncategorized';
      categoryMap.putIfAbsent(
        unCatId,
        () => {
          'id': unCatId,
          'name': 'قنوات أخرى',
          'sort_order': 9999,
          'channels': <Map<String, dynamic>>[],
        },
      );
      (categoryMap[unCatId]!['channels'] as List).add(channel);
    } else {
      for (var cat in categories) {
        if (cat is! Map) continue;
        final catId = cat['id']?.toString() ?? uuid.v4();
        final entry = categoryMap.putIfAbsent(
          catId,
          () => {
            'id': catId,
            'name': cat['name'] ?? 'Unknown',
            'is_premium': cat['is_premium'] ?? false,
            'sort_order': cat['sort_order'] ?? 0,
            'image': cat['image'],
            'channels': <Map<String, dynamic>>[],
          },
        );
        (entry['channels'] as List).add(channel);
      }
    }
  }

  List<Map<String, dynamic>> processedChannels = categoryMap.values.toList();
  processedChannels.sort(
    (a, b) =>
        (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0),
  );

  fetchedNews.sort((a, b) {
    try {
      return DateTime.parse(
        b['date'].toString(),
      ).compareTo(DateTime.parse(a['date'].toString()));
    } catch (e) {
      return 0;
    }
  });
  fetchedGoals.sort((a, b) {
    try {
      return DateTime.parse(
        b['createdAt'].toString(),
      ).compareTo(DateTime.parse(a['createdAt'].toString()));
    } catch (e) {
      return 0;
    }
  });

  return {
    'channels': processedChannels,
    'news': fetchedNews,
    'matches': fetchedMatches,
    'goals': fetchedGoals,
    'highlights': fetchedHighlights,
  };
}

// --- New top-level functions for background processing during refresh ---
Future<List<Map<String, dynamic>>> _processRefreshedChannelsData(
  List<dynamic> args,
) async {
  final List<dynamic> fetchedChannels = args[0] as List<dynamic>;
  final List<dynamic> fetchedCategories = args[1] as List<dynamic>;
  const uuid = Uuid();

  // New API returns channels directly, each channel has categories as nested array.
  // We need to group channels by category for the existing UI.
  Map<String, Map<String, dynamic>> categoryMap = {};

  // Pre-populate categoryMap with data from fetchedCategories (includes images!)
  for (var catData in fetchedCategories) {
    if (catData is! Map) continue;
    final cat = Map<String, dynamic>.from(catData);
    final catId = cat['id']?.toString() ?? uuid.v4();
    categoryMap[catId] = {
      'id': catId,
      'name': cat['name'] ?? 'Unknown',
      'is_premium': cat['is_premium'] ?? false,
      'sort_order': cat['sort_order'] ?? 0,
      'image': cat['image'],
      'channels': <Map<String, dynamic>>[],
    };
  }

  for (var channelData in fetchedChannels) {
    if (channelData is! Map) continue;
    final channel = Map<String, dynamic>.from(channelData);

    // Ensure channel has an ID
    if (channel['id'] == null) {
      channel['id'] = uuid.v4();
    }

    // Get categories for this channel
    final categories = channel['categories'] as List<dynamic>? ?? [];

    if (categories.isEmpty) {
      // No category, add to "Uncategorized"
      const unCatId = 'uncategorized';
      categoryMap.putIfAbsent(
        unCatId,
        () => {
          'id': unCatId,
          'name': 'قنوات أخرى',
          'sort_order': 9999,
          'channels': <Map<String, dynamic>>[],
        },
      );
      (categoryMap[unCatId]!['channels'] as List).add(channel);
    } else {
      // Add channel to each of its categories
      for (var cat in categories) {
        if (cat is! Map) continue;
        final catId = cat['id']?.toString() ?? uuid.v4();
        final Map<String, dynamic> entry = categoryMap.putIfAbsent(
          catId,
          () => {
            'id': catId,
            'name': cat['name'] ?? 'Unknown',
            'is_premium': cat['is_premium'] ?? false,
            'sort_order': cat['sort_order'] ?? 0,
            'image': cat['image'],
            'channels': <Map<String, dynamic>>[],
          },
        );
        (entry['channels'] as List).add(channel);
      }
    }
  }

  // Convert to list and sort by sort_order
  List<Map<String, dynamic>> processedChannels = categoryMap.values.toList();
  processedChannels.sort((a, b) {
    final orderA = a['sort_order'] as int? ?? 0;
    final orderB = b['sort_order'] as int? ?? 0;
    return orderA.compareTo(orderB);
  });

  return processedChannels;
}

Future<List<dynamic>> _processRefreshedNewsData(
  List<dynamic> fetchedNews,
) async {
  fetchedNews.sort((a, b) {
    final bool aHasDate = a is Map && a['date'] != null;
    final bool bHasDate = b is Map && b['date'] != null;
    if (!aHasDate && !bHasDate) return 0;
    if (!aHasDate) return 1;
    if (!bHasDate) return -1;
    try {
      final dateA = DateTime.parse(a['date'].toString());
      final dateB = DateTime.parse(b['date'].toString());
      return dateB.compareTo(dateA);
    } catch (e) {
      if (aHasDate && bHasDate) return 0;
      if (aHasDate) return 1;
      if (bHasDate) return -1;
      return 0;
    }
  });
  return fetchedNews;
}

Future<List<dynamic>> _processRefreshedGoalsData(
  List<dynamic> fetchedGoals,
) async {
  fetchedGoals.sort((a, b) {
    final bool aHasDate = a is Map && a['createdAt'] != null;
    final bool bHasDate = b is Map && b['createdAt'] != null;
    if (!aHasDate && !bHasDate) return 0;
    if (!aHasDate) return 1;
    if (!bHasDate) return -1;
    try {
      final dateA = DateTime.parse(a['createdAt'].toString());
      final dateB = DateTime.parse(b['createdAt'].toString());
      return dateB.compareTo(dateA);
    } catch (e) {
      if (aHasDate && bHasDate) return 0;
      if (aHasDate) return 1;
      if (bHasDate) return -1;
      return 0;
    }
  });
  return fetchedGoals;
}

class MyApp extends StatelessWidget {
  final Future<void> initFuture;

  const MyApp({super.key, required this.initFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black, // Dark background while loading
            ),
          );
        }
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return MaterialApp(
              title: '7eSen TV',
              debugShowCheckedModeBanner: false,
              themeMode: themeProvider.themeMode,
              theme: ThemeData(
                brightness: Brightness.light,
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
                textTheme: GoogleFonts.cairoTextTheme(
                  const TextTheme(
                    bodyLarge: TextStyle(color: Colors.black),
                    bodyMedium: TextStyle(color: Colors.black),
                    bodySmall: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
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
              ),
              initialRoute: '/',
              routes: {
                '/pwa_install': (context) => const PwaInstallScreen(),
                '/': (context) => HomePage(
                      key: homeKey,
                      onThemeChanged: (isDarkMode) {
                        themeProvider.setThemeMode(
                          isDarkMode ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                '/Notification_screen': (context) => const NotificationPage(),
              },
              navigatorKey: navigatorKey,
            );
          },
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const HomePage({super.key, required this.onThemeChanged});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String? _userName;
  String? _userProfileImage;
  String? _fcmToken;
  bool _isSubscribed = false;
  String? _subscriptionExpiryDays;
  String? _subscriptionPlan;
  List<Match> matches = [];
  List<dynamic> channels = [];
  List<dynamic> news = [];
  List<dynamic> goals = [];
  List<Highlight> highlights = [];
  int _selectedIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredChannels = [];
  bool _isDarkMode = false;
  bool _isSearchBarVisible = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _channelsHasError = false;
  bool _newsHasError = false;
  bool _goalsHasError = false;
  bool _highlightsHasError = false;
  bool _matchesHasError = false;
  bool _categoriesHasError = false;

  StreamSubscription? _userSubscription;
  Timer? _windowsStatusTimer;
  bool _initialStatusLoaded = false;

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    _startInitializationSequence();
  }

  Future<void> _startInitializationSequence() async {
    await _initData();
    await _initNotifications();

    // DELAY monitor status on Windows to avoid threading bridge issues during startup
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      debugPrint("Windows: Small delay before stream setup...");
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    _monitorUserStatus();
    checkForUpdate().then((_) => _checkAndAskForName());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _userSubscription?.cancel();
    _windowsStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    // On Web (especially iOS), requesting token immediately can freeze the app or cause issues.
    // It should be done via user interaction. Disabling auto-init for Web.
    // Also skip on Windows where Firebase is not initialized.
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return;

    final firebaseApi = FirebaseApi();
    _fcmToken = await firebaseApi.initNotification();
    if (_userName != null && _userName!.isNotEmpty) {
      _sendDeviceInfoToServer(name: _userName!, token: _fcmToken);
    }
  }

  void _sendDeviceInfoToServer({required String name, required String? token}) {
    if (token == null) {
      debugPrint('Cannot send user info to server: FCM token is null.');
      return;
    }
    debugPrint('--- SENDING USER INFO TO SERVER (SIMULATION) ---');
    debugPrint('User Name: $name');
    debugPrint('FCM Token: $token');
    debugPrint('-------------------------------------------------');
  }

  Future<void> _checkAndAskForName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? finalName;

      // 1. Try to get name from Firebase Auth
      if (user != null &&
          user.displayName != null &&
          user.displayName!.isNotEmpty) {
        finalName = user.displayName;
      }

      // 2. If no Auth name, try SharedPreferences
      if (finalName == null) {
        final prefs = await SharedPreferences.getInstance();
        finalName = prefs.getString('user_name');
      }

      // 3. If found, set it. If not, ask user.
      if (finalName != null && finalName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userName = finalName;
          });
          // Sync Prefs if it came from Auth
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getString('user_name') != finalName) {
            await prefs.setString('user_name', finalName);
          }

          if (_fcmToken != null) {
            _sendDeviceInfoToServer(
                name: _userName ?? "Unknown", token: _fcmToken);
          }
        }
      } else {
        if (mounted) {
          _showNameInputDialog();
        }
      }
    } catch (e) {
      debugPrint("_checkAndAskForName Error: $e");
    }
  }

  Future<void> _showNameInputDialog() async {
    final nameController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('مرحباً بك!', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                  'لتقديم تجربة أفضل، الرجاء إدخال اسمك الأول.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'الاسم الأول',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('حفظ'),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_name', nameController.text);
                  if (mounted) {
                    setState(() {
                      _userName = nameController.text;
                    });
                    _sendDeviceInfoToServer(name: _userName!, token: _fcmToken);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditNameDialog() async {
    final nameController = TextEditingController(text: _userName);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تعديل اسمك', textAlign: TextAlign.center),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'الاسم الجديد',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('حفظ'),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final newName = nameController.text.trim();

                  // 1. Update Cloud/Auth
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    debugPrint("User already logged in: ${user.uid}");
                    // Send Telemetry
                    ApiService.sendTelemetry(user.uid);

                    // Check Banned Status
                    // Check Banned Status
                    AuthService().getUserStream()?.listen((snapshot) async {
                      final data = snapshot.data() as Map<String, dynamic>?;
                      if (snapshot.exists &&
                          data != null &&
                          data['status'] == 'banned') {
                        await FirebaseAuth.instance.signOut();
                        navigatorKey.currentState?.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                        if (navigatorKey.currentContext != null) {
                          ScaffoldMessenger.of(
                            navigatorKey.currentContext!,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم حظر حسابك. يرجى التواصل مع الدعم.',
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    });
                  }
                  await AuthService().updateUserName(newName);

                  // 2. Update Local Prefs
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_name', newName);

                  if (mounted) {
                    setState(() {
                      _userName = newName;
                    });
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث الاسم بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _monitorUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ApiService.sendTelemetry(user.uid);
    }

    final prefs = await SharedPreferences.getInstance();
    final currentDeviceId = prefs.getString('device_id');

    // On Windows AND Web, real-time streams can be unstable (Web: NullError crash).
    // We will use a periodic timer or manual checks as a safe alternative.
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      // FORCE INITIAL FETCH execution
      debugPrint("Windows: Performing initial status check...");
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (uid != null) {
        // 1. Load CACHED data first (Instant UI)
        final cachedData = await AuthService().getCachedUserDataOnly();
        if (cachedData != null && mounted) {
          debugPrint("Windows: Loaded cached user data.");
          _updateAppStateWithUserData(cachedData, deviceId);
        }

        // 2. Fetch FRESH data (Background update)
        final initialData = await AuthService().getUserData();
        if (initialData != null && mounted) {
          _updateAppStateWithUserData(initialData, deviceId);
        }
      }

      _scheduleWindowsPolling();
      return;
    }

    final stream = AuthService().getUserStream();
    if (stream != null) {
      _userSubscription = stream.listen((snapshot) {
        try {
          if (snapshot.exists && snapshot.data() != null) {
            final dataMap = snapshot.data();
            if (dataMap is Map<String, dynamic>) {
              _updateAppStateWithUserData(
                dataMap,
                currentDeviceId,
              );
            } else if (dataMap is Map) {
              _updateAppStateWithUserData(
                Map<String, dynamic>.from(dataMap),
                currentDeviceId,
              );
            }
          }
        } catch (e) {
          debugPrint("Monitor User Status Error: $e");
        }
      });
    }
  }

  // --- Adaptive Polling Logic ---
  bool _isFastPollingMode = false;
  DateTime? _fastPollingEndTime;

  /// Triggered by PaymentScreen after a successful receipt upload.
  /// Switches to fast polling (30s) for 15 minutes to catch activation quickly.
  /// Triggered by PaymentScreen after a successful receipt upload.
  /// Switches to fast polling (30s) for 15 minutes to catch activation quickly.
  void startFastPolling() {
    if (_isSubscribed) return; // Already subscribed, no need.

    debugPrint("Windows: Fast polling activated for 15 minutes.");
    _isFastPollingMode = true;
    _fastPollingEndTime = DateTime.now().add(const Duration(minutes: 15));
    _scheduleWindowsPolling();
  }

  void _scheduleWindowsPolling() {
    _windowsStatusTimer?.cancel();

    // STRICT OPTIMIZATION:
    // If we are NOT in Fast Mode, we do NOT poll at all.
    // The user requested: "Don't ask for subscription status every little while"
    if (!_isFastPollingMode) {
      debugPrint("Windows: Background polling disabled (Eco Mode).");
      return;
    }

    // If Fast Mode is active, check if it expired
    if (_fastPollingEndTime != null &&
        DateTime.now().isAfter(_fastPollingEndTime!)) {
      debugPrint("Windows: Fast polling expired. Polling stopped.");
      _isFastPollingMode = false;
      _fastPollingEndTime = null;
      return;
    }

    // Fast Mode Active: Poll every 30s
    const duration = Duration(seconds: 30);

    debugPrint(
      "Windows: Status polling scheduled in ${duration.inSeconds}s (FastMode: Active)",
    );

    _windowsStatusTimer = Timer(duration, () async {
      if (!mounted) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prefs = await SharedPreferences.getInstance();
      final currentDeviceId = prefs.getString('device_id');

      if (uid != null) {
        // Fast mode implies we expect a change, so we hit the API
        final statusData = await AuthService().getUserData();
        if (statusData != null && mounted) {
          // If we became subscribed, stop fast polling immediately
          if (statusData['isSubscribed'] == true) {
            debugPrint(
              "Windows: Subscription detected! Stopping fast polling.",
            );
            _isFastPollingMode = false;
          }
          _updateAppStateWithUserData(statusData, currentDeviceId);
        }
      }

      if (mounted && _isFastPollingMode) {
        _scheduleWindowsPolling(); // Recurse only if still in fast mode
      }
    });
  }

  void _updateAppStateWithUserData(
    Map<String, dynamic> data,
    String? currentDeviceId,
  ) {
    if (data['status'] == 'banned') {
      _handleBannedUser();
    }

    // Check for concurrent session
    if (currentDeviceId != null &&
        data['activeDeviceId'] != null &&
        data['activeDeviceId'] != currentDeviceId) {
      _handleDuplicateSession();
    }

    // Update subscription status and expiry
    final isSub = data['isSubscribed'] == true;
    DateTime? expiryDateTime;

    // Handle multiple formats: subscriptionEnd (API), subscriptionExpiry/expiryDate (Old Firestore)
    final dynamic timestamp = data['subscriptionEnd'] ??
        data['subscriptionExpiry'] ??
        data['expiryDate'];

    if (timestamp is DateTime) {
      expiryDateTime = timestamp;
    } else if (timestamp is String) {
      expiryDateTime = DateTime.tryParse(timestamp);
    } else if (timestamp != null &&
        timestamp.runtimeType.toString().contains('Timestamp')) {
      expiryDateTime = (timestamp as dynamic).toDate();
    }

    String? daysRemaining;
    if (expiryDateTime != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiryDateOnly = DateTime(
        expiryDateTime.year,
        expiryDateTime.month,
        expiryDateTime.day,
      );
      final difference = expiryDateOnly.difference(today).inDays;

      if (difference > 0) {
        daysRemaining = '$difference يوم متبقي';
      } else if (difference == 0) {
        daysRemaining = 'ينتهي اليوم';
      } else {
        daysRemaining = 'منتهي';
      }
    }

    if (mounted) {
      // Check if user was just activated (transition from false to true)
      // Only trigger if initial status was already loaded to avoid showing it on startup for already subbed users
      if (_initialStatusLoaded && !_isSubscribed && isSub) {
        debugPrint("Subscription ACTIVATED!");
        final userEmail = FirebaseAuth.instance.currentUser?.email;
        if (userEmail != null) {
          ResendService.sendUserActivationNotification(userEmail);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل اشتراكك بنجاح! استمتع بالمشاهدة.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _isSubscribed = isSub;
        _subscriptionExpiryDays = daysRemaining;
        // Map planId to a readable string if generic subscriptionPlan is missing
        if (data['subscriptionPlan'] != null) {
          _subscriptionPlan = data['subscriptionPlan'];
        } else if (data['planId'] != null) {
          // Simple mapping fallback or display Plan #
          _subscriptionPlan = 'Premium (Plan ${data['planId']})';
        } else {
          _subscriptionPlan = isSub ? 'Premium' : null;
        }

        if (data['image_url'] != null) {
          _userProfileImage = data['image_url'];
        } else if (data['photoUrl'] != null) {
          _userProfileImage = data['photoUrl'];
        }

        _initialStatusLoaded = true; // Mark as loaded after any update
      });
    }
  }

  void _handleDuplicateSession() async {
    // Cancel subscription
    _userSubscription?.cancel();

    // Sign out
    await AuthService().signOut();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            'تم تسجيل الخروج',
            style: TextStyle(color: Colors.orangeAccent),
          ),
          content: const Text(
            'تم تسجيل الدخول من جهاز آخر. لا يسمح بفتح الحساب من أكثر من جهاز في نفس الوقت.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  void _handleBannedUser() async {
    // Cancel subscription to avoid loop
    _userSubscription?.cancel();

    // Sign out
    await AuthService().signOut();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            'تم حظر الحساب',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'تم حظر حسابك بسبب مخافة الشروط. يرجى التواصل مع الدعم الفني.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (navigatorKey.currentState != null) {
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('موافق'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _channelsHasError = false;
      _newsHasError = false;
      _goalsHasError = false;
      _matchesHasError = false;
      _highlightsHasError = false;
    });

    // Get Auth Token for premium content fetching (if logged in)
    String? token;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        token = await user.getIdToken();

        // Windows Firestore bridge protection delay (reduced for speed)
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          debugPrint("Windows: Small delay for Firestore safety...");
          await Future.delayed(const Duration(milliseconds: 600));
        }

        final authService = AuthService();
        // Start all data fetching in parallel
        final List<Future<dynamic>> initFutures = [
          authService.getUserData(),
          ApiService.fetchChannels(authToken: token).catchError((e) {
            debugPrint('Error fetching channels: $e');
            if (mounted) setState(() => _channelsHasError = true);
            return <dynamic>[];
          }),
          ApiService.fetchNews(authToken: token).catchError((e) {
            debugPrint('Error fetching news: $e');
            if (mounted) setState(() => _newsHasError = true);
            return <dynamic>[];
          }),
          ApiService.fetchMatches(authToken: token).catchError((e) {
            debugPrint('Error fetching matches: $e');
            if (mounted) setState(() => _matchesHasError = true);
            return <Match>[];
          }),
          ApiService.fetchGoals(authToken: token).catchError((e) {
            debugPrint('Error fetching goals: $e');
            if (mounted) setState(() => _goalsHasError = true);
            return <dynamic>[];
          }),
          ApiService.fetchHighlights(authToken: token).catchError((e) {
            debugPrint('Error fetching highlights: $e');
            if (mounted) setState(() => _highlightsHasError = true);
            return <Highlight>[];
          }),
          ApiService.fetchCategories(authToken: token).catchError((e) {
            debugPrint('Error fetching categories: $e');
            if (mounted) setState(() => _categoriesHasError = true);
            return <dynamic>[];
          }),
        ];

        final results = await Future.wait(initFutures);
        final userData = results[0] as Map<String, dynamic>?;
        final fetchedResults = results.sublist(1);

        if (mounted && userData != null) {
          final isSub = userData['isSubscribed'] == true;
          DateTime? expiryDateTime;
          // Handle multiple formats: subscriptionEnd (API), subscriptionExpiry/expiryDate (Old Firestore)
          final dynamic timestamp = userData['subscriptionEnd'] ??
              userData['subscriptionExpiry'] ??
              userData['expiryDate'];

          if (timestamp is DateTime) {
            expiryDateTime = timestamp;
          } else if (timestamp is String) {
            expiryDateTime = DateTime.tryParse(timestamp);
          } else if (timestamp != null &&
              timestamp.runtimeType.toString().contains('Timestamp')) {
            expiryDateTime = (timestamp as dynamic).toDate();
          }

          String? daysRemaining;
          if (expiryDateTime != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final expiryDateOnly = DateTime(
              expiryDateTime.year,
              expiryDateTime.month,
              expiryDateTime.day,
            );
            final difference = expiryDateOnly.difference(today).inDays;

            if (difference > 0) {
              daysRemaining = '$difference يوم متبقي';
            } else if (difference == 0) {
              daysRemaining = 'ينتهي اليوم';
            } else {
              daysRemaining = 'منتهي';
            }
          }

          setState(() {
            _isSubscribed = isSub;
            _subscriptionExpiryDays = daysRemaining;
            // Map planId to a readable string if generic subscriptionPlan is missing
            if (userData['subscriptionPlan'] != null) {
              _subscriptionPlan = userData['subscriptionPlan'];
            } else if (userData['planId'] != null) {
              _subscriptionPlan = 'Premium (Plan ${userData['planId']})';
            } else {
              _subscriptionPlan = isSub ? 'Premium' : null;
            }
            _initialStatusLoaded = true;
          });
        }
        // Send Telemetry
        ApiService.sendTelemetry(user.uid);

        if (_channelsHasError &&
            _newsHasError &&
            _matchesHasError &&
            _goalsHasError &&
            _highlightsHasError &&
            _categoriesHasError) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              if (kIsWeb) removeWebSplash();
            });
          }
          return;
        }

        try {
          // 🛑 OPTIMIZATION: Process directly on Main Thread to avoid Web Isolate Serialization Crash
          debugPrint('Processing data on Main Thread (Authenticated)...');
          final processedData = await _processFetchedData(fetchedResults);

          if (mounted) {
            setState(() {
              channels = processedData['channels'] ?? [];
              news = processedData['news'] ?? [];
              matches = processedData['matches'] ?? [];
              goals = processedData['goals'] ?? [];
              highlights = processedData['highlights'] ?? [];
              _filteredChannels = channels;

              _isLoading = false;
              if (kIsWeb) removeWebSplash();
            });
          }
        } catch (e) {
          debugPrint('Error processing data: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              if (kIsWeb) removeWebSplash();
            });
          }
        }

        return; // Exit early as we've handled the logged-in case
      }
    } catch (e) {
      debugPrint('Error during logged-in initData: $e');
    }

    // Guest login or error branch
    final List<Future<dynamic>> guestFutures = [
      ApiService.fetchChannels(authToken: token).catchError((e) {
        debugPrint('Error fetching channels: $e');
        if (mounted) setState(() => _channelsHasError = true);
        return <dynamic>[];
      }),
      ApiService.fetchNews(authToken: token).catchError((e) {
        debugPrint('Error fetching news: $e');
        if (mounted) setState(() => _newsHasError = true);
        return <dynamic>[];
      }),
      ApiService.fetchMatches(authToken: token).catchError((e) {
        debugPrint('Error fetching matches: $e');
        if (mounted) setState(() => _matchesHasError = true);
        return <Match>[];
      }),
      ApiService.fetchGoals(authToken: token).catchError((e) {
        debugPrint('Error fetching goals: $e');
        if (mounted) setState(() => _goalsHasError = true);
        return <dynamic>[];
      }),
      ApiService.fetchHighlights(authToken: token).catchError((e) {
        debugPrint('Error fetching highlights: $e');
        if (mounted) setState(() => _highlightsHasError = true);
        return <Highlight>[];
      }),
      ApiService.fetchCategories(authToken: token).catchError((e) {
        debugPrint('Error fetching categories: $e');
        if (mounted) setState(() => _categoriesHasError = true);
        return <dynamic>[];
      }),
    ];

    final fetchedResults = await Future.wait(guestFutures);

    if (_channelsHasError &&
        _newsHasError &&
        _matchesHasError &&
        _goalsHasError &&
        _highlightsHasError &&
        _categoriesHasError) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          if (kIsWeb) removeWebSplash();
        });
      }
      return;
    }

    try {
      // 🛑 OPTIMIZATION: Process directly on Main Thread to avoid Web Isolate Serialization Crash
      debugPrint('Processing data on Main Thread...');
      final processedData = await _processFetchedData(fetchedResults);

      if (mounted) {
        setState(() {
          channels = processedData['channels'] ?? [];
          news = processedData['news'] ?? [];
          matches = processedData['matches'] ?? [];
          goals = processedData['goals'] ?? [];
          highlights = processedData['highlights'] ?? [];
          _filteredChannels = channels;
          _isLoading = false;
          if (kIsWeb) removeWebSplash();
        });
      }
    } catch (e) {
      debugPrint('Error processing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          if (kIsWeb) removeWebSplash();
        });
      }
    }
  }

  void _retryLoadingData() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _channelsHasError = false;
        _newsHasError = false;
        _goalsHasError = false;
        _matchesHasError = false;
        _highlightsHasError = false;
        _initData();
      });
    }
  }

  void _retryChannels() {
    if (mounted) {
      setState(() {
        _channelsHasError = false;
      });
      _refreshSection(0);
    }
  }

  void _retryNews() {
    if (mounted) {
      setState(() {
        _newsHasError = false;
      });
      _refreshSection(1);
    }
  }

  void _retryGoals() {
    if (mounted) {
      setState(() {
        _goalsHasError = false;
      });
      _refreshSection(2);
    }
  }

  void _retryMatches() {
    if (mounted) {
      setState(() {
        _matchesHasError = false;
      });
      _refreshSection(3);
    }
  }

  void _retryHighlights() {
    if (mounted) {
      setState(() {
        _highlightsHasError = false;
      });
      _refreshSection(4);
    }
  }

  void _filterChannels(String query) {
    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        _filteredChannels = channels;
      } else {
        _filteredChannels = channels.where((channelCategory) {
          if (channelCategory is Map) {
            String categoryName = channelCategory['name']?.toLowerCase() ?? '';
            if (categoryName.contains(query.toLowerCase())) {
              return true;
            }
            if (channelCategory['channels'] is List) {
              return channelCategory['channels'].any((channel) {
                if (channel is Map) {
                  String channelName = channel['name']?.toLowerCase() ?? '';
                  return channelName.contains(query.toLowerCase());
                }
                return false;
              });
            }
            return false;
          }
          return false;
        }).toList();
      }
    });
  }

  int compareVersions(String version1, String version2) {
    List<String> v1Parts = version1.split('.');
    List<String> v2Parts = version2.split('.');
    int len = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
    for (int i = 0; i < len; i++) {
      int v1 = i < v1Parts.length ? int.tryParse(v1Parts[i]) ?? 0 : 0;
      int v2 = i < v2Parts.length ? int.tryParse(v2Parts[i]) ?? 0 : 0;
      if (v1 < v2) return -1;
      if (v1 > v2) return 1;
    }
    return 0;
  }

  Future<void> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/hussein34535/forceupdate/refs/heads/main/update.json',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final updateUrl = data['update_url'];
        const currentVersion = '4.0.0';

        if (latestVersion != null &&
            updateUrl != null &&
            compareVersions(currentVersion, latestVersion) < 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showUpdateDialog(updateUrl);
            }
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showTelegramDialog(context, userName: _userName);
            }
          });
        }
      } else if (mounted) {
        showTelegramDialog(context, userName: _userName);
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        // Prevent SnackBar from appearing over the Splash Screen
        if (mounted && !_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'فشل التحقق من التحديث. يرجى التحقق من اتصالك بالإنترنت.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void showUpdateDialog(String updateUrl) {
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha((0.8 * 255).round()),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (
        BuildContext buildContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Theme.of(
              context,
            ).scaffoldBackgroundColor.withAlpha((255 * 0.9).round()),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          "⚠️ تحديث إجباري",
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "هناك تحديث جديد إلزامي للتطبيق. الرجاء التحديث للاستمرار في استخدام التطبيق.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () async {
                            final Uri uri = Uri.parse(updateUrl);
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'لا يمكن فتح رابط التحديث.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'حدث خطأ عند فتح الرابط.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 12,
                            ),
                            child: Text(
                              "تحديث الآن",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  void openVideo(
    BuildContext context,
    String? initialUrl,
    List<Map<String, dynamic>> streamLinks,
    String sourceSection, {
    int? contentId,
    bool isPremium = false,
  }) async {
    // WEB SPECIFIC: Skip all ad/premium logic on web for now (or handle differently)
    // If premium logic is needed on web, it should be mirrored here.
    // For now, adhering to existing web skip.
    if (kIsWeb) {
      _navigateToVideoPlayer(context, initialUrl ?? '', streamLinks);
      return;
    }

    // --- PREMIUM CONTENT UNLOCK LOGIC ---
    if (isPremium) {
      // Map sourceSection to API type (singular form)
      String apiType = sourceSection;
      if (sourceSection == 'channels') apiType = 'channel';
      if (sourceSection == 'goals') apiType = 'goal';
      if (sourceSection == 'news') apiType = 'news';
      if (sourceSection == 'matches') apiType = 'match';

      // Navigate IMMEDIATELY to Player. Player will handle fetching/unlocking internally.
      _navigateToVideoPlayer(
        context,
        initialUrl ?? '',
        streamLinks,
        isLocked: true,
        contentId: contentId,
        category: apiType,
      );
      return;
    }

    // Direct Navigation (Ads Removed)
    _navigateToVideoPlayer(context, initialUrl ?? '', streamLinks);
  }

  Future<void> _navigateToVideoPlayer(
    BuildContext context,
    String initialUrl,
    List<Map<String, dynamic>> streamLinks, {
    bool isLocked = false,
    int? contentId,
    String? category,
  }) async {
    await navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          initialUrl: initialUrl,
          streamLinks: streamLinks,
          isLocked: isLocked,
          contentId: contentId,
          category: category,
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];

    // Premium Account Icon
    Color packageColor = Colors.amber.shade400;
    if (_subscriptionPlan != null) {
      final plan = _subscriptionPlan!.toLowerCase();
      if (plan.contains('شهري') || plan.contains('month')) {
        packageColor = Colors.blue.shade400;
      } else if (plan.contains('سنوي') || plan.contains('year')) {
        packageColor = Colors.amber.shade400;
      } else if (plan.contains('اسبوع') || plan.contains('week')) {
        packageColor = Colors.green.shade400;
      }
    }

    actions.add(
      Padding(
        padding: EdgeInsets.only(
          left: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
              ? 10.0
              : 8.0,
          right: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
              ? 10.0
              : 8.0,
          bottom: 12.0, // Comfortable space below the icon
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: Hero(
            tag: 'profile_avatar',
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isSubscribed
                          ? [packageColor, packageColor.withValues(alpha: 0.6)]
                          : [Colors.grey.shade700, Colors.grey.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28, // Standardized large radius for all platforms
                    backgroundColor: const Color(0xFF121212),
                    backgroundImage: _userProfileImage != null
                        ? NetworkImage(_userProfileImage!)
                        : null,
                    child: _userProfileImage != null
                        ? null
                        : (_userName != null && _userName!.isNotEmpty
                            ? Text(
                                _userName![0].toUpperCase(),
                                style: TextStyle(
                                  color: _isSubscribed
                                      ? packageColor
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: (!kIsWeb &&
                                          defaultTargetPlatform ==
                                              TargetPlatform.windows)
                                      ? 18
                                      : 12,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color:
                                    _isSubscribed ? packageColor : Colors.white,
                                size: (!kIsWeb &&
                                        defaultTargetPlatform ==
                                            TargetPlatform.windows)
                                    ? 24
                                    : 16,
                              )),
                  ),
                ),
                if (_isSubscribed && _subscriptionExpiryDays != null)
                  Positioned(
                    bottom: -10, // Moved lower as requested
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853), // Vivid Green (A700)
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 24),
                      alignment: Alignment.center,
                      child: Text(
                        '${_subscriptionExpiryDays!.replaceAll(RegExp(r'[^0-9]'), '')} يوم',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return actions;
  }

  Widget _buildSearchBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withAlpha((0.5 * 255).round()),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث عن قناة...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    isDense: true,
                  ),
                  onChanged: _filterChannels,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _isSearchBarVisible = false;
                    _searchController.clear();
                    _filterChannels('');
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshSection(int index) async {
    if (!mounted) return;

    setState(() {
      switch (index) {
        case 0:
          _channelsHasError = false;
          break;
        case 1:
          _newsHasError = false;
          break;
        case 2:
          _goalsHasError = false;
          break;
        case 3:
          _matchesHasError = false;
          break;
        case 4:
          _highlightsHasError = false;
          break;
      }
    });

    try {
      switch (index) {
        case 0:
          try {
            final user = FirebaseAuth.instance.currentUser;
            final token = await user?.getIdToken();

            final List<dynamic> results = await Future.wait([
              ApiService.fetchChannels(authToken: token),
              ApiService.fetchCategories(authToken: token),
            ]);
            final fetchedChannels = results[0];
            final fetchedCategories = results[1];

            // 🛑 OPTIMIZATION: Process directly on Main Thread
            final processedChannels = await _processRefreshedChannelsData([
              fetchedChannels,
              fetchedCategories,
            ]);

            if (mounted) {
              setState(() {
                channels = processedChannels;
                _filterChannels(_searchController.text);
                _channelsHasError = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _channelsHasError = true;
                channels = [];
                _filterChannels('');
              });
            }
          }
          break;
        case 1:
          try {
            final fetchedNews = await ApiService.fetchNews();
            // 🛑 OPTIMIZATION: Process directly on Main Thread
            final processedNews = await _processRefreshedNewsData(fetchedNews);

            if (mounted) {
              setState(() {
                news = processedNews;
                _newsHasError = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _newsHasError = true;
                news = [];
              });
            }
          }
          break;
        case 2:
          try {
            final fetchedGoals = await ApiService.fetchGoals();
            // 🛑 OPTIMIZATION: Process directly on Main Thread
            final processedGoals = await _processRefreshedGoalsData(
              fetchedGoals,
            );

            if (mounted) {
              setState(() {
                goals = processedGoals;
                _goalsHasError = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _goalsHasError = true;
                goals = [];
              });
            }
          }
        case 3:
          try {
            final fetchedMatches = await ApiService.fetchMatches();
            if (mounted) {
              setState(() {
                matches = fetchedMatches;
                _matchesHasError = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _matchesHasError = true;
                matches = [];
              });
            }
          }
          break;
        case 4:
          try {
            final fetchedHighlights = await ApiService.fetchHighlights();
            if (mounted) {
              setState(() {
                highlights = fetchedHighlights;
                _highlightsHasError = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _highlightsHasError = true;
                highlights = [];
              });
            }
          }
          break;
      }
    } catch (e) {
      // Ignore errors during individual section refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    // LOADING STATE: Match HTML Splash (Full Screen, Black, Centered Logo)
    // WEB ONLY as requested
    // LOADING STATE: Match HTML Splash (Full Screen, Black, Centered Logo)
    // WEB ONLY as requested
    if (kIsWeb && _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C52D8)),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(AppBar().preferredSize.height),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
            color: Theme.of(context).appBarTheme.backgroundColor,
          ),
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Theme.of(context).cardColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (BuildContext context) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (_userName != null)
                              ListTile(
                                leading: Icon(
                                  Icons.person,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 28,
                                ),
                                title: Text(
                                  _userName ?? 'المستخدم',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showEditNameDialog();
                                  },
                                ),
                              ),
                            const Divider(),
                            // Theme Mode Toggle in Menu
                            ListTile(
                              leading: Icon(
                                _isDarkMode
                                    ? Icons.dark_mode
                                    : Icons.light_mode,
                                color: Colors.amber,
                              ),
                              title: const Text('وضع التشغيل'),
                              trailing: Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value: _isDarkMode,
                                  activeThumbColor: Colors.purple,
                                  onChanged: (value) {
                                    setState(() {
                                      _isDarkMode = value;
                                    });
                                    widget.onThemeChanged(value);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.notifications_active_outlined,
                                color: Colors.blue,
                              ),
                              title: const Text('التنبيهات'),
                              onTap: () {
                                Navigator.pop(context);
                                // Notifications logic
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.diamond,
                                color: Colors.amber,
                              ),
                              title: const Text(
                                'الاشتراك المميز',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SubscriptionScreen(),
                                  ),
                                );
                              },
                            ),

                            ListTile(
                              leading: Icon(
                                Icons.color_lens,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              title: Text(
                                'تخصيص الألوان',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge!.color,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ThemeCustomizationScreen(),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                FontAwesomeIcons.telegram,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              title: Text(
                                'Telegram',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge!.color,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                final Uri telegramUri = Uri.parse(
                                  'https://t.me/tv_7esen',
                                );
                                try {
                                  if (await canLaunchUrl(telegramUri)) {
                                    await launchUrl(
                                      telegramUri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'لا يمكن فتح رابط التحديث.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'حدث خطأ عند فتح الرابط.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              title: Text(
                                'البحث',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge!.color,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _isSearchBarVisible = true;
                                });
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.privacy_tip_rounded,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              title: Text(
                                'سياسة الخصوصية',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge!.color,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PrivacyPolicyPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            title: Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _userName != null
                        ? RichText(
                            textAlign:
                                Directionality.of(context) == TextDirection.rtl
                                    ? TextAlign.right
                                    : TextAlign.left,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Cairo',
                              ),
                              children: [
                                const TextSpan(text: 'أهلاً بك '),
                                TextSpan(
                                  text: _userName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    foreground: _isDarkMode
                                        ? (Paint()
                                          ..shader = LinearGradient(
                                            colors: <Color>[
                                              Colors.blue.shade800,
                                              Colors.deepPurple.shade700,
                                              Colors.blue.shade500,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ).createShader(
                                            const Rect.fromLTWH(
                                              0.0,
                                              0.0,
                                              200.0,
                                              70.0,
                                            ),
                                          ))
                                        : null,
                                    color: _isDarkMode
                                        ? null
                                        : const Color(0xFFF8F8F8),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            actions: _buildAppBarActions(),
          ),
        ),
      ),
      body: _isSearchBarVisible
          ? _buildSearchBar()
          : Builder(
              builder: (context) {
                // Use _isLoading directly instead of FutureBuilder
                // This prevents loading indicator when returning from other screens
                if (_isLoading && channels.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                } else if (_hasError) {
                  return _buildGeneralErrorWidget();
                } else {
                  return RefreshIndicator(
                    color: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Theme.of(context).cardColor,
                    onRefresh: () => _refreshSection(_selectedIndex),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _buildSectionContent(0), // Channels
                          _buildSectionContent(1), // News
                          _buildSectionContent(2), // Goals
                          _buildSectionContent(3), // Matches
                          _buildSectionContent(4), // Highlights
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        color: _isDarkMode ? Colors.black : const Color(0xFF7C52D8),
        buttonBackgroundColor: Theme.of(context).cardColor,
        animationDuration: const Duration(milliseconds: 300),
        items: [
          const Icon(Icons.tv, size: 30, color: Colors.white),
          Image.asset(
            'assets/replay.png',
            width: 30,
            height: 30,
            color: Colors.white,
          ),
          Image.asset(
            'assets/goal.png',
            width: 30,
            height: 30,
            color: Colors.white,
          ),
          Image.asset(
            'assets/table.png',
            width: 30,
            height: 30,
            color: Colors.white,
          ),
          const Icon(
            Icons.video_library_rounded,
            size: 30,
            color: Colors.white,
          ),
        ],
        index: _selectedIndex,
        onTap: (index) {
          if (!mounted) return;
          setState(() {
            _selectedIndex = index;
          });
        },
        height: 60,
      ),
    );
  }

  Widget _buildGeneralErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 20),
          Text(
            'حدث خطأ أثناء تحميل البيانات.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'الرجاء التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _retryLoadingData,
            icon: const Icon(Icons.replay),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 15),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.replay),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              textStyle: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0: // Channels
        if (_channelsHasError) {
          return _buildSectionErrorWidget(
            'فشل تحميل القنوات. الرجاء المحاولة مرة أخرى.',
            _retryChannels,
          );
        } else {
          debugPrint(
            "DEBUG UI: ChannelsSection receiving (Filtered: ${_filteredChannels.length} / Total: ${channels.length})",
          );
          debugPrint(
            "DEBUG UI: Current Search Query: '${_searchController.text}'",
          );
          return ChannelsSection(
            channelCategories: _filteredChannels,
            openVideo: openVideo,
          );
        }
      case 1: // News
        if (_newsHasError) {
          return _buildSectionErrorWidget(
            'فشل تحميل الأخبار. الرجاء المحاولة مرة أخرى.',
            _retryNews,
          );
        } else {
          return NewsSection(
            newsArticles: Future.value(news),
            openVideo: openVideo,
          );
        }
      case 2: // Goals
        if (_goalsHasError) {
          return _buildSectionErrorWidget(
            'فشل تحميل الأهداف. الرجاء المحاولة مرة أخرى.',
            _retryGoals,
          );
        } else {
          return GoalsSection(
            goalsArticles: Future.value(goals),
            openVideo: openVideo,
            userName: _userName,
          );
        }
      case 3: // Matches
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          return _buildSectionErrorWidget(
            'فشل تحميل المباريات. الرجاء المحاولة مرة أخرى.',
            _retryMatches,
          );
        } else {
          return MatchesSection(
            matches: Future.value(matches),
            openVideo: openVideo,
          );
        }
      case 4: // Highlights
        if (_highlightsHasError) {
          return _buildSectionErrorWidget(
            'فشل تحميل الملخصات. الرجاء المحاولة مرة أخرى.',
            _retryHighlights,
          );
        } else {
          return HighlightsSection(
            highlights: Future.value(highlights),
            openVideo: openVideo,
          );
        }
      default:
        return const Center(child: Text('قسم غير معروف'));
    }
  }
}
