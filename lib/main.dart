import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hesen/firebase_api.dart';
import 'package:hesen/notification_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/models/match_model.dart';
import 'package:uuid/uuid.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:day_night_switch/day_night_switch.dart';
import 'package:hesen/video_player_screen.dart';
import 'package:hesen/widgets.dart';
import 'dart:async';
import 'package:hesen/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hesen/theme_customization_screen.dart';
import 'dart:io';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _createNotificationChannel() async {
  var android = const AndroidInitializationSettings('@mipmap/ic_launcher');
  var iOS = const DarwinInitializationSettings();
  var initSettings = InitializationSettings(android: android, iOS: iOS);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  var androidNotificationChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidNotificationChannel);
}

SharedPreferences? prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: './.env');

  // التحقق من عدم تهيئة التطبيق قبل الاستدعاء
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // Firebase app already initialized, safe to ignore
    } else {
      rethrow; // Re-throw other Firebase exceptions
    }
  }
  if (!kIsWeb) {
    final firebaseApi = FirebaseApi();
    await firebaseApi.initNotification();
  }
  tz.initializeTimeZones();
  prefs = await SharedPreferences.getInstance();

  if (!kIsWeb) {
    await UnityAds.init(
      gameId: '5840220',
      testMode: false,
      onComplete: () {},
      onFailed: (error, message) {},
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _createNotificationChannel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Hesen TV',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: themeProvider.getPrimaryColor(false),
        scaffoldBackgroundColor: themeProvider.getScaffoldBackgroundColor(
          false,
        ),
        cardColor: themeProvider.getCardColor(false),
        colorScheme: ColorScheme.light(
          primary: themeProvider.getPrimaryColor(false),
          secondary: themeProvider.getSecondaryColor(false),
          surface: Colors.white,
          background: themeProvider.getScaffoldBackgroundColor(false),
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onBackground: Colors.black,
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: themeProvider.getAppBarBackgroundColor(false),
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
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: themeProvider.getPrimaryColor(true),
        scaffoldBackgroundColor: themeProvider.getScaffoldBackgroundColor(true),
        cardColor: themeProvider.getCardColor(true),
        colorScheme: ColorScheme.dark(
          primary: themeProvider.getPrimaryColor(true),
          secondary: themeProvider.getSecondaryColor(true),
          surface: const Color(0xFF1C1C1C),
          background: themeProvider.getScaffoldBackgroundColor(true),
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.white,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: themeProvider.getAppBarBackgroundColor(true),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white),
        ),
      ),
      initialRoute: '/home',
      routes: {
        '/home': (context) => HomePage(
              key: const ValueKey('home'),
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
  }
}

// --- Top-level function for background processing ---
Future<Map<String, dynamic>> _processFetchedData(List<dynamic> results) async {
  final fetchedChannels = results[0] as List<dynamic>;
  final fetchedNews = results[1] as List<dynamic>;
  final fetchedMatches = results[2] as List<Match>;
  final fetchedGoals = results[3] as List<dynamic>;

  final uuid = Uuid();
  // print("--- BACKGROUND: Processing Channels --- ");

  // Sort categories by createdAt
  // Use try-catch for robust parsing
  List<Map<String, dynamic>> sortedCategories = [];
  for (var categoryData in fetchedChannels) {
    if (categoryData is Map) {
      sortedCategories.add(Map<String, dynamic>.from(categoryData));
    }
  }
  sortedCategories.sort((a, b) {
    if (a['createdAt'] == null || b['createdAt'] == null) return 0;
    try {
      final dateA = DateTime.parse(a['createdAt'].toString());
      final dateB = DateTime.parse(b['createdAt'].toString());
      return dateA.compareTo(dateB);
    } catch (e) {
      return a['createdAt'].toString().compareTo(b['createdAt'].toString());
    }
  });

  // Process categories: assign IDs and sort channels
  List<Map<String, dynamic>> processedChannels = [];
  for (var categoryData in sortedCategories) {
    // Iterate sorted categories
    Map<String, dynamic> newCategory =
        categoryData; // Already a new map if needed

    // Assign UUID if category id is null
    if (newCategory['id'] == null) {
      newCategory['id'] = uuid.v4();
    }

    // Sort channels within the category by creation date
    if (newCategory['channels'] is List) {
      List originalChannels = newCategory['channels'];
      List<Map<String, dynamic>> sortedChannelsList = [];

      for (var channelData in originalChannels) {
        if (channelData is Map) {
          Map<String, dynamic> newChannel = Map<String, dynamic>.from(
            channelData,
          );
          if (newChannel['id'] == null) {
            newChannel['id'] = uuid.v4();
          }
          sortedChannelsList.add(newChannel);
        }
      }

      // Sort the new list of channel maps by createdAt
      sortedChannelsList.sort((a, b) {
        if (a['createdAt'] == null || b['createdAt'] == null) return 0;
        try {
          final dateA = DateTime.parse(a['createdAt'].toString());
          final dateB = DateTime.parse(b['createdAt'].toString());
          return dateA.compareTo(dateB);
        } catch (e) {
          return a['createdAt'].toString().compareTo(b['createdAt'].toString());
        }
      });
      newCategory['channels'] = sortedChannelsList;
    } else {
      newCategory['channels'] = [];
    }
    processedChannels.add(newCategory);
  }
  // print("--- BACKGROUND: Processing Complete --- ");

  return {
    'channels': processedChannels,
    'news': fetchedNews,
    'matches': fetchedMatches,
    'goals': fetchedGoals,
  };
}

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const HomePage({super.key, required this.onThemeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<Match> matches = [];
  List<dynamic> channels = [];
  List<dynamic> news = [];
  List<dynamic> goals = [];
  int _selectedIndex = 0;
  Future<void>? _dataFuture;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredChannels = [];
  late bool _isDarkMode;
  bool _isSearchBarVisible = false;
  late TabController _tabController;

  // Unity Ad Placement IDs
  final String _interstitialPlacementId = 'Interstitial_Android';
  final String _rewardedPlacementId = 'Rewarded_Android';

  bool _isAdShowing = false; // -->> أضف هذا المتغير. هذا هو القفل الخاص بنا

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    _dataFuture = _initData();
    requestNotificationPermission();

    // Load the flag and schedule the dialog if needed
    // _checkAndShowTelegramDialog(); // Removed this line

    // Add this line to call the update check function
    checkForUpdate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      // Step 1: Fetch data concurrently (remains the same)
      final results = await Future.wait([
        ApiService.fetchChannelCategories(),
        ApiService.fetchNews(),
        ApiService.fetchMatches(),
        ApiService.fetchGoals(),
      ]);

      // Step 2: Process data in the background using compute
      // print("--- Starting background data processing ---");
      final processedData = await compute(_processFetchedData, results);
      // print("--- Finished background data processing ---");

      // Step 3: Update state with processed data (only if mounted)
      if (mounted) {
        setState(() {
          channels = processedData['channels'];
          news = processedData['news'];
          matches = processedData['matches'];
          goals = processedData['goals'];
          _filteredChannels = channels; // Initialize filtered channels
          _tabController = TabController(length: channels.length, vsync: this);
          _tabController.addListener(_handleTabSelection);
        });
      }
    } catch (e) {
      // Handle errors
      debugPrint('Error initializing data: $e');
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
        const currentVersion = '3.0.0';

        if (latestVersion != null &&
            updateUrl != null &&
            compareVersions(currentVersion, latestVersion) < 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showUpdateDialog(updateUrl);
            }
          });
        } else {
          // print('No update required or update data incomplete.');
        }
      } else if (mounted) {
        // If status code is not 200, show the Telegram dialog
        showTelegramDialog();
      }
    } catch (e) {
      // print('Error during update check: $e');
      if (e is http.ClientException || e is SocketException) {
        if (mounted) {
          showTelegramDialog();
        }
      }
    }
  }

  void showTelegramDialog() {
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
                          "⚠️ تحديث تجريبي",
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "تحديث تجريبي به خلل. انضم لقناة التيليجرام للتأكد من التحديثات.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () async {
                            final Uri uri = Uri.parse(
                              'https://t.me/tv_7esen',
                            );
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
                                        'لا يمكن فتح رابط التيليجرام.',
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
                                      'حدث خطأ عند فتح رابط التيليجرام.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "الانضمام لقناة التيليجرام",
                            style: TextStyle(fontSize: 16),
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
    String initialUrl,
    List<Map<String, dynamic>> streamLinks,
    String sourceSection,
  ) async {
    // -->> الخطوة 1: تحقق من القفل في البداية
    if (_isAdShowing) {
      print("Ad is already in progress. Ignoring new request.");
      return; // اخرج من الدالة إذا كان هناك إعلان قيد التشغيل بالفعل
    }

    // -->> الخطوة 2: قم بتفعيل القفل
    setState(() {
      _isAdShowing = true;
    });

    // --- دالة مساعدة لإعادة ضبط القفل (لتقليل تكرار الكود) ---
    void _resetAdLock() {
      if (mounted) {
        setState(() {
          _isAdShowing = false;
        });
      }
    }
    // -----------------------------------------------------------

    final bool isRewardedSection =
        sourceSection == 'news' || sourceSection == 'goals';
    final String placementId =
        isRewardedSection ? _rewardedPlacementId : _interstitialPlacementId;

    // --- State variables for this specific call ---
    bool adLoadFinished = false; // True if load completes or fails
    bool navigationDone = false; // True if navigation to player screen happened
    Timer? loadTimer; // Timer for the 4-second timeout
    // ----

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );

    final BuildContext? capturedNavigatorContext = navigatorKey.currentContext;

    // --- Helper function to safely dismiss dialog and navigate ---
    void dismissAndNavigate() {
      if (navigationDone) return; // Prevent multiple navigations
      navigationDone = true;
      BuildContext effectiveContext = capturedNavigatorContext ?? context;
      if (Navigator.canPop(effectiveContext)) {
        Navigator.pop(effectiveContext);
      }
      _navigateToVideoPlayer(effectiveContext, initialUrl, streamLinks);
    }
    // ----

    // --- Helper function to show ad AFTER navigation ---
    void showAdOverlay(String adPlacementId) {
      // print("showAdOverlay: Showing ad $adPlacementId over video player.");
      UnityAds.showVideoAd(
        placementId: adPlacementId,
        // These callbacks DON'T navigate
        onComplete: (pid) {}, // print("Overlay Ad $pid Complete"),
        onFailed:
            (pid, err, msg) {}, // print("Overlay Ad $pid Failed: $err $msg"),
        onStart: (pid) {}, // print("Overlay Ad $pid Start"),
        onClick: (pid) {}, // print("Overlay Ad $pid Click"),
        onSkipped: (pid) {
          // print("Overlay Ad $pid Skipped");
          if (isRewardedSection) {
            // Still show message even if it's an overlay
            BuildContext effectiveContext = capturedNavigatorContext ?? context;
            ScaffoldMessenger.of(effectiveContext).showSnackBar(
              const SnackBar(
                content: Text('يجب مشاهدة الإعلان كاملاً للوصول للمحتوى.'),
              ),
            );
          }
        },
      );
    }
    // ----

    // Start the 4-second timer
    loadTimer = Timer(const Duration(seconds: 4), () {
      print("Ad load timer expired.");
      _resetAdLock(); // <-- أعد ضبط القفل هنا
      if (!adLoadFinished) {
        print("Timeout occurred before ad load finished. Navigating early.");
        dismissAndNavigate(); // Navigate early, ad load continues
      }
    });

    // Attempt to load the ad
    try {
      UnityAds.load(
        placementId: placementId,
        onComplete: (loadedPlacementId) async {
          // print("UnityAds.load complete: $loadedPlacementId");
          if (adLoadFinished)
            return; // Already handled (e.g., by failure or previous complete)
          adLoadFinished = true;
          loadTimer?.cancel();

          if (navigationDone) {
            // Navigation already happened due to timeout
            // print("Ad loaded AFTER timeout/navigation. Showing as overlay.");
            showAdOverlay(loadedPlacementId);
          } else {
            // Ad loaded within the 4-second timeout
            // print("Ad loaded WITHIN timeout. Dismissing dialog and showing ad now.");
            BuildContext effectiveContext = capturedNavigatorContext ?? context;
            if (Navigator.canPop(effectiveContext)) {
              Navigator.pop(effectiveContext); // Dismiss dialog FIRST
            }

            // Show the ad, and navigate AFTER it finishes/fails/skips
            await UnityAds.showVideoAd(
              placementId: loadedPlacementId,
              onComplete: (completedPlacementId) {
                _resetAdLock(); // <-- أعد ضبط القفل هنا
                // print("Pre-Nav Ad $completedPlacementId Complete. Navigating.");
                dismissAndNavigate(); // Navigate after completion
              },
              onFailed: (failedPlacementId, error, message) {
                _resetAdLock(); // <-- أعد ضبط القفل هنا
                // print("Pre-Nav Ad $failedPlacementId Failed: $error $message. Navigating.");
                dismissAndNavigate(); // Navigate even on failure to show
              },
              onStart: (startPlacementId) => {},
              onClick: (clickPlacementId) => {},
              onSkipped: (skippedPlacementId) {
                _resetAdLock(); // <-- أعد ضبط القفل هنا
                // print("Pre-Nav Ad $skippedPlacementId Skipped.");
                if (isRewardedSection) {
                  // Don't navigate for skipped rewarded ad, just show message
                  BuildContext effectiveContext =
                      capturedNavigatorContext ?? context;
                  ScaffoldMessenger.of(effectiveContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'يجب مشاهدة الإعلان كاملاً للوصول للمحتوى.',
                      ),
                    ),
                  );
                  // Ensure navigationDone is set so subsequent checks work correctly
                  navigationDone = true;
                } else {
                  // Navigate for skipped non-rewarded ad
                  dismissAndNavigate();
                }
              },
            );
          }
        },
        onFailed: (failedPlacementId, error, message) {
          // print("UnityAds.load failed: $failedPlacementId, $error, $message");
          if (adLoadFinished) return;
          adLoadFinished = true;
          loadTimer?.cancel();

          _resetAdLock(); // <-- أعد ضبط القفل هنا

          if (!navigationDone) {
            // print("Ad load failed WITHIN timeout. Navigating.");
            dismissAndNavigate(); // Navigate if load failed before timeout
          }
          // If navigationDone is true, do nothing (timeout already handled navigation)
        },
      );
    } catch (e) {
      // print("Error during UnityAds.load call: $e");
      loadTimer.cancel();
      _resetAdLock(); // <-- أعد ضبط القفل هنا
      if (!navigationDone) {
        // print("Error occurred WITHIN timeout. Navigating.");
        dismissAndNavigate(); // Navigate on error before timeout
      }
      // If navigationDone is true, do nothing (timeout already handled navigation)
    }
  }

  void _navigateToVideoPlayer(
    BuildContext context,
    String initialUrl,
    List<Map<String, dynamic>> streamLinks,
  ) {
    // Use the root navigator key to push the route
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) =>
            VideoPlayerScreen(initialUrl: initialUrl, streamLinks: streamLinks),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];

    actions.add(
      Transform.scale(
        scale: 0.3,
        child: DayNightSwitch(
          value: _isDarkMode,
          moonImage: AssetImage('assets/moon.png'),
          sunImage: AssetImage('assets/sun.png'),
          onChanged: (value) {
            setState(() {
              _isDarkMode = value;
            });
            widget.onThemeChanged(value);
          },
          dayColor: Color(0xFFF8F8F8),
          nightColor: Color.fromARGB(255, 27, 27, 27),
          sunColor: Color(0xFFF8F8F8),
          moonColor: Color(0xFF0A0A0A),
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

  // Add this function to handle refresh
  Future<void> _refreshSection(int index) async {
    try {
      switch (index) {
        case 0: // Channels
          final fetchedChannels = await ApiService.fetchChannelCategories();
          // print("--- REFRESHED CHANNELS DATA ---");

          // Sort the fetched categories first by their creation date
          fetchedChannels.sort((a, b) {
            if (a is! Map ||
                b is! Map ||
                a['createdAt'] == null ||
                b['createdAt'] == null) return 0;
            try {
              final dateA = DateTime.parse(a['createdAt'].toString());
              final dateB = DateTime.parse(b['createdAt'].toString());
              return dateA.compareTo(dateB);
            } catch (e) {
              // Handle potential parsing errors, fallback to string compare
              return a['createdAt'].toString().compareTo(
                    b['createdAt'].toString(),
                  );
            }
          });

          // Process categories: assign IDs and create new maps with channels sorted by createdAt
          final uuid = Uuid();
          List<Map<String, dynamic>> processedChannels = [];
          for (var categoryData in fetchedChannels) {
            if (categoryData is Map) {
              Map<String, dynamic> newCategory = Map<String, dynamic>.from(
                categoryData,
              );

              // Assign UUID if category id is null
              if (newCategory['id'] == null) {
                newCategory['id'] = uuid.v4();
              }

              // Sort channels within the category by creation date, creating a new list
              if (newCategory['channels'] is List) {
                List originalChannels = newCategory['channels'];
                List<Map<String, dynamic>> sortedChannelsList = [];

                // Assign UUIDs to channels if needed and create new maps
                for (var channelData in originalChannels) {
                  if (channelData is Map) {
                    Map<String, dynamic> newChannel = Map<String, dynamic>.from(
                      channelData,
                    );
                    if (newChannel['id'] == null) {
                      newChannel['id'] = uuid.v4();
                    }
                    sortedChannelsList.add(newChannel);
                  }
                }

                // Sort the new list of channel maps by createdAt
                sortedChannelsList.sort((a, b) {
                  if (a['createdAt'] == null || b['createdAt'] == null)
                    return 0;
                  try {
                    final dateA = DateTime.parse(a['createdAt'].toString());
                    final dateB = DateTime.parse(b['createdAt'].toString());
                    return dateA.compareTo(dateB);
                  } catch (e) {
                    return a['createdAt'].toString().compareTo(
                          b['createdAt'].toString(),
                        );
                  }
                });
                newCategory['channels'] = sortedChannelsList;
              } else {
                newCategory['channels'] = [];
              }
              processedChannels.add(newCategory);
            }
          }
          // print("--- SORTED REFRESHED CHANNELS DATA ---");
          // print(processedChannels);
          // print("-------------------------------------");

          if (mounted) {
            setState(() {
              channels = processedChannels; // Use the processed list
              _filterChannels(_searchController.text);
            });
          }
          break;
        case 1: // News
          final fetchedNews = await ApiService.fetchNews();
          if (mounted) setState(() => news = fetchedNews);
          break;
        case 2: // Goals
          final fetchedGoals = await ApiService.fetchGoals();
          if (mounted) setState(() => goals = fetchedGoals);
          break;
        case 3: // Matches
          final fetchedMatches = await ApiService.fetchMatches();
          if (mounted) setState(() => matches = fetchedMatches);
          break;
      }
    } catch (e) {
      // Handle or log error if needed
      // print("Error refreshing section $index: $e");
    }
  }

  // --- Show Telegram Dialog Logic ---
  // Future<void> _checkAndShowTelegramDialog() async { // Removed this function
  //   // Always schedule the dialog to show after the first frame
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (mounted) {
  //       // Check if the widget is still mounted
  //       showTelegramDialog();
  //     }
  //   });
  // }

  void _handleTabSelection() {
    if (!mounted) return;
    setState(() {
      _selectedIndex = _tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = AppBar().preferredSize.height;
    // final additionalOffset = MediaQuery.of(context).padding.top + 2.0; // Removed

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
            color: Theme.of(context).appBarTheme.backgroundColor,
          ),
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.menu_rounded, color: Colors.white, size: 28),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (BuildContext context) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
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
                                await launchUrl(
                                  telegramUri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (e) {
                                // print(
                                //     'Error launching URL in external app: $e');
                                try {
                                  await launchUrl(
                                    telegramUri,
                                    mode: LaunchMode.inAppWebView,
                                  );
                                } catch (e) {
                                  // print('Error launching URL in browser: $e');
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
                    );
                  },
                );
              },
            ),
            title: Text(
              '7eSen TV',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            actions: _buildAppBarActions(),
          ),
        ),
      ),
      body: _isSearchBarVisible
          ? _buildSearchBar()
          : FutureBuilder<void>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading data',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                  );
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
                          Builder(
                            builder: (context) {
                              // print(
                              //     "--- HomePage build - Passing to ChannelsSection: ---");
                              // print(_filteredChannels);
                              // print(
                              //     "-----------------------------------------------------");
                              return ChannelsSection(
                                channelCategories: _filteredChannels,
                                openVideo: openVideo,
                                isAdLoading:
                                    _isAdShowing, // -->> مرر حالة القفل
                              );
                            },
                          ),
                          NewsSection(
                            newsArticles: Future.value(news),
                            openVideo: openVideo,
                            isAdLoading: _isAdShowing, // -->> مرر حالة القفل
                          ),
                          GoalsSection(
                            goalsArticles: Future.value(goals),
                            openVideo: openVideo,
                            isAdLoading: _isAdShowing, // -->> مرر حالة القفل
                          ),
                          MatchesSection(
                            matches: Future.value(matches),
                            openVideo: openVideo,
                            isAdLoading: _isAdShowing, // -->> مرر حالة القفل
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        color: _isDarkMode ? Colors.black : Color(0xFF7C52D8),
        buttonBackgroundColor: Theme.of(context).cardColor,
        animationDuration: const Duration(milliseconds: 300),
        items: [
          Icon(Icons.tv, size: 30, color: Colors.white),
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
        ],
        index: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        height: 60,
      ),
    );
  }
}
