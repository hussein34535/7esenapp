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
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hesen/telegram_dialog.dart'; // Import the Telegram dialog

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _createNotificationChannel() async {
  var android =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // Or your app icon
  var iOS = DarwinInitializationSettings();
  var initSettings = InitializationSettings(android: android, iOS: iOS);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  var androidNotificationChannel = AndroidNotificationChannel(
    'high_importance_channel', // Same as in AndroidManifest.xml
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
  // Ensure widgets are initialized first
  // Load environment variables from .env file
  await dotenv.load(fileName: './.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initNotification();
  tz.initializeTimeZones(); // Initialize timezone database
  prefs = await SharedPreferences.getInstance();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode(); // Load theme mode from SharedPreferences
    _checkFirstTime();
    _createNotificationChannel(); // Create the notification channel
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
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1C1C1C),
          secondary: Color.fromARGB(255, 184, 28, 176),
          surface: Color(0xFF1C1C1C),
          background: Color(0xFF0A0A0A),
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
      initialRoute: '/home', // Go directly to home/password check
      routes: {
        // '/': (context) => MySplashScreen(), // Removed custom splash route
        '/home': (context) => _isFirstTime
            ? PasswordEntryScreen(
                key: ValueKey('password'),
                onCorrectInput: () {
                  setState(() {
                    _isFirstTime = false;
                  });
                  Navigator.pushReplacementNamed(
                      context, '/home'); // Re-navigate to home after password
                },
                prefs: prefs!,
              )
            : HomePage(
                key: ValueKey('home'),
                onThemeChanged: (isDarkMode) {
                  setState(() {
                    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
                    _saveThemeMode(
                        _themeMode); // Save theme mode to SharedPreferences
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

// Removed MySplashScreen widget

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode themeMode;

  HomePage({Key? key, required this.onThemeChanged, required this.themeMode})
      : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Match> matches = [];
  List channels = [];
  List news = [];
  int _selectedIndex = 0;
  late Future<List> channelCategories;
  late Future<List> newsArticles;
  late Future<List<Match>> matchesFuture;
  late Future<void> _dataFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List _filteredChannels = [];
  late bool _isDarkMode; // Initialize in initState based on themeMode
  bool _isSearchBarVisible = false;
  // InterstitialAd? _interstitialAd;
  // bool _isAdLoading = false;
  // // Use your real Ad Unit ID here in production
  // final String _interstitialAdUnitId =
  //     'ca-app-pub-2393153600924393/2316622245'; // Production Interstitial Ad ID
  // final String _rewardedAdUnitId =
  //     'ca-app-pub-2393153600924393/1679399820'; // Production Rewarded Ad ID
  // RewardedAd? _rewardedAd;
  // bool _isRewardedAdLoading = false;
  Completer<void>? _drawerCloseCompleter;

  @override
  void initState() {
    super.initState();
    _isDarkMode =
        widget.themeMode == ThemeMode.dark; // Initialize _isDarkMode here
    _dataFuture = _initData();
    requestNotificationPermission();
    // _loadAd(); // Load the interstitial ad
    // _loadRewardedAd(); // Load the rewarded ad

    // Show Telegram dialog after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if the dialog should be shown (e.g., only once per session or based on SharedPreferences)
      // For now, let's show it every time HomePage is initialized.
      showTelegramDialog(context);
    });
  }

  @override
  void dispose() {
    _drawerCloseCompleter?.complete();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    channelCategories = fetchChannelCategories();
    newsArticles = fetchNews();
    matchesFuture = fetchMatches();
    checkForUpdate();
    await Future.wait([channelCategories, newsArticles, matchesFuture]);
  }

  Future<List<Match>> fetchMatches() async {
    try {
      final fetchedMatches = await ApiService.fetchMatches();
      matches = fetchedMatches;
      return fetchedMatches;
    } catch (e) {
      return [];
    }
  }

  Future<List> fetchChannelCategories() async {
    final fetchedChannels = await ApiService.fetchChannelCategories();
    final uuid = Uuid();
    for (var channel in fetchedChannels) {
      if (channel['id'] == null) {
        channel['id'] = uuid.v4();
      }
      for (var streamLink in channel['channels']) {
        if (streamLink['id'] == null) {
          streamLink['id'] = uuid.v4();
        }
      }
    }
    channels = fetchedChannels;
    _filteredChannels = channels;
    return fetchedChannels;
  }

  void _filterChannels(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredChannels = channels;
      } else {
        _filteredChannels = channels.where((channel) {
          String channelName = channel['name']?.toLowerCase() ?? '';
          return channelName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<List> fetchNews() async {
    final fetchedNews = await ApiService.fetchNews();
    news = fetchedNews;
    return fetchedNews;
  }

  // Helper function to compare version strings
  int compareVersions(String version1, String version2) {
    List<String> v1Parts = version1.split('.');
    List<String> v2Parts = version2.split('.');
    int len = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
    for (int i = 0; i < len; i++) {
      int v1 = i < v1Parts.length ? int.parse(v1Parts[i]) : 0;
      int v2 = i < v2Parts.length ? int.parse(v2Parts[i]) : 0;
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
        const currentVersion = '1.0.4'; //

        if (compareVersions(currentVersion, latestVersion) < 0) {
          showUpdateDialog(updateUrl);
        }
      }
    } catch (e) {}
  }

  void showUpdateDialog(String updateUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      barrierColor:
          Colors.black.withOpacity(0.8), // Optional: Darken background
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext buildContext, Animation animation,
          Animation secondaryAnimation) {
        return WillPopScope(
          // To prevent back button dismissal on Android
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Theme.of(context).cardColor,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      "⚠️ تحديث إجباري",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 26),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "هناك تحديث جديد إلزامي للتطبيق. الرجاء التحديث للاستمرار في استخدام التطبيق.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge!.color),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                      ),
                      onPressed: () async {
                        if (await canLaunchUrl(Uri.parse(updateUrl))) {
                          await launchUrl(Uri.parse(updateUrl));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 12),
                        child: Text("تحديث",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ),
                  ],
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
          nightColor: Color(0xFF0A0A0A),
          sunColor: Color(0xFFF8F8F8),
          moonColor: Color(0xFF0A0A0A),
        ),
      ),
    );

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = AppBar().preferredSize.height;
    final additionalOffset = MediaQuery.of(context).padding.top + 2.0;
    final totalOffset = appBarHeight + additionalOffset;

    final navBarBackgroundColor = Color(0xFF7C52D8);

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
              icon: Icon(Icons.menu_rounded, color: Colors.white),
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
                                print(
                                    'Error launching URL in external app: $e');
                                try {
                                  await launchUrl(telegramUri,
                                      mode: LaunchMode.inAppWebView);
                                } catch (e) {
                                  print('Error launching URL in browser: $e');
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
              style: TextStyle(fontWeight: FontWeight.bold),
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
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        ChannelsSection(
                          channelCategories: _filteredChannels,
                          openVideo: openVideo,
                        ),
                        NewsSection(
                          newsArticles: newsArticles,
                          openVideo: openVideo,
                        ),
                        MatchesSection(
                          matches: matchesFuture,
                          openVideo: openVideo,
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
      bottomNavigationBar: CurvedNavigationBar(
        // Background behind the bar matches the scaffold background
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        color: Colors.black, // Bar itself is always black
        buttonBackgroundColor: Theme.of(context)
            .cardColor, // Keep button background theme-aware for contrast
        animationDuration: const Duration(milliseconds: 300),
        items: [
          Image.asset('assets/tv.png',
              width: 30, height: 30, color: Colors.white),
          Image.asset('assets/replay.png',
              width: 30, height: 30, color: Colors.white),
          Image.asset('assets/ball.png',
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

  // Function to load Rewarded Ad
  // void _loadRewardedAd() {
  //   if (_isRewardedAdLoading) {
  //     return;
  //   }
  //   _isRewardedAdLoading = true;
  //   RewardedAd.load(
  //       adUnitId: _rewardedAdUnitId,
  //       request: const AdRequest(),
  //       rewardedAdLoadCallback: RewardedAdLoadCallback(
  //         onAdLoaded: (RewardedAd ad) {
  //           print('$ad loaded.');
  //           _rewardedAd = ad;
  //           _isRewardedAdLoading = false;
  //         },
  //         onAdFailedToLoad: (LoadAdError error) {
  //           print('RewardedAd failed to load: $error');
  //           _rewardedAd = null;
  //           _isRewardedAdLoading = false;
  //         },
  //       ));
  // }

  // Function to load Interstitial Ad
  // void _loadAd() {
  //   if (_isAdLoading) {
  //     return; // Don't load if already loading
  //   }
  //   _isAdLoading = true;
  //   InterstitialAd.load(
  //     adUnitId: _interstitialAdUnitId, // Corrected variable name
  //     request: const AdRequest(),
  //     adLoadCallback: InterstitialAdLoadCallback(
  //       onAdLoaded: (InterstitialAd ad) {
  //         print('$ad loaded.');
  //         _interstitialAd = ad;
  //         _isAdLoading = false;
  //       },
  //       onAdFailedToLoad: (LoadAdError error) {
  //         print('InterstitialAd failed to load: $error');
  //         _isAdLoading = false;
  //         _interstitialAd = null; // Ensure ad is null if loading failed
  //       },
  //     ),
  //   );
  // }

  // Updated openVideo to handle ads based on source
  void openVideo(BuildContext context, String initialUrl,
      List<Map<String, dynamic>> streamLinks, String sourceSection) {
    print("openVideo called from: $sourceSection");

    // if (sourceSection == 'news') {
    //   // --- Show Rewarded Ad for News Section ---
    //   if (_rewardedAd != null) {
    //     print("Attempting to show Rewarded Ad for News.");
    //     _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
    //       onAdShowedFullScreenContent: (RewardedAd ad) =>
    //           print('$ad onAdShowedFullScreenContent.'),
    //       onAdDismissedFullScreenContent: (RewardedAd ad) {
    //         print('$ad onAdDismissedFullScreenContent.');
    //         ad.dispose();
    //         _rewardedAd = null;
    //         _loadRewardedAd(); // Load the next one
    //         // Navigate AFTER ad dismissal
    //         _navigateToVideoPlayer(context, initialUrl, streamLinks);
    //       },
    //       onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
    //         print('$ad onAdFailedToShowFullScreenContent: $error');
    //         ad.dispose();
    //         _rewardedAd = null;
    //         _loadRewardedAd(); // Load the next one
    //         // Navigate directly if ad fails to show
    //         _navigateToVideoPlayer(context, initialUrl, streamLinks);
    //       },
    //     );

    //     _rewardedAd!.show(
    //         onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
    //       print(
    //           '$ad with reward $RewardItem(${reward.amount}, ${reward.type})');
    //       // Handle reward if necessary
    //     });
    //   } else {
    //     print("Rewarded Ad not ready for News, navigating directly.");
    //     _loadRewardedAd(); // Try loading again
    //     _navigateToVideoPlayer(context, initialUrl, streamLinks);
    //   }
    // } else {
    //   // --- Show Interstitial Ad for Channels/Matches Sections ---
    //   final interstitialAdToShow = _interstitialAd;
    //   _interstitialAd = null; // Clear the reference

    //   // Start loading the next interstitial ad immediately
    //   _loadAd();

    //   if (interstitialAdToShow != null) {
    //     print("Attempting to show Interstitial Ad for $sourceSection.");
    //     interstitialAdToShow.fullScreenContentCallback =
    //         FullScreenContentCallback(
    //       onAdShowedFullScreenContent: (InterstitialAd ad) =>
    //           print('$ad onAdShowedFullScreenContent.'),
    //       onAdDismissedFullScreenContent: (InterstitialAd ad) {
    //         print('$ad onAdDismissedFullScreenContent.');
    //         ad.dispose();
    //         // Navigate AFTER ad dismissal using GlobalKey
    //         _navigateToVideoPlayer(context, initialUrl, streamLinks);
    //       },
    //       onAdFailedToShowFullScreenContent:
    //           (InterstitialAd ad, AdError error) {
    //         print('$ad onAdFailedToShowFullScreenContent: $error');
    //         ad.dispose();
    //         // Navigate directly if ad fails to show using GlobalKey
    //         _navigateToVideoPlayer(context, initialUrl, streamLinks);
    //       },
    //     );
    //     interstitialAdToShow.show();
    //   } else {
    //     print(
    //         "Interstitial Ad not ready for $sourceSection, navigating directly.");
    //     // Navigate directly if no ad is loaded
    //     _navigateToVideoPlayer(context, initialUrl, streamLinks);
    //   }
    // }

    _navigateToVideoPlayer(context, initialUrl, streamLinks);
  }

  // Helper function for navigation using GlobalKey
  void _navigateToVideoPlayer(
      BuildContext context, // Context still passed but not used for navigation
      String initialUrl,
      List<Map<String, dynamic>> streamLinks) {
    // Use the GlobalKey to access the NavigatorState safely
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          // BuildContext here is fine
          initialUrl: initialUrl,
          streamLinks: streamLinks,
          // interstitialAd: adToShow, // Removed parameter
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.6)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'بحث عن قناة',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search,
              color: Theme.of(context).colorScheme.secondary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (query) {
          _filterChannels(query);
        },
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
      ),
    );
  }
}
