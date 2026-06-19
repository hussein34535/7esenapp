part of 'package:hesen/screens/home_page.dart';

mixin HomePageDataMixin on State<HomePage> {
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
  bool _isFastPollingMode = false;
  DateTime? _fastPollingEndTime;

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

    String? token;
    try {
      final user = AuthService.isFirebaseInitialized
          ? FirebaseAuth.instance.currentUser
          : null;
      if (user != null) {
        token = await user.getIdToken();

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          debugPrint("Windows: Small delay for Firestore safety...");
          await Future.delayed(const Duration(milliseconds: 600));
        }

        final authService = AuthService();
        final List<Future<dynamic>> initFutures = [
          authService.getUserData().catchError((e) {
            debugPrint('Error fetching user data: $e');
            return null;
          }),
          ApiService.fetchChannels(authToken: token).catchError((e) {
            debugPrint('Error fetching channels: $e');
            if (mounted) setState(() { _channelsHasError = true; _lastError = 'فشل تحميل القنوات: $e'; });
            return <dynamic>[];
          }),
          ApiService.fetchNews(authToken: token).catchError((e) {
            debugPrint('Error fetching news: $e');
            if (mounted) setState(() { _newsHasError = true; _lastError = 'فشل تحميل الأخبار: $e'; });
            return <dynamic>[];
          }),
          ApiService.fetchMatches(authToken: token).catchError((e) {
            debugPrint('Error fetching matches: $e');
            if (mounted) setState(() { _matchesHasError = true; _lastError = 'فشل تحميل المباريات: $e'; });
            return <Match>[];
          }),
          ApiService.fetchGoals(authToken: token).catchError((e) {
            debugPrint('Error fetching goals: $e');
            if (mounted) setState(() { _goalsHasError = true; _lastError = 'فشل تحميل الأهداف: $e'; });
            return <dynamic>[];
          }),
          ApiService.fetchHighlights(authToken: token).catchError((e) {
            debugPrint('Error fetching highlights: $e');
            if (mounted) setState(() { _highlightsHasError = true; _lastError = 'فشل تحميل ملخصات: $e'; });
            return <Highlight>[];
          }),
          ApiService.fetchCategories(authToken: token).catchError((e) {
            debugPrint('Error fetching categories: $e');
            if (mounted) setState(() { _categoriesHasError = true; _lastError = 'فشل تحميل التصنيفات: $e'; });
            return <dynamic>[];
          }),
        ];

        final results = await Future.wait(initFutures);
        Map<String, dynamic>? userData;
        try { userData = results[0] as Map<String, dynamic>?; } catch (e) { debugPrint('Error casting userData: $e'); }
        final fetchedResults = results.sublist(1);

        if (mounted && userData != null) {
          final isSub = userData['isSubscribed'] == true;
          DateTime? expiryDateTime;
          final dynamic timestamp = userData['subscriptionEnd'] ??
              userData['subscriptionExpiry'] ?? userData['expiryDate'];
          if (timestamp is DateTime) { expiryDateTime = timestamp; }
          else if (timestamp is String) { expiryDateTime = DateTime.tryParse(timestamp); }
          else if (timestamp != null && timestamp.runtimeType.toString().contains('Timestamp')) {
            expiryDateTime = (timestamp as dynamic).toDate();
          }
          String? daysRemaining;
          if (expiryDateTime != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final expiryDateOnly = DateTime(expiryDateTime.year, expiryDateTime.month, expiryDateTime.day);
            final difference = expiryDateOnly.difference(today).inDays;
            if (difference > 0) { daysRemaining = '$difference يوم متبقي'; }
            else if (difference == 0) { daysRemaining = 'ينتهي اليوم'; }
            else { daysRemaining = 'منتهي'; }
          }
          setState(() {
            _isSubscribed = isSub;
            _subscriptionExpiryDays = daysRemaining;
            if (userData?['subscriptionPlan'] != null) { _subscriptionPlan = userData!['subscriptionPlan']; }
            else if (userData?['planId'] != null) { _subscriptionPlan = 'Premium (Plan ${userData!['planId']})'; }
            else { _subscriptionPlan = isSub ? 'Premium' : null; }
            _initialStatusLoaded = true;
          });
        }
        ApiService.sendTelemetry(user.uid);

        if (_channelsHasError && _newsHasError && _matchesHasError && _goalsHasError && _highlightsHasError && _categoriesHasError) {
          if (mounted) { setState(() { _isLoading = false; _hasError = true; if (kIsWeb) removeWebSplash(); }); }
          return;
        }

        try {
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
          if (mounted) { setState(() { _isLoading = false; _hasError = true; if (kIsWeb) removeWebSplash(); }); }
        }
        return;
      }
    } catch (e) { debugPrint('Error during logged-in initData: $e'); }

    final List<Future<dynamic>> guestFutures = [
      ApiService.fetchChannels(authToken: token).catchError((e) { debugPrint('Error fetching channels: $e'); if (mounted) setState(() { _channelsHasError = true; _lastError = 'فشل تحميل القنوات: $e'; }); return <dynamic>[]; }),
      ApiService.fetchNews(authToken: token).catchError((e) { debugPrint('Error fetching news: $e'); if (mounted) setState(() { _newsHasError = true; _lastError = 'فشل تحميل الأخبار: $e'; }); return <dynamic>[]; }),
      ApiService.fetchMatches(authToken: token).catchError((e) { debugPrint('Error fetching matches: $e'); if (mounted) setState(() { _matchesHasError = true; _lastError = 'فشل تحميل المباريات: $e'; }); return <Match>[]; }),
      ApiService.fetchGoals(authToken: token).catchError((e) { debugPrint('Error fetching goals: $e'); if (mounted) setState(() { _goalsHasError = true; _lastError = 'فشل تحميل الأهداف: $e'; }); return <dynamic>[]; }),
      ApiService.fetchHighlights(authToken: token).catchError((e) { debugPrint('Error fetching highlights: $e'); if (mounted) setState(() { _highlightsHasError = true; _lastError = 'فشل تحميل الملخصات: $e'; }); return <Highlight>[]; }),
      ApiService.fetchCategories(authToken: token).catchError((e) { debugPrint('Error fetching categories: $e'); if (mounted) setState(() { _categoriesHasError = true; _lastError = 'فشل تحميل التصنيفات: $e'; }); return <dynamic>[]; }),
    ];

    final fetchedResults = await Future.wait(guestFutures);

    if (_channelsHasError && _newsHasError && _matchesHasError && _goalsHasError && _highlightsHasError && _categoriesHasError) {
      if (mounted) { setState(() { _isLoading = false; _hasError = true; if (kIsWeb) removeWebSplash(); }); }
      return;
    }

    try {
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
      if (mounted) { setState(() { _isLoading = false; _hasError = true; _lastError = 'خطأ في معالجة البيانات: $e'; if (kIsWeb) removeWebSplash(); }); }
    }
  }

  Future<void> _retryLoadingData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; _hasError = false; _channelsHasError = false;
      _newsHasError = false; _goalsHasError = false; _matchesHasError = false; _highlightsHasError = false;
    });
    await _initData();
  }

  void _retryChannels() { if (mounted) { setState(() { _channelsHasError = false; }); _refreshSection(0); } }
  void _retryNews() { if (mounted) { setState(() { _newsHasError = false; }); _refreshSection(1); } }
  void _retryGoals() { if (mounted) { setState(() { _goalsHasError = false; }); _refreshSection(2); } }
  void _retryMatches() { if (mounted) { setState(() { _matchesHasError = false; }); _refreshSection(3); } }
  void _retryHighlights() { if (mounted) { setState(() { _highlightsHasError = false; }); _refreshSection(4); } }

  Future<void> _refreshSection(int index) async {
    if (!mounted) return;
    setState(() {
      switch (index) {
        case 0: _channelsHasError = false; break;
        case 1: _newsHasError = false; break;
        case 2: _goalsHasError = false; break;
        case 3: _matchesHasError = false; break;
        case 4: _highlightsHasError = false; break;
      }
    });

    try {
      switch (index) {
        case 0:
          try {
            final user = AuthService.isFirebaseInitialized ? FirebaseAuth.instance.currentUser : null;
            final token = await user?.getIdToken();
            final results = await Future.wait([
              ApiService.fetchChannels(authToken: token),
              ApiService.fetchCategories(authToken: token),
            ]);
            final processedChannels = await processRefreshedChannelsData(results);
            if (mounted) { setState(() { channels = processedChannels; _filterChannels(_searchController.text); _channelsHasError = false; }); }
          } catch (e) { if (mounted) { setState(() { _channelsHasError = true; channels = []; _filterChannels(''); }); } }
          break;
        case 1:
          try {
            final fetchedNews = await ApiService.fetchNews();
            final processedNews = await processRefreshedNewsData(fetchedNews);
            if (mounted) { setState(() { news = processedNews; _newsHasError = false; }); }
          } catch (e) { if (mounted) { setState(() { _newsHasError = true; news = []; }); } }
          break;
        case 2:
          try {
            final fetchedGoals = await ApiService.fetchGoals();
            final processedGoals = await processRefreshedGoalsData(fetchedGoals);
            if (mounted) { setState(() { goals = processedGoals; _goalsHasError = false; }); }
          } catch (e) { if (mounted) { setState(() { _goalsHasError = true; goals = []; }); } }
          break;
        case 3:
          try {
            final fetchedMatches = await ApiService.fetchMatches();
            if (mounted) { setState(() { matches = fetchedMatches; _matchesHasError = false; }); }
          } catch (e) { if (mounted) { setState(() { _matchesHasError = true; matches = []; }); } }
          break;
        case 4:
          try {
            final fetchedHighlights = await ApiService.fetchHighlights();
            if (mounted) { setState(() { highlights = fetchedHighlights; _highlightsHasError = false; }); }
          } catch (e) { if (mounted) { setState(() { _highlightsHasError = true; highlights = []; }); } }
          break;
      }
    } catch (e) {
      debugPrint('Refresh section error: $e');
    }
  }

  void _filterChannels(String query) {
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) { _filteredChannels = channels; }
      else {
        _filteredChannels = channels.where((channelCategory) {
          if (channelCategory is Map) {
            String categoryName = channelCategory['name']?.toLowerCase() ?? '';
            if (categoryName.contains(query.toLowerCase())) { return true; }
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

  Future<void> _initNotifications() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return;
    final firebaseApi = FirebaseApi();
    _fcmToken = await firebaseApi.initNotification();
    if (_userName != null && _userName!.isNotEmpty) {
      _sendDeviceInfoToServer(name: _userName!, token: _fcmToken);
    }
  }

  Future<void> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) { await Permission.notification.request(); }
  }

  void _sendDeviceInfoToServer({required String name, required String? token}) {
    if (token == null) return;
  }

  Future<void> _checkAndAskForName() async {
    try {
      String? finalName;
      if (AuthService.isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
          finalName = user.displayName;
        }
      }
      if (finalName == null) {
        final prefs = await SharedPreferences.getInstance();
        finalName = prefs.getString('user_name');
      }
      if (finalName != null && finalName.isNotEmpty) {
        if (mounted) { setState(() { _userName = finalName; }); }
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('user_name') != finalName) { await prefs.setString('user_name', finalName); }
        if (_fcmToken != null) { _sendDeviceInfoToServer(name: _userName ?? "Unknown", token: _fcmToken); }
      } else {
        if (mounted) { _showNameInputDialog(); }
      }
    } catch (e) { debugPrint("_checkAndAskForName Error: $e"); }
  }

  Future<void> _showNameInputDialog() async {
    final nameController = TextEditingController();
    return showDialog<void>(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('مرحباً بك!', textAlign: TextAlign.center),
        content: SingleChildScrollView(child: ListBody(children: [
          const Text('لتقديم تجربة أفضل، الرجاء إدخال اسمك الأول.', textAlign: TextAlign.center),
          const SizedBox(height: 15),
          TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(hintText: 'الاسم الأول', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(
            child: const Text('حفظ'),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', nameController.text);
                if (mounted) {
                  setState(() { _userName = nameController.text; });
                  _sendDeviceInfoToServer(name: _userName!, token: _fcmToken);
                  if (context.mounted) { Navigator.of(context).pop(); }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final nameController = TextEditingController(text: _userName);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('تعديل اسمك', textAlign: TextAlign.center),
        content: TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(hintText: 'الاسم الجديد', border: OutlineInputBorder())),
        actions: [
          TextButton(child: const Text('إلغاء'), onPressed: () { Navigator.of(context).pop(); }),
          TextButton(
            child: const Text('حفظ'),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newName = nameController.text.trim();
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) { debugPrint("User already logged in: ${user.uid}"); ApiService.sendTelemetry(user.uid); }
                await AuthService().updateUserName(newName);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', newName);
                if (mounted) {
                  setState(() { _userName = newName; });
                  if (context.mounted) { Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الاسم بنجاح'), backgroundColor: Colors.green)); }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _monitorUserStatus() async {
    if (!AuthService.isFirebaseInitialized) { debugPrint("MonitorUserStatus: Skipped (Firebase not initialized)."); return; }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) { ApiService.sendTelemetry(user.uid); }

    final prefs = await SharedPreferences.getInstance();
    final currentDeviceId = prefs.getString('device_id');

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      try {
        debugPrint("Web/Windows: Performing initial status check...");
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final deviceId = prefs.getString('device_id');
        if (uid != null) {
          final cachedData = await AuthService().getCachedUserDataOnly();
          if (cachedData != null && mounted) { _updateAppStateWithUserData(cachedData, deviceId); }
          final initialData = await AuthService().getUserData();
          if (initialData != null && mounted) { _updateAppStateWithUserData(initialData, deviceId); }
        }
      } catch (e) { debugPrint("Monitor User Status (Web) Error: $e"); }
      _scheduleWindowsPolling();
      return;
    }

    final stream = AuthService().getUserStream();
    if (stream != null) {
      _userSubscription = stream.listen((snapshot) {
        try {
          if (snapshot.exists && snapshot.data() != null) {
            final dataMap = snapshot.data();
            if (dataMap is Map<String, dynamic>) { _updateAppStateWithUserData(dataMap, currentDeviceId); }
            else if (dataMap is Map) { _updateAppStateWithUserData(Map<String, dynamic>.from(dataMap), currentDeviceId); }
          }
        } catch (e) { debugPrint("Monitor User Status Error: $e"); }
      });
    }
  }

  void startFastPolling() {
    if (_isSubscribed) return;
    debugPrint("Windows: Fast polling activated for 15 minutes.");
    _isFastPollingMode = true;
    _fastPollingEndTime = DateTime.now().add(const Duration(minutes: 15));
    _scheduleWindowsPolling();
  }

  void _scheduleWindowsPolling() {
    _windowsStatusTimer?.cancel();
    if (!_isFastPollingMode) { debugPrint("Windows: Background polling disabled (Eco Mode)."); return; }
    if (_fastPollingEndTime != null && DateTime.now().isAfter(_fastPollingEndTime!)) {
      debugPrint("Windows: Fast polling expired. Polling stopped.");
      _isFastPollingMode = false;
      _fastPollingEndTime = null;
      return;
    }
    const duration = Duration(seconds: 30);
    debugPrint("Windows: Status polling scheduled in ${duration.inSeconds}s (FastMode: Active)");
    _windowsStatusTimer = Timer(duration, () async {
      if (!mounted) return;
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final prefs = await SharedPreferences.getInstance();
        final currentDeviceId = prefs.getString('device_id');
        if (uid != null) {
          final statusData = await AuthService().getUserData();
          if (statusData != null && mounted) {
            if (statusData['isSubscribed'] == true) { _isFastPollingMode = false; }
            _updateAppStateWithUserData(statusData, currentDeviceId);
          }
        }
      } catch (e) { debugPrint("Polling Error: $e"); }
      if (mounted && _isFastPollingMode) { _scheduleWindowsPolling(); }
    });
  }

  void _updateAppStateWithUserData(Map<String, dynamic> data, String? currentDeviceId) {
    if (data['status'] == 'banned') { _handleBannedUser(); }
    if (currentDeviceId != null && data['activeDeviceId'] != null && data['activeDeviceId'] != currentDeviceId) { _handleDuplicateSession(); }

    final isSub = data['isSubscribed'] == true;
    DateTime? expiryDateTime;
    final dynamic timestamp = data['subscriptionEnd'] ?? data['subscriptionExpiry'] ?? data['expiryDate'];
    if (timestamp is DateTime) { expiryDateTime = timestamp; }
    else if (timestamp is String) { expiryDateTime = DateTime.tryParse(timestamp); }
    else if (timestamp != null && timestamp.runtimeType.toString().contains('Timestamp')) { expiryDateTime = (timestamp as dynamic).toDate(); }

    String? daysRemaining;
    if (expiryDateTime != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiryDateOnly = DateTime(expiryDateTime.year, expiryDateTime.month, expiryDateTime.day);
      final difference = expiryDateOnly.difference(today).inDays;
      if (difference > 0) { daysRemaining = '$difference يوم متبقي'; }
      else if (difference == 0) { daysRemaining = 'ينتهي اليوم'; }
      else { daysRemaining = 'منتهي'; }
    }

    if (mounted) {
      if (_initialStatusLoaded && !_isSubscribed && isSub) {
        debugPrint("Subscription ACTIVATED!");
        final userEmail = FirebaseAuth.instance.currentUser?.email;
        if (userEmail != null) { ResendService.sendUserActivationNotification(userEmail); }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل اشتراكك بنجاح! استمتع بالمشاهدة.'), backgroundColor: Colors.green));
      }
      setState(() {
        _isSubscribed = isSub;
        _subscriptionExpiryDays = daysRemaining;
        if (data['subscriptionPlan'] != null) { _subscriptionPlan = data['subscriptionPlan']; }
        else if (data['planId'] != null) { _subscriptionPlan = 'Premium (Plan ${data['planId']})'; }
        else { _subscriptionPlan = isSub ? 'Premium' : null; }
        if (data['image_url'] != null) { _userProfileImage = data['image_url']; }
        else if (data['photoUrl'] != null) { _userProfileImage = data['photoUrl']; }
        _initialStatusLoaded = true;
      });
    }
  }

  void _handleDuplicateSession() async {
    _userSubscription?.cancel();
    await AuthService().signOut();
    if (mounted) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل الخروج', style: TextStyle(color: Colors.orangeAccent)),
          content: const Text('تم تسجيل الدخول من جهاز آخر. لا يسمح بفتح الحساب من أكثر من جهاز في نفس الوقت.'),
          actions: [TextButton(onPressed: () { Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); }, child: const Text('حسناً'))],
        ),
      );
    }
  }

  void _handleBannedUser() async {
    _userSubscription?.cancel();
    await AuthService().signOut();
    if (mounted) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('تم حظر الحساب', style: TextStyle(color: Colors.red)),
          content: const Text('تم حظر حسابك بسبب مخافة الشروط. يرجى التواصل مع الدعم الفني.'),
          actions: [TextButton(onPressed: () { if (navigatorKey.currentState != null) { navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); } }, child: const Text('موافق'))],
        ),
      );
    }
  }

  Future<void> _startInitializationSequence() async {
    await _initData();
    await _initNotifications();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      debugPrint("Windows: Small delay before stream setup...");
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    _monitorUserStatus();
    checkForUpdate().then((_) => _checkAndAskForName());
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
        Uri.parse('https://raw.githubusercontent.com/hussein34535/forceupdate/refs/heads/main/update.json'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final updateUrl = data['update_url'];
        const currentVersion = '4.0.0';
        if (latestVersion != null && updateUrl != null && compareVersions(currentVersion, latestVersion) < 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { _showUpdateDialog(updateUrl); } });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { showTelegramDialog(context, userName: _userName); } });
        }
      } else if (mounted) { showTelegramDialog(context, userName: _userName); }
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException')) {
        if (mounted && !_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل التحقق من التحديث. يرجى التحقق من اتصالك بالإنترنت.'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showUpdateDialog(String updateUrl) {
    if (!mounted) return;
    showGeneralDialog(
      context: context, barrierDismissible: false,
      barrierColor: Colors.black.withAlpha((0.8 * 255).round()),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withAlpha((255 * 0.9).round()),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("⚠️ تحديث إجباري", textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Text("هناك تحديث جديد إلزامي للتطبيق. الرجاء التحديث للاستمرار في استخدام التطبيق.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () async {
                            final Uri uri = Uri.parse(updateUrl);
                            try {
                              if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
                              else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح رابط التحديث.'))); }
                            } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ عند فتح الرابط.'))); } }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            child: Text("تحديث الآن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
}
