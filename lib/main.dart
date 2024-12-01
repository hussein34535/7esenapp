import 'package:hesen/firebase_api.dart';
import 'package:hesen/notification_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart'; // تأكد من استيراد هذا الملف
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // استيراد الحزمة المناسبة
import 'package:chewie/chewie.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/models/match_model.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initNotification();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7eSen TV',
      theme: ThemeData(
        primaryColor: Color(0xFF512da8),
        scaffoldBackgroundColor: Color(0xFF673ab7),
        cardColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF512da8),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF512da8),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: HomePage(),
      navigatorKey: navigatorKey,
      routes: {
        '/Notification_screen': (context) => const NotificationPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    _initData();
    requestNotificationPermission();
  }

  Future<void> _initData() async {
    channelCategories = fetchChannelCategories();
    newsArticles = fetchNews();
    matchesFuture = fetchMatches();
    checkForUpdate();
  }

  Future<List<Match>> fetchMatches() async {
    try {
      final fetchedMatches = await ApiService.fetchMatches();
      setState(() {
        matches = fetchedMatches;
      });
      return fetchedMatches;
    } catch (e) {
      print('Error fetching matches: $e');
      return [];
    }
  }

  Future<List> fetchChannelCategories() async {
    final fetchedChannels = await ApiService.fetchChannelCategories();
    setState(() {
      channels = fetchedChannels;
    });
    return fetchedChannels;
  }

  Future<List> fetchNews() async {
    final fetchedNews = await ApiService.fetchNews();
    setState(() {
      news = fetchedNews;
    });
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
        const currentVersion = '1.0.0';
        if (currentVersion != latestVersion) {
          showUpdateDialog(updateUrl);
        }
      }
    } catch (e) {
      print("Error checking for update: $e");
    }
  }

  void showUpdateDialog(String updateUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Update Available"),
          content: Text(
              "A new version of the app is available. Please update to continue."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Later"),
            ),
            TextButton(
              onPressed: () async {
                if (await canLaunch(updateUrl)) {
                  await launch(updateUrl);
                }
              },
              child: Text("Update"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('7eSen TV'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ChannelsSection(
              channelCategories: channelCategories, openVideo: openVideo),
          NewsSection(newsArticles: newsArticles),
          MatchesSection(
              matches: matchesFuture, openVideo: openVideo),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.tv),
            label: 'القنوات',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.newspaper),
            label: 'الأخبار',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.futbol),
            label: 'المباريات',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  void openVideo(BuildContext context, String initialUrl, List<StreamLink> streamLinks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          initialUrl: initialUrl,
          streamLinks: streamLinks.map((link) => {
            'name': link.quality,
            'url': link.url,
          }).toList(),
        ),
      ),
    );
  }
}

class ChannelsSection extends StatelessWidget {
  final Future<List> channelCategories;
  final Function openVideo;

  ChannelsSection({required this.channelCategories, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: channelCategories,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('خطأ في استرجاع القنوات'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لا توجد قنوات لعرضها'));
        } else {
          final categories = snapshot.data!;
          categories.sort((a, b) => a['id'].compareTo(b['id']));
          return ListView.separated(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return ChannelBox(
                  category: categories[index], openVideo: openVideo);
            },
            separatorBuilder: (context, index) => SizedBox(height: 16),
          );
        }
      },
    );
  }
}

class ChannelBox extends StatelessWidget {
  final dynamic category;
  final Function openVideo;

  ChannelBox({required this.category, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Center(
          child: Text(
            category['name'] ?? 'Unknown Category',
            style: TextStyle(
              color: Color(0xFF673ab7),
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CategoryChannelsScreen(
                channels: category['channels'] ?? [],
                openVideo: openVideo,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryChannelsScreen extends StatelessWidget {
  final List channels;
  final Function openVideo;

  CategoryChannelsScreen({required this.channels, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('القنوات'),
      ),
      body: ListView.separated(
        itemCount: channels.length,
        itemBuilder: (context, index) {
          return ChannelTile(channel: channels[index], openVideo: openVideo);
        },
        separatorBuilder: (context, index) => SizedBox(height: 16),
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  final dynamic channel;
  final Function openVideo;

  ChannelTile({required this.channel, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    if (channel == null || channel['name'] == null) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: ListTile(
          title: Center(
            child: Text(
              'Unknown Channel',
              style: TextStyle(
                color: Color(0xFF673ab7),
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    String channelName = channel['name'] ?? 'Unknown Channel';

    List<dynamic> streamLinks = channel['StreamLink'] ?? [];

    String? firstStreamLink;

    if (streamLinks.isNotEmpty) {
      var firstLink = streamLinks[0]['children']?.firstWhere(
        (child) => child['url'] != null,
        orElse: () => null,
      );
      firstStreamLink = firstLink?['url'];
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Center(
          child: Text(
            channelName,
            style: TextStyle(
              color: Color(0xFF673ab7),
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => openVideo(context, firstStreamLink!,
            streamLinks), 
      ),
    );
  }
}

class MatchesSection extends StatelessWidget {
  final Future<List<Match>> matches;
  final Function openVideo;

  const MatchesSection({required this.matches, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Match>>(
      future: matches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ في تحميل المباريات'));
        }

        final matchesList = snapshot.data ?? [];
        if (matchesList.isEmpty) {
          return Center(child: Text('لا توجد مباريات متاحة'));
        }

        return ListView.builder(
          itemCount: matchesList.length,
          itemBuilder: (context, index) {
            return MatchBox(
              match: matchesList[index],
              openVideo: openVideo,
            );
          },
        );
      },
    );
  }
}

class MatchBox extends StatelessWidget {
  final Match match;
  final Function openVideo;

  MatchBox({required this.match, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    if (match == null || match.streamLinks.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          openVideo(context, match.streamLinks.first.url, match.streamLinks);
        },
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              if (match.logoAUrl != null)
                Image.network(
                  match.logoAUrl!,
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.sports_soccer, size: 40),
                ),
              SizedBox(width: 8),
              if (match.logoBUrl != null)
                Image.network(
                  match.logoBUrl!,
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.sports_soccer, size: 40),
                ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.teamA} vs ${match.teamB}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${match.matchTime} - ${match.commentator}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${match.channel} - ${match.champion}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewsSection extends StatelessWidget {
  final Future<List> newsArticles;

  NewsSection({required this.newsArticles});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: newsArticles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('خطأ ف استرجاع لأخبار'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لا وجد أر لعرضها'));
        } else {
          final articles = snapshot.data!;
          return ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index]['attributes'];
              return NewsBox(article: article);
            },
          );
        }
      },
    );
  }
}

class NewsBox extends StatelessWidget {
  final dynamic article;

  NewsBox({required this.article});

  @override
  Widget build(BuildContext context) {
    if (article == null || article['title'] == null) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 280,
              color: Colors.grey, // Placeholder for missing image
              child: Center(child: Text('No Image Available')),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Unknown Title',
                style: TextStyle(
                  color: Color(0xFF673ab7),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      );
    }

    String title = article['title'] ?? 'Unknown Title';
    String imageUrl = article['image']?['data']?['attributes']?['url'] ?? '';

    return GestureDetector(
      onTap: () {
        if (article['link'] != null && article['link'].isNotEmpty) {
          _launchURL(article['link']);
        }
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 280,
                color: Colors.grey, // Placeholder for missing image
                child: Center(child: Text('No Image Available')),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Color(0xFF673ab7),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    article['content'] ?? 'No content available',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article['date'] != null
                            ? DateFormat('yyyy-MM-dd')
                                .format(DateTime.parse(article['date']))
                            : 'No date available',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (article['link'] != null &&
                              article['link'].isNotEmpty) {
                            _launchURL(article['link']);
                          }
                        },
                        child: Text(
                          'المزيد',
                          style: TextStyle(
                            color: Color(0xFF673ab7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchURL(String url) async {
    try {
      await launch(url, forceSafariVC: false, forceWebView: false);
    } catch (e) {
      print('Could not launch $url: $e');
    }
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String initialUrl;
  final List<Map<String, String>> streamLinks;

  VideoPlayerScreen({required this.initialUrl, required this.streamLinks});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLiveStream = false;
  double _progress = 0.0;
  late AnimationController _bufferingController;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _bufferingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat();
    _initializePlayer(widget.initialUrl);
  }

  Future<void> _initializePlayer(String url) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _videoPlayerController = VideoPlayerController.network(url);
      await _videoPlayerController.initialize();

      _isLiveStream = _videoPlayerController.value.duration == Duration.zero;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        aspectRatio: 16 / 9,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      _videoPlayerController.addListener(_updateProgress);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error initializing video player: $e");
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _updateProgress() {
    if (!mounted) return;

    if (_isLiveStream) {
      return;
    }

    final Duration position = _videoPlayerController.value.position;
    final Duration duration = _videoPlayerController.value.duration;

    if (duration.inMilliseconds > 0) {
      setState(() {
        _progress = position.inMilliseconds / duration.inMilliseconds;
      });
    }

    print(
        "Progress: $_progress, Position: ${position.inSeconds}s, Duration: ${duration.inSeconds}s, Is Live: $_isLiveStream");
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_updateProgress);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _bufferingController.dispose();
    super.dispose();
  }

  void _changeStream(String url) async {
    setState(() {
      _isLoading = true;
    });
    await _videoPlayerController.pause();
    await _videoPlayerController.dispose();
    await _initializePlayer(url);
  }

  Widget _buildProgressIndicator() {
    if (_isLiveStream) {
      return AnimatedBuilder(
        animation: _bufferingController,
        builder: (context, child) {
          return LinearProgressIndicator(
            value: null, 
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          );
        },
      );
    } else {
      return LinearProgressIndicator(
        value: _progress,
        backgroundColor: Colors.grey.withOpacity(0.3),
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      );
    }
  }

  Widget _buildControls(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط التقدم
          if (!_isLiveStream)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: _progress,
                onChanged: (value) {
                  setState(() {
                    _progress = value;
                  });
                  final duration = _controller?.value.duration;
                  if (duration != null) {
                    final position = duration * value;
                    _controller?.seekTo(position);
                  }
                },
                activeColor: Colors.red,
                inactiveColor: Colors.grey[300],
              ),
            ),
          
          // أزرار التحكم
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // زر الجودات
              if (widget.streamLinks.length > 1)
                IconButton(
                  icon: Icon(Icons.high_quality),
                  color: Colors.white,
                  onPressed: _showQualitySelector,
                ),
              
              SizedBox(width: 32),
              
              // زر التشغيل/الإيقاف
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                color: Colors.white,
                iconSize: 32.0,
                onPressed: _togglePlay,
              ),
              
              SizedBox(width: 32),
              
              // زر ملء الشاشة
              IconButton(
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                color: Colors.white,
                onPressed: _toggleFullScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => Container(
        child: ListView(
          shrinkWrap: true,
          children: widget.streamLinks.map((link) {
            final streamUrl = link['url'];
            return ListTile(
              title: Text(
                link['name'] ?? 'Unknown Quality',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                if (streamUrl != null && streamUrl.isNotEmpty) {
                  _initializeVideo(streamUrl);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _togglePlay() {
    if (_controller != null) {
      setState(() {
        _isPlaying = !_isPlaying;
        _isPlaying ? _controller!.play() : _controller!.pause();
      });
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
  }

  void _initializeVideo(String url) async {
    setState(() {
      _isLoading = true;
    });
    await _videoPlayerController.pause();
    await _videoPlayerController.dispose();
    await _initializePlayer(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _hasError
                ? Text('Error loading video',
                    style: TextStyle(color: Colors.white))
                : _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Chewie(controller: _chewieController!),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.streamLinks.map<Widget>((link) {
                    final streamName = link['name'] ?? 'Unknown Stream';
                    final streamUrl = link['url'];

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (streamUrl != null && streamUrl.isNotEmpty) {
                            _changeStream(streamUrl);
                          }
                        },
                        child: Text(streamName, 
                          style: TextStyle(color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLiveStream)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'LIVE',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                _buildProgressIndicator(),
                _buildControls(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
