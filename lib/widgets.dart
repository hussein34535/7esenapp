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
                    physics: const AlwaysScrollableScrollPhysics(),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(25.0),
        onTap: () {
          // Print the channels list just before navigation
          List channelsToPass = category['channels'] ?? [];
          // print("--- ChannelBox onTap - Channels being passed: ---");
          // print(channelsToPass);
          // print("--------------------------------------------------");

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CategoryChannelsScreen(
                channels: channelsToPass, // Pass the list
                openVideo: openVideo,
              ),
            ),
          );
        },
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
    // Add print statement here
    // print("--- CategoryChannelsScreen RECEIVED CHANNELS ---");
    // print(widget.channels);
    // print("---------------------------------------------");
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
              physics: const AlwaysScrollableScrollPhysics(),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(25.0),
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
                ...liveMatches
                    .map(
                        (match) => MatchBox(match: match, openVideo: openVideo))
                    .toList(),
              if (upcomingMatches.isNotEmpty)
                ...upcomingMatches
                    .map(
                        (match) => MatchBox(match: match, openVideo: openVideo))
                    .toList(),
              if (finishedMatches.isNotEmpty)
                ...finishedMatches
                    .map(
                        (match) => MatchBox(match: match, openVideo: openVideo))
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

    // Use local time for comparison
    DateTime now = DateTime.now();
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        margin: EdgeInsets.all(9), // Medium margin
        child: Padding(
          padding: const EdgeInsets.all(9.0), // Medium padding
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(logoA, size: 52), // Medium logo size
                        SizedBox(height: 4), // Kept smaller space
                        Text(teamA,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15) // Medium font size
                            ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7), // Medium padding
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(9), // Medium radius
                    ),
                    child: Text(
                      timeStatus,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13, // Medium font size
                          color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(logoB, size: 52), // Medium logo size
                        SizedBox(height: 4), // Kept smaller space
                        Text(teamB,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15) // Medium font size
                            ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 9), // Medium space
              // Details Row (Commentator, Channel)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Commentator
                  Row(
                    children: [
                      Icon(Icons.mic,
                          size: 18, color: Colors.grey), // Medium icon size
                      SizedBox(width: 4), // Kept smaller space
                      Text(commentator,
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12)), // Medium font size
                    ],
                  ),
                  // Channel
                  Row(
                    children: [
                      Icon(Icons.tv,
                          size: 18, color: Colors.grey), // Medium icon size
                      SizedBox(width: 4), // Kept smaller space
                      Text(channel,
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12)), // Medium font size
                    ],
                  ),
                ],
              ),
              // Champion (moved below)
              Padding(
                padding: const EdgeInsets.only(top: 7.0), // Medium padding
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center the champion
                  children: [
                    Icon(Icons.emoji_events,
                        size: 18,
                        color: Colors.grey), // Changed from Icons.stars
                    SizedBox(width: 4), // Kept smaller space
                    Text(champion,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey)), // Medium font size
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String logoUrl, {double size = 60}) {
    return Container(
      width: size,
      height: size,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) => Image.asset(
                'assets/no-image.png',
                width: size * 0.8,
                height: size * 0.8,
                color: Colors.grey,
              ),
              placeholder: (context, url) =>
                  Center(child: CircularProgressIndicator()),
            )
          : Image.asset(
              'assets/no-image.png',
              width: size * 0.8,
              height: size * 0.8,
              color: Colors.grey,
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
    final screenWidth = MediaQuery.of(context).size.width; // Get screen width
    final titleFontSize =
        (screenWidth * 0.05).clamp(16.0, 24.0); // Calculate dynamic size

    return FutureBuilder<List<dynamic>>(
      future: newsArticles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // Use CustomScrollView + SliverFillRemaining for centering + scrollability
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('خطأ في استرجاع الأخبار',
                              textAlign: TextAlign.center, // Center text
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color))))),
            ],
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Use CustomScrollView + SliverFillRemaining for centering + scrollability
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('لا توجد أخبار لعرضها',
                              textAlign: TextAlign.center, // Center text
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color))))),
            ],
          );
        } else {
          final articles =
              snapshot.data!.reversed.toList(); // Reverse the list here
          return Column(
            // Wrap ListView in a Column
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Make ListView take remaining space
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: articles.length,
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return NewsBox(article: article, openVideo: openVideo);
                  },
                ),
              ),
            ],
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always attempt CachedNetworkImage, rely on errorWidget for null/bad URLs
            CachedNetworkImage(
              imageUrl: imageUrl ?? '', // Pass url or empty string
              placeholder: (context, url) => Center(
                  child:
                      CircularProgressIndicator()), // Keep placeholder for loading
              errorWidget: (context, url, error) =>
                  _buildPlaceholder(), // Use placeholder on error/null url
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
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

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[300],
      child: Center(
        child: Icon(Icons.image, size: 50, color: Colors.grey[600]),
      ),
    );
  }
}

class GoalsSection extends StatelessWidget {
  final Future<List<dynamic>> goalsArticles;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String)
      openVideo;

  const GoalsSection({
    super.key,
    required this.goalsArticles,
    required this.openVideo,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // Get screen width
    final titleFontSize =
        (screenWidth * 0.05).clamp(16.0, 24.0); // Calculate dynamic size

    return FutureBuilder<List<dynamic>>(
      future: goalsArticles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // Use CustomScrollView + SliverFillRemaining for centering + scrollability
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading goals',
                    textAlign: TextAlign.center, // Center text
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                )),
              ),
            ],
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Use CustomScrollView + SliverFillRemaining for centering + scrollability
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No goals available',
                    textAlign: TextAlign.center, // Center text
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                )),
              ),
            ],
          );
        }

        final goals = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                    top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final title = goal['title'] ?? '';
                  final time = goal['time'] ?? '';
                  final url = goal['url'] ?? [];
                  final image = goal['image']?[0] ?? {};

                  // Simplified image URL extraction: Use direct URL first
                  String? imageUrl = image['url'];

                  // Add base URL if the image URL is relative
                  if (imageUrl != null && !imageUrl.startsWith('http')) {
                    imageUrl = 'https://st9.onrender.com' + imageUrl;
                  }

                  List<Map<String, dynamic>> streamLinks = [];
                  if (url is List) {
                    for (var item in url) {
                      if (item['type'] == 'paragraph' &&
                          item['children'] is List) {
                        for (var child in item['children']) {
                          if (child['type'] == 'link' && child['url'] != null) {
                            streamLinks.add({
                              'name': child['children']?[0]['text'] ?? 'Link',
                              'url': child['url'],
                            });
                          }
                        }
                      }
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      if (streamLinks.isNotEmpty) {
                        openVideo(context, streamLinks[0]['url'], streamLinks,
                            'goals');
                      }
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.0)),
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null)
                            CachedNetworkImage(
                              imageUrl:
                                  imageUrl ?? '', // Pass url or empty string
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _buildScoreOrTime(
    BuildContext context, String? score, String? time, String status,
    {double iconSize = 16.0}) {
  if (status == 'FT' ||
      status == 'HT' ||
      score != null && score.contains('-')) {
    // Final Score - Use larger font, different color if needed
    return Text(
      score ?? '-', // Show score if available, else fallback
      style: TextStyle(
        fontSize: 18.0, // Larger font for final score
        fontWeight: FontWeight.bold,
        color:
            Theme.of(context).colorScheme.secondary, // Distinct color for score
      ),
    );
  } else if (status == 'NS' || time == null || time.isEmpty) {
    // Not Started or No Time - Use a placeholder icon
    // Replace Image.asset with Icon
    return Icon(
      Icons.sports_soccer, // Placeholder icon
      size: iconSize + 4, // Slightly larger icon
      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
    );
    /* Original Image.asset
    return Image.asset(
      'assets/ball.png', // Use the correct path
      width: iconSize + 4, // Slightly larger icon
      height: iconSize + 4,
      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
    );
    */
  } else {
    // In-progress or Scheduled Time - Regular time display
    return Text(
      time,
      style: TextStyle(
        fontSize: 14.0,
        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.9),
      ),
    );
  }
}

Widget _buildLiveIndicator(BuildContext context, String status) {
  if (status == 'LIVE' ||
      status == 'HT' ||
      (status.contains('') && status != 'FT' && status != 'NS')) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  } else if (status == 'NS') {
    // Replace Image.asset with Icon for Not Started status
    return Image.asset(
      'assets/no-image.png', // Use the specified asset
      width: 16, // Consistent size
      height: 16,
      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
    );
    /* Original Icon
    return Icon(
      Icons.sports_soccer, // Placeholder icon
      size: 16, // Consistent size
      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
    );
    */
    /* Original Image.asset
    return Image.asset(
      'assets/ball.png', // Use the correct path
      width: 16,
      height: 16,
      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
    );
    */
  } else {
    return const SizedBox.shrink(); // Return empty space if not LIVE or NS
  }
}
