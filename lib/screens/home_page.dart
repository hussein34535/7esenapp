import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hesen/navigation.dart';
import 'package:hesen/web_utils.dart'
    if (dart.library.io) 'package:hesen/web_utils_stub.dart';
import 'package:hesen/firebase_api.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/services/data_processor.dart';
import 'package:hesen/services/resend_service.dart';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/models/highlight_model.dart';
import 'package:hesen/widgets.dart';
import 'package:hesen/theme_customization_screen.dart';
import 'package:hesen/telegram_dialog.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:hesen/screens/subscription_screen.dart';
import 'package:hesen/screens/profile_screen.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:hesen/video_player_screen.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  // Error tracking
  String _lastError = '';
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
      return;
    }
    // Simulation logic omitted for cleanliness
  }

  Future<void> _checkAndAskForName() async {
    try {
      String? finalName;

      // 1. Try to get name from Firebase Auth (only if Firebase initialized)
      if (AuthService.isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null &&
            user.displayName != null &&
            user.displayName!.isNotEmpty) {
          finalName = user.displayName;
        }
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
                    ApiService.sendTelemetry(user.uid);
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
    // Skip entirely if Firebase failed to initialize
    if (!AuthService.isFirebaseInitialized) {
      debugPrint("MonitorUserStatus: Skipped (Firebase not initialized).");
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ApiService.sendTelemetry(user.uid);
    }

    final prefs = await SharedPreferences.getInstance();
    final currentDeviceId = prefs.getString('device_id');

    // On Windows AND Web, real-time streams can be unstable (Web: NullError crash).
    // We will use a periodic timer or manual checks as a safe alternative.
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      try {
        // FORCE INITIAL FETCH execution
        debugPrint("Web/Windows: Performing initial status check...");
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('device_id');

        if (uid != null) {
          // 1. Load CACHED data first (Instant UI)
          final cachedData = await AuthService().getCachedUserDataOnly();
          if (cachedData != null && mounted) {
            debugPrint("Web/Windows: Loaded cached user data.");
            _updateAppStateWithUserData(cachedData, deviceId);
          }

          // 2. Fetch FRESH data (Background update)
          final initialData = await AuthService().getUserData();
          if (initialData != null && mounted) {
            _updateAppStateWithUserData(initialData, deviceId);
          }
        }
      } catch (e) {
        debugPrint("Monitor User Status (Web) Error: $e");
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

      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final prefs = await SharedPreferences.getInstance();
        final currentDeviceId = prefs.getString('device_id');

        if (uid != null) {
          final statusData = await AuthService().getUserData();
          if (statusData != null && mounted) {
            if (statusData['isSubscribed'] == true) {
              debugPrint(
                "Polling: Subscription detected! Stopping fast polling.",
              );
              _isFastPollingMode = false;
            }
            _updateAppStateWithUserData(statusData, currentDeviceId);
          }
        }
      } catch (e) {
        debugPrint("Polling Error: $e");
      }

      if (mounted && _isFastPollingMode) {
        _scheduleWindowsPolling();
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
      final user = AuthService.isFirebaseInitialized
          ? FirebaseAuth.instance.currentUser
          : null;
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
          authService.getUserData().catchError((e) {
            debugPrint('Error fetching user data: $e');
            return null;
          }),
          ApiService.fetchChannels(authToken: token).catchError((e) {
            debugPrint('Error fetching channels: $e');
            if (mounted)
              setState(() {
                _channelsHasError = true;
                _lastError = 'فشل تحميل القنوات: $e';
              });
            return <dynamic>[];
          }),
          ApiService.fetchNews(authToken: token).catchError((e) {
            debugPrint('Error fetching news: $e');
            if (mounted)
              setState(() {
                _newsHasError = true;
                _lastError = 'فشل تحميل الأخبار: $e';
              });
            return <dynamic>[];
          }),
          ApiService.fetchMatches(authToken: token).catchError((e) {
            debugPrint('Error fetching matches: $e');
            if (mounted)
              setState(() {
                _matchesHasError = true;
                _lastError = 'فشل تحميل المباريات: $e';
              });
            return <Match>[];
          }),
          ApiService.fetchGoals(authToken: token).catchError((e) {
            debugPrint('Error fetching goals: $e');
            if (mounted)
              setState(() {
                _goalsHasError = true;
                _lastError = 'فشل تحميل الأهداف: $e';
              });
            return <dynamic>[];
          }),
          ApiService.fetchHighlights(authToken: token).catchError((e) {
            debugPrint('Error fetching highlights: $e');
            if (mounted)
              setState(() {
                _highlightsHasError = true;
                _lastError = 'فشل تحميل ملخصات: $e';
              });
            return <Highlight>[];
          }),
          ApiService.fetchCategories(authToken: token).catchError((e) {
            debugPrint('Error fetching categories: $e');
            if (mounted)
              setState(() {
                _categoriesHasError = true;
                _lastError = 'فشل تحميل التصنيفات: $e';
              });
            return <dynamic>[];
          }),
        ];

        final results = await Future.wait(initFutures);
        Map<String, dynamic>? userData;
        try {
          userData = results[0] as Map<String, dynamic>?;
        } catch (e) {
          debugPrint('Error casting userData: $e');
        }
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
            if (userData?['subscriptionPlan'] != null) {
              _subscriptionPlan = userData!['subscriptionPlan'];
            } else if (userData?['planId'] != null) {
              _subscriptionPlan = 'Premium (Plan ${userData!['planId']})';
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
          final processedData = await processFetchedData(fetchedResults);

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
        if (mounted)
          setState(() {
            _channelsHasError = true;
            _lastError = 'فشل تحميل القنوات: $e';
          });
        return <dynamic>[];
      }),
      ApiService.fetchNews(authToken: token).catchError((e) {
        debugPrint('Error fetching news: $e');
        if (mounted)
          setState(() {
            _newsHasError = true;
            _lastError = 'فشل تحميل الأخبار: $e';
          });
        return <dynamic>[];
      }),
      ApiService.fetchMatches(authToken: token).catchError((e) {
        debugPrint('Error fetching matches: $e');
        if (mounted)
          setState(() {
            _matchesHasError = true;
            _lastError = 'فشل تحميل المباريات: $e';
          });
        return <Match>[];
      }),
      ApiService.fetchGoals(authToken: token).catchError((e) {
        debugPrint('Error fetching goals: $e');
        if (mounted)
          setState(() {
            _goalsHasError = true;
            _lastError = 'فشل تحميل الأهداف: $e';
          });
        return <dynamic>[];
      }),
      ApiService.fetchHighlights(authToken: token).catchError((e) {
        debugPrint('Error fetching highlights: $e');
        if (mounted)
          setState(() {
            _highlightsHasError = true;
            _lastError = 'فشل تحميل الملخصات: $e';
          });
        return <Highlight>[];
      }),
      ApiService.fetchCategories(authToken: token).catchError((e) {
        debugPrint('Error fetching categories: $e');
        if (mounted)
          setState(() {
            _categoriesHasError = true;
            _lastError = 'فشل تحميل التصنيفات: $e';
          });
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
      final processedData = await processFetchedData(fetchedResults);

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
          _lastError = 'خطأ في معالجة البيانات: $e';
          if (kIsWeb) removeWebSplash();
        });
      }
    }
  }

  Future<void> _retryLoadingData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _channelsHasError = false;
      _newsHasError = false;
      _goalsHasError = false;
      _matchesHasError = false;
      _highlightsHasError = false;
    });
    await _initData();
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
    // WEB SPECIFIC: Previously skipped. Now enabled to support decryption/unlocking on Web.
    // Standard ad logic might still be skipped if initialized as non-web.

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
    final videoScreen = VideoPlayerScreen(
      initialUrl: initialUrl,
      streamLinks: streamLinks,
      isLocked: isLocked,
      contentId: contentId,
      category: category,
    );

    if (kIsWeb) {
      // Web: Use lightweight fade transition (slide composites 2 layers = heavy for WASM)
      await navigatorKey.currentState?.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => videoScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } else {
      // Mobile/Desktop: Keep the standard Material transition
      await navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => videoScreen),
      );
    }
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];

    // Premium Promo Button in AppBar for non-subscribed users
    if (!_isSubscribed) {
      actions.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // Gold to Orange
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.black87,
                size: 18,
              ),
              label: const Text(
                'اشترك الآن',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ),
      );
    }

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
                        ? CachedNetworkImageProvider(_userProfileImage!)
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
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
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
            final user = AuthService.isFirebaseInitialized
                ? FirebaseAuth.instance.currentUser
                : null;
            final token = await user?.getIdToken();

            final List<dynamic> results = await Future.wait([
              ApiService.fetchChannels(authToken: token),
              ApiService.fetchCategories(authToken: token),
            ]);
            final fetchedChannels = results[0];
            final fetchedCategories = results[1];

            // 🛑 OPTIMIZATION: Process directly on Main Thread
            final processedChannels = await processRefreshedChannelsData([
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
            final processedNews = await processRefreshedNewsData(fetchedNews);

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
            final processedGoals = await processRefreshedGoalsData(
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
          break;
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
                                  ).textTheme.bodyLarge?.color ?? Colors.white,
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
                                  ).textTheme.bodyLarge?.color ?? Colors.white,
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
                                  ).textTheme.bodyLarge?.color ?? Colors.white,
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
                                  ).textTheme.bodyLarge?.color ?? Colors.white,
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
            _lastError.isNotEmpty
                ? _lastError
                : 'حدث خطأ أثناء تحميل البيانات.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'الرجاء التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70,
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
          Icon(Icons.wifi_off_rounded, color: Colors.red[400], size: 60),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
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
          return Column(
            children: [
              _buildSubscriptionBanner(),
              Expanded(
                child: ChannelsSection(
                  channelCategories: _filteredChannels,
                  openVideo: openVideo,
                ),
              ),
            ],
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
        if (_matchesHasError) {
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

  Widget _buildSubscriptionBanner() {
    // Detect Windows/Desktop platform for sizing
    final bool isDesktop = (defaultTargetPlatform == TargetPlatform.windows || 
                           defaultTargetPlatform == TargetPlatform.linux || 
                           defaultTargetPlatform == TargetPlatform.macOS) && !kIsWeb;
    
    final double maxBannerWidth = isDesktop ? 1200 : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBannerWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              
              if (!_isSubscribed) {
                // Promo Banner for non-subscribed users
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7C52D8), // Theme main color
                        Color(0xFF4A148C), // Rich Purple
                        Color(0xFF311B92), // Deep Indigo
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Decorative glowing background circle
                        Positioned(
                          right: -30,
                          top: -30,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                          child: Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Text & Icon
                              Expanded(
                                flex: isWide ? 3 : 0,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.workspace_premium_rounded,
                                        color: Colors.amber,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'اشترك في الباقة المميزة لـ حسن TV 👑',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'شاهد كافة القنوات، بدون إعلانات، بجودة عالية وبث مستقر!',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontSize: 12,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isWide) const SizedBox(height: 16),
                              // Subscribe Button
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'اشترك الآن',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black87),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Active subscription banner
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00695C), // Deep Teal
                        Color(0xFF00897B), // Light Teal
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF00E676), // Bright Green
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اشتراكك نشط: ${_subscriptionPlan ?? "الباقة المميزة"} 💎',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                if (_subscriptionExpiryDays != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _subscriptionExpiryDays!,
                                    style: const TextStyle(
                                      color: Color(0xFFB9F6CA), // Light green tint
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'التفاصيل',
                                style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
