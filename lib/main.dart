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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:day_night_switch/day_night_switch.dart';
import 'package:hesen/video_player_screen.dart';
import 'package:intl/intl.dart';
import 'package:hesen/widgets.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/password_entry_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hesen/telegram_dialog.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:math' as math;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initNotification();
  tz.initializeTimeZones();
  prefs = await SharedPreferences.getInstance();

  await UnityAds.init(
    gameId: '5840220',
    testMode: false,
    onComplete: () {},
    onFailed: (error, message) {},
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _checkFirstTime();
    _createNotificationChannel();
  }

  Future<void> _loadThemeMode() async {
    final savedThemeMode = prefs?.getString('themeMode');
    if (savedThemeMode != null) {
      setState(() {
        _themeMode =
            savedThemeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  Future<void> _saveThemeMode(ThemeMode themeMode) async {
    await prefs?.setString(
        'themeMode', themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> _checkFirstTime() async {
    bool? isFirstTime = prefs?.getBool('isFirstTime');
    setState(() {
      _isFirstTime = isFirstTime == null || isFirstTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7eSen TV',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF673AB7),
        scaffoldBackgroundColor: const Color(0xFF673AB7),
        cardColor: const Color(0xFF673AB7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF673AB7),
          secondary: Color(0xFF00BCD4),
          surface: Colors.white,
          background: Color(0xFF673AB7),
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onBackground: Colors.black,
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF673AB7),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
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
        primaryColor: const Color(0xFF673AB7),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF1C1C1C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1C1C1C),
          secondary: Color.fromARGB(255, 184, 28, 176),
          surface: Color(0xFF1C1C1C),
          background: Colors.black,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.white,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 0, 0, 0),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
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
      themeMode: _themeMode,
      initialRoute: '/home',
      routes: {
        '/home': (context) => _isFirstTime
            ? PasswordEntryScreen(
                key: const ValueKey('password'),
                onCorrectInput: () {
                  setState(() {
                    _isFirstTime = false;
                  });
                  Navigator.pushReplacementNamed(context, '/home');
                },
                prefs: prefs!,
              )
            : HomePage(
                key: const ValueKey('home'),
                onThemeChanged: (isDarkMode) {
                  setState(() {
                    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
                    _saveThemeMode(_themeMode);
                  });
                },
                themeMode: _themeMode,
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
          Map<String, dynamic> newChannel =
              Map<String, dynamic>.from(channelData);
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
  final ThemeMode themeMode;

  const HomePage(
      {super.key, required this.onThemeChanged, required this.themeMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  // Unity Ad Placement IDs
  final String _interstitialPlacementId = 'Interstitial_Android';
  final String _rewardedPlacementId = 'Rewarded_Android';
  Map<String, bool> _adPlacements = {
    'Interstitial_Android': false,
    'Rewarded_Android': false,
  };

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.themeMode == ThemeMode.dark;
    _dataFuture = _initData();
    requestNotificationPermission();
    _loadAds();

    // Load the flag and schedule the dialog if needed
    _checkAndShowTelegramDialog();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          channels = processedData['channels'] as List<dynamic>;
          _filteredChannels = channels; // Initialize filter with processed data
          news = processedData['news'] as List<dynamic>;
          matches = processedData['matches'] as List<Match>;
          goals = processedData['goals'] as List<dynamic>;
        });
      }

      // Step 4: Check for updates (can likely stay here)
      checkForUpdate();
    } catch (e) {
      // print('Error initializing data: $e');
      if (mounted) {
        setState(() {
          // Handle error state if necessary, maybe set lists to empty
          channels = [];
          _filteredChannels = [];
          news = [];
          matches = [];
          goals = [];
        });
      }
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
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/hussein34535/forceupdate/refs/heads/main/update.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final updateUrl = data['update_url'];
        const currentVersion = '1.0.5';

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
      } else {
        // print(
        //     'Failed to fetch update check. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // print('Error during update check: $e');
    }
  }

  void showUpdateDialog(String updateUrl) {
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha((0.8 * 255).round()),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext buildContext, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Theme.of(context)
                .scaffoldBackgroundColor
                .withAlpha((255 * 0.9).round()),
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
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'لا يمكن فتح رابط التحديث.')));
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('حدث خطأ عند فتح الرابط.')));
                              }
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 25, vertical: 12),
                            child: Text("تحديث الآن",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
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

  void _loadAds() {
    for (var placementId in _adPlacements.keys) {
      _loadAd(placementId);
    }
  }

  void _loadAd(String placementId) {
    UnityAds.load(
        placementId: placementId,
        onComplete: (placementId) {
          // print('Load Complete $placementId');
          if (mounted) {
            setState(() {
              _adPlacements[placementId] = true;
            });
          }
        },
        onFailed: (placementId, error, message) =>
            {} // print('Load Failed $placementId: $error $message'),
        );
  }

  void openVideo(BuildContext context, String initialUrl,
      List<Map<String, dynamic>> streamLinks, String sourceSection) async {
    // print("openVideo called from: $sourceSection");

    // Determine placement ID and if it's a rewarded ad
    final bool isRewardedSection =
        sourceSection == 'news' || sourceSection == 'goals';
    final String placementId =
        isRewardedSection ? _rewardedPlacementId : _interstitialPlacementId;
    final bool adReady = _adPlacements[placementId] ?? false;

    // print(
    //     "Attempting to show ${isRewardedSection ? 'Rewarded' : 'Interstitial'} Ad ($placementId) for $sourceSection. Ad Ready: $adReady");

    try {
      if (adReady) {
        // Mark ad as used immediately
        if (mounted) {
          setState(() {
            _adPlacements[placementId] = false;
          });
        }

        await UnityAds.showVideoAd(
          placementId: placementId,
          onComplete: (placementId) {
            // print('Video Ad $placementId completed.');
            _navigateToVideoPlayer(context, initialUrl, streamLinks);
            _loadAd(placementId); // Reload the ad
            if (isRewardedSection) {
              // print("Reward earned for watching ad: $placementId");
              // Optional: Show a confirmation message to the user about the reward
            }
          },
          onFailed: (placementId, error, message) {
            // print('Video Ad $placementId failed: $error $message');
            _navigateToVideoPlayer(context, initialUrl, streamLinks);
            _loadAd(placementId); // Attempt to reload the ad anyway
          },
          onStart: (placementId) =>
              {}, // print('Video Ad $placementId started.'),
          onClick: (placementId) =>
              {}, // print('Video Ad $placementId clicked.'),
          onSkipped: (placementId) {
            // print('Video Ad $placementId skipped.');
            _loadAd(placementId); // Reload the ad
            // Only navigate if it wasn't a rewarded ad that requires completion
            if (!isRewardedSection) {
              _navigateToVideoPlayer(context, initialUrl, streamLinks);
            } else {
              // Show message that reward requires full watch
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'يجب مشاهدة الإعلان كاملاً للوصول للمحتوى.'))); // Updated message
              }
            }
          },
        );
      } else {
        // print("Unity Ad $placementId not ready, navigating directly.");
        _navigateToVideoPlayer(context, initialUrl, streamLinks);
        // Still try to load the ad for next time
        _loadAd(placementId);
      }
    } catch (e) {
      // print("Error showing Unity Ad ($placementId): $e");
      _navigateToVideoPlayer(context, initialUrl, streamLinks);
      _loadAd(placementId); // Attempt to reload on error
    }
  }

  void _navigateToVideoPlayer(BuildContext context, String initialUrl,
      List<Map<String, dynamic>> streamLinks) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          initialUrl: initialUrl,
          streamLinks: streamLinks,
        ),
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
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withAlpha((0.5 * 255).round())),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث عن قناة...',
                    hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color),
                    prefixIcon: Icon(Icons.search,
                        color: Theme.of(context).colorScheme.secondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    isDense: true,
                  ),
                  onChanged: _filterChannels,
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: Theme.of(context).textTheme.bodyLarge!.color),
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
              return a['createdAt']
                  .toString()
                  .compareTo(b['createdAt'].toString());
            }
          });

          // Process categories: assign IDs and create new maps with channels sorted by createdAt
          final uuid = Uuid();
          List<Map<String, dynamic>> processedChannels = [];
          for (var categoryData in fetchedChannels) {
            if (categoryData is Map) {
              Map<String, dynamic> newCategory =
                  Map<String, dynamic>.from(categoryData);

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
                    Map<String, dynamic> newChannel =
                        Map<String, dynamic>.from(channelData);
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
                    return a['createdAt']
                        .toString()
                        .compareTo(b['createdAt'].toString());
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
  Future<void> _checkAndShowTelegramDialog() async {
    // Always schedule the dialog to show after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if the widget is still mounted
        showTelegramDialog(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = AppBar().preferredSize.height;
    final additionalOffset = MediaQuery.of(context).padding.top + 2.0;
    final totalOffset = appBarHeight + additionalOffset;

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
              icon: Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (BuildContext context) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: Icon(FontAwesomeIcons.telegram,
                                color: Theme.of(context).colorScheme.secondary),
                            title: Text('Telegram',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color)),
                            onTap: () async {
                              Navigator.pop(context);
                              final Uri telegramUri =
                                  Uri.parse('https://t.me/tv_7esen');
                              try {
                                await launchUrl(telegramUri,
                                    mode: LaunchMode.externalApplication);
                              } catch (e) {
                                // print(
                                //     'Error launching URL in external app: $e');
                                try {
                                  await launchUrl(telegramUri,
                                      mode: LaunchMode.inAppWebView);
                                } catch (e) {
                                  // print('Error launching URL in browser: $e');
                                }
                              }
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.search,
                                color: Theme.of(context).colorScheme.secondary),
                            title: Text('البحث',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color)),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _isSearchBarVisible = true;
                              });
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.privacy_tip_rounded,
                                color: Theme.of(context).colorScheme.secondary),
                            title: Text('سياسة الخصوصية',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color)),
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
                          ListTile(
                            leading: Icon(Icons.share_rounded,
                                color: Theme.of(context).colorScheme.secondary),
                            title: Text('مشاركه التطبيق',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color)),
                            onTap: () async {
                              Navigator.pop(context);
                              Share.share('https://t.me/tv_7esen');
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
                      child: Text('Error loading data',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color)));
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
                          Builder(builder: (context) {
                            // print(
                            //     "--- HomePage build - Passing to ChannelsSection: ---");
                            // print(_filteredChannels);
                            // print(
                            //     "-----------------------------------------------------");
                            return ChannelsSection(
                              channelCategories: _filteredChannels,
                              openVideo: openVideo,
                            );
                          }),
                          NewsSection(
                            newsArticles: Future.value(news),
                            openVideo: openVideo,
                          ),
                          GoalsSection(
                            goalsArticles: Future.value(goals),
                            openVideo: openVideo,
                          ),
                          MatchesSection(
                            matches: Future.value(matches),
                            openVideo: openVideo,
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
          Image.asset('assets/replay.png',
              width: 30, height: 30, color: Colors.white),
          Image.asset('assets/goal.png',
              width: 30, height: 30, color: Colors.white),
          Image.asset('assets/table.png',
              width: 30, height: 30, color: Colors.white),
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
