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
import 'package:lottie/lottie.dart';
import 'package:hesen/video_player_screen.dart';
import 'package:intl/intl.dart';
import 'package:hesen/widgets.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/password_entry_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

SharedPreferences? prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initNotification();
  await MobileAds.instance.initialize();
  prefs = await SharedPreferences.getInstance();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isFirstTime = true; // Keep this for first-time logic.

  @override
  void initState() {
    super.initState();
    _checkFirstTime(); // Check first-time status in initState
  }

//Added this to check if user need to inter the password or not
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
      // Use named routes for navigation
      initialRoute: '/', // Start with the splash screen
      routes: {
        '/': (context) =>
            MySplashScreen(), // Splash screen is the absolute first screen
        '/home': (context) => _isFirstTime
            ? PasswordEntryScreen(
                key: ValueKey('password'),
                onCorrectInput: () {
                  setState(() {
                    _isFirstTime = false; // Correctly set _isFirstTime
                  });
                },
                prefs: prefs!,
              )
            : HomePage(
                key: ValueKey('home'),
                onThemeChanged: (isDarkMode) {
                  setState(() {
                    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
                  });
                },
                themeMode: _themeMode,
              ),
        // Other routes
        '/Notification_screen': (context) => const NotificationPage(),
      },
      navigatorKey: navigatorKey,
    );
  }
}

// --- Splash Screen ---
class MySplashScreen extends StatefulWidget {
  const MySplashScreen({super.key});

  @override
  _MySplashScreenState createState() => _MySplashScreenState();
}

class _MySplashScreenState extends State<MySplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start the timer to navigate to the main screen after 3 seconds
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(
          context, '/home'); // Navigate using named route
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.black, // Black background
            width: double.infinity,
            height: double.infinity,
          ),
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 2,
              child: Image.asset('assets/icon/icon.png'),
            ), // Centered image
          ),
        ],
      ),
    );
  }
}

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
  bool _isDarkMode = true;
  bool _isSearchBarVisible = false;
  Completer<void>? _drawerCloseCompleter;

  @override
  void initState() {
    super.initState();
    _dataFuture = _initData();
    requestNotificationPermission();
    _isDarkMode = widget.themeMode == ThemeMode.dark;
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
      // Handle errors appropriately, maybe log them
      return []; // Return an empty list on error
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

  Future<void> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/7essen/forceupdate/main/latestversion.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final updateUrl = data['update_url'];
        const currentVersion = '1.0.0'; // Replace with your app's version

        if (currentVersion != latestVersion) {
          showUpdateDialog(updateUrl);
        }
      }
    } catch (e) {
      // Handle errors, e.g., no internet connection
    }
  }

  void showUpdateDialog(String updateUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          titleTextStyle: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
              fontWeight: FontWeight.bold,
              fontSize: 20), // Bold Title
          contentTextStyle: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .color), // Consistent Content Text
          title: const Text("تحديث متاح"),
          content: const Text(
              "هناك تحديث جديد متاح للتطبيق, الرجاء التحديث للاستمرار."),
          backgroundColor:
              Theme.of(context).cardColor, // Dialog background color from theme
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("لاحقاً",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold)), // Bold Button Text
            ),
            TextButton(
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(updateUrl))) {
                  await launchUrl(Uri.parse(updateUrl));
                }
              },
              child: Text("تحديث",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold)), // Bold Button Text
            ),
          ],
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
          dayColor: Color(0xFFF8F8F8), // Light Grey - Match Light Background
          nightColor: Color(0xFF0A0A0A), // Near Black - Match Dark Background
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
    final additionalOffset =
        MediaQuery.of(context).padding.top + 2.0; // Add 2.0 to the top padding
    final totalOffset = appBarHeight + additionalOffset;

    // لون أفتح قليلاً من البنفسجي الأساسي
    final navBarBackgroundColor = Color(0xFF7C52D8);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300), // Smooth transition
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // Subtle Shadow
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, 1), // Slightly shifted shadow
              ),
            ],
            color: Theme.of(context)
                .appBarTheme
                .backgroundColor, // Use theme's AppBar color
          ),
          child: AppBar(
            elevation: 0, // Remove default elevation
            leading: IconButton(
              // IconButton for the drawer
              icon: Icon(Icons.menu_rounded,
                  color: Colors.white), // Rounded menu icon, white color
              onPressed: () {
                showModalBottomSheet(
                  // Show BottomSheet on icon press
                  context: context,
                  backgroundColor: Theme.of(context)
                      .cardColor, // Background color from theme card color
                  shape: RoundedRectangleBorder(
                    // Rounded edges for the BottomSheet
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16)), // Slightly less rounded
                  ),
                  builder: (BuildContext context) {
                    return Padding(
                      // Padding for the list from all sides
                      padding: const EdgeInsets.symmetric(
                          vertical: 16.0), // Reduced padding
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: Icon(FontAwesomeIcons.telegram,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary), // Use secondary color for icons
                            title: Text('Telegram',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold, // Bold Menu Items
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
                                // Fallback: Try launching in the in-app browser
                                try {
                                  await launchUrl(telegramUri,
                                      mode: LaunchMode.inAppWebView);
                                } catch (e) {
                                  print('Error launching URL in browser: $e');
                                  // Handle the error (e.g., show a message to the user)
                                }
                              }
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.search,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary), // Use secondary color for icons
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary), // Use secondary color for icons
                            title: Text('سياسة الخصوصية',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold, // Bold Menu Items
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary), // Use secondary color for icons
                            title: Text('مشاركه التطبيق',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold, // Bold Menu Items
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : const Color(0xFF673AB7),
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.primary
            : navBarBackgroundColor,
        buttonBackgroundColor: Theme.of(context).cardColor,
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

  void openVideo(BuildContext context, String initialUrl,
      List<Map<String, dynamic>> streamLinks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          initialUrl: initialUrl,
          streamLinks: streamLinks,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardColor, // Card color for search bar background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .secondary
                .withOpacity(0.6)), // Slightly transparent secondary border
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'بحث عن قناة',
          hintStyle:
              TextStyle(color: Colors.grey.shade500), // Lighter grey hint
          prefixIcon: Icon(Icons.search,
              color: Theme.of(context)
                  .colorScheme
                  .secondary), // Secondary color search icon
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16), // Horizontal padding
        ),
        onChanged: (query) {
          _filterChannels(query);
        },
        style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyLarge!
                .color), // Text color from theme
      ),
    );
  }
}
