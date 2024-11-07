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
import 'package:flutter/foundation.dart' show kIsWeb;
// import 'news_section.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    await FirebaseApi().initNotification();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7eSen TV',
      theme: ThemeData(
        primaryColor: const Color(0xFF512da8),
        scaffoldBackgroundColor: const Color(0xFF673ab7),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF512da8),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
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
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late Future<List> channelCategories;
  late Future<List> newsArticles;

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    channelCategories = fetchChannelCategories();
    newsArticles = fetchNews();
  }

  Future<void> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<List> fetchChannelCategories() async {
    try {
      final response = await http.get(Uri.parse(
          'https://st9.onrender.com/api/channel-categories?populate=channels'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Extract categories and include channels
        return List.from(data['data'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching channel categories: $e");
      return [];
    }
  }

  Future<List> fetchNews() async {
    try {
      final response = await http
          .get(Uri.parse('https://st9.onrender.com/api/news?populate=*'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List.from(data['data'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching news: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('7eSen TV'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ChannelsSection(
              channelCategories: channelCategories, openVideo: openVideo),
          NewsSection(newsArticles: newsArticles),
          // MatchesSection(matches: matches, openVideo: openVideo), // تم حذف هذا السطر
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
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

  void openVideo(
      BuildContext context, String firstStreamLink, List<dynamic> streamLinks) {
    // Extract the stream names and their URLs
    List<Map<String, String>> streams = [];

    for (var streamLink in streamLinks) {
      var children = streamLink['children'];
      if (children != null && children.isNotEmpty) {
        var linkElement = children
            .firstWhere((child) => child['type'] == 'link', orElse: () => null);
        if (linkElement != null &&
            linkElement['url'] != null &&
            linkElement['children'] != null) {
          var streamName =
              linkElement['children'][0]['text'] ?? 'Unknown Stream';
          var streamUrl = linkElement['url'];
          streams.add({'name': streamName, 'url': streamUrl});
        }
      }
    }

    // Automatically open the video player with the first stream
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => VideoPlayerScreen(
        initialUrl: firstStreamLink,
        streamLinks: streams, // Pass the list of streams
      ),
    ));
  }
}

class ChannelsSection extends StatelessWidget {
  final Future<List> channelCategories;
  final Function openVideo;

  const ChannelsSection(
      {super.key, required this.channelCategories, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: channelCategories,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('خطأ في استرجاع القنوات'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد قنوات لعرضها'));
        } else {
          final categories = snapshot.data!;
          categories.sort((a, b) => a['id'].compareTo(b['id']));
          return ListView.separated(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return ChannelBox(
                  category: categories[index], openVideo: openVideo);
            },
            separatorBuilder: (context, index) => const SizedBox(height: 16),
          );
        }
      },
    );
  }
}

class ChannelBox extends StatelessWidget {
  final dynamic category;
  final Function openVideo;

  const ChannelBox(
      {super.key, required this.category, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Center(
          child: Text(
            category['name'] ?? 'Unknown Category',
            style: const TextStyle(
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

  const CategoryChannelsScreen(
      {super.key, required this.channels, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القنوات'),
      ),
      body: ListView.separated(
        itemCount: channels.length,
        itemBuilder: (context, index) {
          return ChannelTile(channel: channels[index], openVideo: openVideo);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 16),
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  final dynamic channel;
  final Function openVideo;

  const ChannelTile(
      {super.key, required this.channel, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    // Print the channel data for debugging
    print("Channel Data: $channel");

    // Ensure that channel and its attributes are not null
    if (channel == null || channel['name'] == null) {
      return const Card(
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

    // Safely extract channel name
    String channelName = channel['name'] ?? 'Unknown Channel';

    // Extract StreamLink names safely
    List<dynamic> streamLinks = channel['StreamLink'] ?? [];

    // Automatically play the first available stream link when tapped
    String? firstStreamLink;

    if (streamLinks.isNotEmpty) {
      firstStreamLink = streamLinks[0]['children']
          .firstWhere((child) => child['url'] != null)['url'];
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Center(
          child: Text(
            channelName,
            style: const TextStyle(
              color: Color(0xFF673ab7),
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => openVideo(context, firstStreamLink!,
            streamLinks), // Automatically play first stream link
      ),
    );
  }
}

class MatchesSection extends StatelessWidget {
  final Future<List> matches;
  final Function openVideo;

  const MatchesSection(
      {super.key, required this.matches, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: matches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('خطأ في استرجاع المباريات'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد مباريات لعرضها'));
        } else {
          final matches = snapshot.data!;

          List liveMatches = [];
          List upcomingMatches = [];
          List finishedMatches = [];

          for (var match in matches) {
            // تحقق من أن match ليس null وأنه يحتوي على attributes
            if (match == null || match['attributes'] == null) continue;

            final matchDateTime =
                DateFormat('HH:mm').parse(match['attributes']['matchTime']);
            final now = DateTime.now();
            final matchDateTimeWithToday = DateTime(now.year, now.month,
                now.day, matchDateTime.hour, matchDateTime.minute);

            if (matchDateTimeWithToday.isBefore(now) &&
                now.isBefore(
                    matchDateTimeWithToday.add(const Duration(minutes: 110)))) {
              liveMatches.add(match);
            } else if (matchDateTimeWithToday.isAfter(now)) {
              upcomingMatches.add(match);
            } else {
              finishedMatches.add(match);
            }
          }

          // ترتيب المباريات القادمة من الأقرب للأبعد
          upcomingMatches.sort((a, b) {
            final matchTimeA =
                DateFormat('HH:mm').parse(a['attributes']['matchTime']);
            final matchTimeB =
                DateFormat('HH:mm').parse(b['attributes']['matchTime']);
            return matchTimeA.compareTo(matchTimeB);
          });

          return ListView(
            children: [
              ...liveMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo)),
              ...upcomingMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo)),
              ...finishedMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo)),
            ],
          );
        }
      },
    );
  }
}

class MatchBox extends StatelessWidget {
  final Match match;
  final Function openVideo;

  const MatchBox({super.key, required this.match, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${match.teamA} vs ${match.teamB}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Match Time: ${match.matchTime}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(match.commentator,
                    style: const TextStyle(color: Colors.grey)),
                Text(match.channel, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
        onTap: () => openVideo(context, match.streamLink),
      ),
    );
  }
}

class Match {
  final String teamA;
  final String teamB;
  final String matchTime;
  final String commentator;
  final String channel;
  final String? streamLink;

  Match({
    required this.teamA,
    required this.teamB,
    required this.matchTime,
    required this.commentator,
    required this.channel,
    this.streamLink,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      teamA: json['attributes']['teamA'],
      teamB: json['attributes']['teamB'],
      matchTime: json['attributes']['matchTime'],
      commentator: json['attributes']['commentator'] ?? 'Unknown Commentator',
      channel: json['attributes']['channel'] ?? 'Unknown Channel',
      streamLink: json['attributes']['streamLink'],
    );
  }
}

class NewsSection extends StatelessWidget {
  final Future<List> newsArticles;

  const NewsSection({super.key, required this.newsArticles});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: newsArticles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('خطأ في استرجاع الأخبار'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد أخبار لعرضها'));
        } else {
          final articles = snapshot.data!;
          return ListView.separated(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index]['attributes'];
              return NewsBox(article: article);
            },
            separatorBuilder: (context, index) => const SizedBox(height: 8),
          );
        }
      },
    );
  }
}

class NewsBox extends StatelessWidget {
  final dynamic article;

  const NewsBox({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (article['link'] != null && article['link'].isNotEmpty) {
          _launchURL(article['link']);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              article['image']['data']['attributes']['url'],
              width: double.infinity,
              height: 280,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article['title'] ?? 'Unknown Title',
                    style: const TextStyle(
                      color: Color(0xFF673ab7),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article['content'] ?? 'No content available',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article['date'] != null
                            ? DateFormat('yyyy-MM-dd')
                                .format(DateTime.parse(article['date']))
                            : 'No date available',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (article['link'] != null &&
                              article['link'].isNotEmpty) {
                            _launchURL(article['link']);
                          }
                        },
                        child: const Text(
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
      // يمكنك هنا إضافة كود لفتح المتصفح بشكل يدوي إذا لزم الأمر
      // مثل استخدام launch('https://www.google.com') كبديل
    }
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String initialUrl;
  final List<Map<String, String>> streamLinks;

  const VideoPlayerScreen(
      {super.key, required this.initialUrl, required this.streamLinks});

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

  @override
  void initState() {
    super.initState();
    _bufferingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
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
              style: const TextStyle(color: Colors.white),
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
      // For live streams, we don't update the progress
      return;
    }

    final Duration position = _videoPlayerController.value.position;
    final Duration duration = _videoPlayerController.value.duration;

    if (duration.inMilliseconds > 0) {
      setState(() {
        _progress = position.inMilliseconds / duration.inMilliseconds;
      });
    }

    // Debug log
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
            value: null, // Indeterminate progress
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          );
        },
      );
    } else {
      return LinearProgressIndicator(
        value: _progress,
        backgroundColor: Colors.grey.withOpacity(0.3),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _hasError
                ? const Text('Error loading video',
                    style: TextStyle(color: Colors.white))
                : _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Chewie(controller: _chewieController!),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.streamLinks.map<Widget>((link) {
                var streamName = link['name'] ?? 'Unknown Stream';
                var streamUrl = link['url'] ?? '';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextButton(
                    onPressed: () =>
                        streamUrl.isNotEmpty ? _changeStream(streamUrl) : null,
                    child: Text(streamName,
                        style: const TextStyle(color: Colors.black)),
                  ),
                );
              }).toList(),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                SizedBox(
                  height: 4,
                  child: _buildProgressIndicator(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
