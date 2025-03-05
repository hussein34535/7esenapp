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

// Global variable to hold the SharedPreferences instance.  Make nullable.
SharedPreferences? prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initNotification();
  await MobileAds.instance.initialize();

  // Pre-load SharedPreferences *before* running the app
  prefs = await SharedPreferences.getInstance(); // Loading

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isFirstTime = true;
  bool _isLoading = true; // Flag to track loading state

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    // No need to load prefs here; it's already loaded in main()
    bool? isFirstTime = prefs?.getBool('isFirstTime');

    // Simulate a short delay (optional, for demonstration)

    setState(() {
      _isFirstTime = isFirstTime == null || isFirstTime;
      _isLoading = false; // Set loading to false after checking
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7eSen TV',
      theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF512da8),
          scaffoldBackgroundColor: const Color(0xFFf0f0f0),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF512da8),
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.black),
            bodyMedium: TextStyle(color: Colors.black),
            bodySmall: TextStyle(color: Colors.black),
          )),
      darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF512da8),
          scaffoldBackgroundColor: const Color(0xFF0a0a0a),
          cardColor: const Color(0xFF221f1f),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF141414),
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white),
            bodySmall: TextStyle(color: Colors.white),
          )),
      themeMode: _themeMode,
      // home: PasswordEntryScreen(),
      home: AnimatedSwitcher(
        duration: Duration(milliseconds: 300), // Short and smooth
        child: _isLoading
            ? Scaffold(
                body: Center(
                    child: CircularProgressIndicator())) // Improved loading UI
            : _isFirstTime
                ? PasswordEntryScreen(
                    key: ValueKey('password'),
                    onCorrectInput: () {
                      setState(() {
                        _isFirstTime = false;
                      });
                    },
                    prefs: prefs!,
                  )
                : HomePage(
                    key: ValueKey('home'),
                    onThemeChanged: (isDarkMode) {
                      setState(() {
                        _themeMode =
                            isDarkMode ? ThemeMode.dark : ThemeMode.light;
                      });
                    },
                    themeMode: _themeMode,
                  ),
      ),
      navigatorKey: navigatorKey,
      routes: {
        '/Notification_screen': (context) => const NotificationPage(),
      },
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
          title: Text("تحديث متاح"),
          content:
              Text("هناك تحديث جديد متاح للتطبيق, الرجاء التحديث للاستمرار."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("لاحقاً"),
            ),
            TextButton(
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(updateUrl))) {
                  await launchUrl(Uri.parse(updateUrl));
                }
              },
              child: Text("تحديث"),
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

    if (_selectedIndex == 0) {
      actions.add(
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            setState(() {
              _isSearchBarVisible = !_isSearchBarVisible;
            });
          },
        ),
      );
    }

    actions.add(
      Transform.scale(
        scale: 0.4,
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
          dayColor: Color(0xFFf0f0f0),
          nightColor: Color(0xFF141414),
          sunColor: Color(0xFFf0f0f0),
          moonColor: Color(0xFF141414),
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

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300), // Smooth transition
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2), // Shadow color
                spreadRadius: 2,
                blurRadius: 4,
                offset: Offset(0, 2), // Shadow position
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
                  color: Colors.white), // Rounded menu icon
              onPressed: () {
                showModalBottomSheet(
                  // Show BottomSheet on icon press
                  context: context,
                  backgroundColor: Theme.of(context)
                      .cardColor, // Background color from theme
                  shape: RoundedRectangleBorder(
                    // Rounded edges for the BottomSheet
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (BuildContext context) {
                    return Padding(
                      // Padding for the list from all sides
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: Icon(FontAwesomeIcons.telegram,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color),
                            title: Text('Telegram',
                                style: TextStyle(
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
                            leading: Icon(Icons.privacy_tip_rounded,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color),
                            title: Text('سياسة الخصوصية',
                                style: TextStyle(
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
                                    .textTheme
                                    .bodyLarge!
                                    .color),
                            title: Text('مشاركه التطبيق',
                                style: TextStyle(
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
            title: _selectedIndex == 0 && _isSearchBarVisible
                ? _buildSearchBar()
                : Text('7eSen TV'),
            actions: _buildAppBarActions(),
          ),
        ),
      ),
      body: FutureBuilder<void>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error loading data',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color)));
          } else {
            return Padding(
              // Add Padding here to create space below AppBar
              padding: const EdgeInsets.only(
                  top: 10.0), // Adjust the top padding as needed
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
        backgroundColor: Colors.transparent,
        color: widget.themeMode == ThemeMode.light
            ? Color(0xFF512da8)
            : Color(0xFF221f1f),
        items: [
          Image.asset('assets/tv.png',
              width: 30, height: 30, color: Colors.white), // Example icon
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
        color: Colors.grey.shade800, // Darker grey for search bar
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'بحث عن قناة',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 5), // Adjust padding
        ),
        onChanged: (query) {
          _filterChannels(query);
        },
        style: TextStyle(color: Colors.white), // Text color in search bar
      ),
    );
  }
}
