import 'package:flutter/material.dart';
import 'package:hesen/models/match_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChannelsSection extends StatefulWidget {
  final List channelCategories;
  final Function openVideo;

  ChannelsSection({required this.channelCategories, required this.openVideo});

  @override
  _ChannelsSectionState createState() => _ChannelsSectionState();
}

class _ChannelsSectionState extends State<ChannelsSection> {
  Key _gridKey = UniqueKey(); // Key for the GridView
  double? _itemHeight;

  @override
  Widget build(BuildContext context) {
    return widget.channelCategories.isEmpty
        ? Center(
            child: Text('لا توجد قنوات لعرضها',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color)))
        : OrientationBuilder(
            builder: (context, orientation) {
              _gridKey = UniqueKey(); // New key on rotation
              return LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate item height *only* once
                  if (_itemHeight == null) {
                    _itemHeight = 72; // Keep this consistent
                  }

                  return GridView.builder(
                    key: _gridKey,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          orientation == Orientation.portrait ? 1 : 2,
                      childAspectRatio: _calculateAspectRatio(
                          orientation, constraints), //Dynamic
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: widget.channelCategories.length,
                    padding: EdgeInsets.all(10),
                    itemBuilder: (context, index) {
                      return ChannelBox(
                          category: widget.channelCategories[index],
                          openVideo: widget.openVideo);
                    },
                  );
                },
              );
            },
          );
  }

  double _calculateAspectRatio(
      Orientation orientation, BoxConstraints constraints) {
    if (orientation == Orientation.portrait) {
      return constraints.maxWidth / _itemHeight!;
    } else {
      return (constraints.maxWidth / 2) / _itemHeight!;
    }
  }
}

class ChannelBox extends StatelessWidget {
  final dynamic category;
  final Function openVideo;

  ChannelBox({required this.category, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
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
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              category['name'] ?? 'Unknown Category',
              style: TextStyle(
                color: Color(0xFF673ab7),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryChannelsScreen extends StatefulWidget {
  final List channels;
  final Function openVideo;

  CategoryChannelsScreen({required this.channels, required this.openVideo});

  @override
  State<CategoryChannelsScreen> createState() => _CategoryChannelsScreenState();
}

class _CategoryChannelsScreenState extends State<CategoryChannelsScreen> {
  String? _selectedChannel;
  Key _gridKey = UniqueKey(); // Use GridView
  double? _itemHeight; // Store the height

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('القنوات'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          _gridKey = UniqueKey(); // Regenerate the key
          return LayoutBuilder(builder: (context, constraints) {
            //  Calculate the item height *only* once.  VERY IMPORTANT.
            if (_itemHeight == null) {
              _itemHeight = 72; // Or get it from your original ChannelBox
            }

            return GridView.builder(
              key: _gridKey,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: orientation == Orientation.portrait ? 1 : 2,
                childAspectRatio: _calculateAspectRatio(
                    orientation, constraints), // Calculate dynamically
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: widget.channels.length,
              padding: EdgeInsets.all(8),
              itemBuilder: (context, index) {
                return SizedBox(
                  // Enforce the height
                  height: _itemHeight,
                  child: ChannelTile(
                    key: ValueKey(widget.channels[index]['id']),
                    channel: widget.channels[index],
                    openVideo: widget.openVideo,
                    isSelected:
                        _selectedChannel == widget.channels[index]['id'],
                    onChannelTap: (channelId) {
                      setState(() {
                        _selectedChannel =
                            (_selectedChannel == channelId) ? null : channelId;
                      });
                    },
                  ),
                );
              },
            );
          });
        },
      ),
    );
  }

  double _calculateAspectRatio(
      Orientation orientation, BoxConstraints constraints) {
    // Calculate aspect ratio based on orientation and available width
    if (orientation == Orientation.portrait) {
      // In portrait mode, use the full width and the desired height
      return constraints.maxWidth / _itemHeight!;
    } else {
      // In landscape mode, use half the width and the desired height
      return (constraints.maxWidth / 2) / _itemHeight!;
    }
  }
}

class ChannelTile extends StatelessWidget {
  final dynamic channel;
  final Function openVideo;
  final bool isSelected;
  final Function(String) onChannelTap;

  ChannelTile({
    required Key key,
    required this.channel,
    required this.openVideo,
    required this.isSelected,
    required this.onChannelTap,
  }) : super(key: key);

  List<Map<String, String>> _extractStreamLinks(List<dynamic>? streamLinks) {
    List<Map<String, String>> streams = [];
    if (streamLinks == null) return streams;

    for (var streamLink in streamLinks) {
      // Use a more robust way to get URL and name
      if (streamLink is Map && streamLink.containsKey('children')) {
        for (var child in streamLink['children']) {
          if (child is Map &&
              child.containsKey('type') &&
              child['type'] == 'link' &&
              child.containsKey('url') &&
              child.containsKey('children')) {
            for (var textChild in child['children']) {
              if (textChild is Map && textChild.containsKey('text')) {
                String? streamUrl = child['url']?.toString();
                String? streamName =
                    textChild['text']?.toString() ?? 'Unknown Stream';
                if (streamUrl != null && streamUrl.isNotEmpty) {
                  if (!streamUrl.startsWith('http')) {
                    streamUrl = 'https://st9.onrender.com' + streamUrl;
                  }
                  streams.add({'name': streamName, 'url': streamUrl});
                }
              }
            }
          }
        }
      }
    }
    return streams;
  }

  @override
  Widget build(BuildContext context) {
    if (channel == null || channel['name'] == null) {
      return SizedBox.shrink();
    }

    String channelName = channel['name'] ?? 'Unknown Channel';
    String channelId = channel['id'].toString();
    List<dynamic> streamLinks = channel['StreamLink'] ?? [];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: () {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          onChannelTap(channelId);

          List<Map<String, String>> streams = _extractStreamLinks(streamLinks);

          if (streams.isNotEmpty) {
            if (streams[0]['url'] is String) {
              openVideo(
                  context,
                  streams[0]['url']!,
                  streams.map((e) => Map<String, dynamic>.from(e)).toList(),
                  'channels' // Added sourceSection
                  );
            } else {
              scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Invalid Stream Format')));
            }
          } else {
            scaffoldMessenger
                .showSnackBar(SnackBar(content: Text("No stream available.")));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              channelName,
              style: TextStyle(
                color: Color(0xFF673ab7),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

//other classes no changes
class MatchesSection extends StatelessWidget {
  final Future<List<Match>> matches;
  final Function openVideo;

  MatchesSection({required this.matches, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Match>>(
      // Start FutureBuilder
      future: matches,
      builder: (context, snapshot) {
        // Start builder method
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('خطأ في استرجاع المباريات',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text('لا توجد مباريات لعرضها',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color)));
        } else {
          final matches = snapshot.data!;

          List<Match> liveMatches = [];
          List<Match> finishedMatches = [];
          List<Match> upcomingMatches = [];

          for (var match in matches) {
            final matchDateTime = DateFormat('HH:mm').parse(match.matchTime);
            final now = DateTime.now();
            final matchDateTimeWithToday = DateTime(now.year, now.month,
                now.day, matchDateTime.hour, matchDateTime.minute);

            if (matchDateTimeWithToday.isBefore(now) &&
                now.isBefore(
                    matchDateTimeWithToday.add(Duration(minutes: 110)))) {
              liveMatches.add(match);
            } else if (matchDateTimeWithToday.isAfter(now)) {
              upcomingMatches.add(match);
            } else {
              finishedMatches.add(match);
            }
          }

          upcomingMatches.sort((a, b) {
            final matchTimeA = DateFormat('HH:mm').parse(a.matchTime);
            final matchTimeB = DateFormat('HH:mm').parse(b.matchTime);
            return matchTimeA.compareTo(matchTimeB);
          });

          return ListView(
            children: [
              if (liveMatches.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    'مباريات مباشرة',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                    textAlign: TextAlign.right,
                  ),
                ),
              ...liveMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo))
                  .toList(),
              if (upcomingMatches.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    'مباريات قادمة',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                    textAlign: TextAlign.right,
                  ),
                ),
              ...upcomingMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo))
                  .toList(),
              if (finishedMatches.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    'مباريات انتهت',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                    textAlign: TextAlign.right,
                  ),
                ),
              ...finishedMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo))
                  .toList(),
            ],
          );
        }
      }, // End builder method
    ); // End FutureBuilder
  }
}

class MatchBox extends StatelessWidget {
  final Match match;
  final Function openVideo;

  MatchBox({required this.match, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    if (match == null) {
      return SizedBox.shrink();
    }

    final teamA = match.teamA;
    final teamB = match.teamB;
    String logoA = match.logoAUrl ?? ''; //  قد تكون فارغة
    String logoB = match.logoBUrl ?? ''; //  قد تكون فارغة
    final matchTime = match.matchTime;
    final commentator = match.commentator;
    final channel = match.channel;
    final champion = match.champion;
    final streamLink = match.streamLinks;

    // إضافة البادئة إذا لزم الأمر
    if (logoA.isNotEmpty && !logoA.startsWith('http')) {
      logoA = 'https://st9.onrender.com' + logoA;
    }
    if (logoB.isNotEmpty && !logoB.startsWith('http')) {
      logoB = 'https://st9.onrender.com' + logoB;
    }

    DateTime now = DateTime.now().toUtc().add(Duration(hours: 0));
    final matchDateTime = DateFormat('HH:mm').parse(matchTime);
    final matchDateTimeWithToday = DateTime(
        now.year, now.month, now.day, matchDateTime.hour, matchDateTime.minute);

    String timeStatus;
    Color borderColor;

    if (matchDateTimeWithToday.isBefore(now) &&
        now.isBefore(matchDateTimeWithToday.add(Duration(minutes: 110)))) {
      timeStatus = 'مباشر';
      borderColor = Colors.red;
    } else if (now
        .isAfter(matchDateTimeWithToday.add(Duration(minutes: 110)))) {
      timeStatus = 'انتهت المباراة';
      borderColor = Colors.black;
    } else {
      timeStatus = DateFormat('hh:mm a').format(matchDateTimeWithToday);
      borderColor = Colors.blueAccent;
    }
    List<Map<String, String>> streams = [];
    for (var streamLinkItem in streamLink) {
      if (streamLinkItem.url.isNotEmpty) {
        streams.add({'name': streamLinkItem.name, 'url': streamLinkItem.url});
      }
    }
    String firstStreamUrl = '';
    if (streams.isNotEmpty) {
      firstStreamUrl = streams[0]['url'] ?? '';
    }
    return GestureDetector(
      onTap: () {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (streams.isNotEmpty) {
          openVideo(
              context,
              firstStreamUrl,
              streams.map((e) => Map<String, dynamic>.from(e)).toList(),
              'matches' // Added sourceSection
              );
        } else {
          scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('لا يوجد رابط للبث المباشر')));
        }
      },
      child: Card(
        margin: EdgeInsets.all(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(logoA),
                        SizedBox(height: 5),
                        Text(teamA,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      timeStatus,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(logoB),
                        SizedBox(height: 5),
                        Text(teamB,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Details Row (Commentator, Channel)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Commentator
                  Row(
                    children: [
                      Icon(Icons.mic, size: 20, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(commentator, style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  // Channel
                  Row(
                    children: [
                      Icon(Icons.tv, size: 20, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(channel, style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              // Champion (moved below)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center the champion
                  children: [
                    Icon(Icons.stars, size: 20, color: Colors.grey),
                    SizedBox(width: 5),
                    Text(champion,
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String logoUrl) {
    return Container(
      width: 60,
      height: 60,
      child: logoUrl.isNotEmpty // تأكد من أن الرابط ليس فارغًا
          ? CachedNetworkImage(
              imageUrl: logoUrl, // استخدم الرابط المعدل هنا
              fit: BoxFit.contain,
              errorWidget: (context, url, error) => Image.asset(
                'assets/ball.png', // Use the correct path
                width: 40,
                height: 40,
                color: Colors.grey, // Optional: if you want to tint the image
              ),
              placeholder: (context, url) =>
                  Center(child: CircularProgressIndicator()),
            )
          : Image.asset(
              'assets/ball.png', // Use the correct path
              width: 40,
              height: 40,
              color: Colors.grey, // Optional: if you want to tint the image
            ),
    );
  }
}

class NewsSection extends StatelessWidget {
  final Future<List<dynamic>> newsArticles;
  final Function openVideo;

  NewsSection({required this.newsArticles, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: newsArticles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('خطأ في استرجاع الأخبار',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text('لا توجد أخبار لعرضها',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color)));
        } else {
          final articles =
              snapshot.data!.reversed.toList(); // Reverse the list here
          return ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return NewsBox(article: article, openVideo: openVideo);
            },
          );
        }
      },
    );
  }
}

class NewsBox extends StatelessWidget {
  final dynamic article;
  final Function openVideo;

  NewsBox({required this.article, required this.openVideo});

  List<Map<String, String>> _extractStreamLinks(List<dynamic>? links) {
    List<Map<String, String>> extractedLinks = [];
    if (links == null) return extractedLinks;

    for (var link in links) {
      if (link is Map && link.containsKey('children')) {
        for (var child in link['children']) {
          if (child is Map &&
              child.containsKey('type') &&
              child['type'] == 'link' &&
              child.containsKey('url') &&
              child.containsKey('children')) {
            for (var textChild in child['children']) {
              if (textChild is Map && textChild.containsKey('text')) {
                String? streamUrl = child['url']?.toString();
                String? streamName =
                    textChild['text']?.toString() ?? 'Unknown Stream';
                if (streamUrl != null && streamUrl.isNotEmpty) {
                  extractedLinks.add({'name': streamName, 'url': streamUrl});
                }
              }
            }
          }
        }
      }
    }
    return extractedLinks;
  }

  @override
  Widget build(BuildContext context) {
    final title = article['title'];
    final date = article['date'] != null
        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(article['date']))
        : '';
    final links = article['link'] as List? ?? [];

    String? imageUrl;
    if (article['image'] != null &&
        article['image'] is List &&
        article['image'].isNotEmpty) {
      final imageData = article['image'][0];
      imageUrl = imageData['url'];
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        imageUrl = 'https://st9.onrender.com' + imageUrl;
      }
    }

    return GestureDetector(
      onTap: () {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        List<Map<String, String>> streams = _extractStreamLinks(links);
        if (streams.isNotEmpty) {
          String firstStreamUrl =
              streams[0]['url'] ?? ''; // Access the first link
          openVideo(
              context,
              firstStreamUrl, // Pass the URL
              streams
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(), // Pass all links (in the correct format)
              'news' // Added sourceSection
              );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
                content: Text('No video link found for this news article.')),
          );
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conditional rendering for image or icon container
            imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder: (context, url) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        _buildPlaceholder(), // Use the placeholder widget
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : _buildPlaceholder(), // Use the placeholder widget
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        date,
                        style: TextStyle(
                          color: Colors.grey,
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

//  إنشاء عنصر نائب للصورة
  Widget _buildPlaceholder() {
    return Container(
      height: 200, // Same height as CachedNetworkImage
      width: double.infinity,
      color: Colors.grey[300], // Light grey color
      child: Center(
        child: Icon(Icons.image,
            size: 50, color: Colors.grey[600]), // Darker grey icon
      ),
    );
  }
}
