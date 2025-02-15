import 'package:flutter/material.dart';
import 'package:hesen/models/match_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChannelsSection extends StatelessWidget {
  final List channelCategories;
  final Function openVideo;

  ChannelsSection({required this.channelCategories, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return channelCategories.isEmpty
        ? Center(
            child: Text('لا توجد قنوات لعرضها',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color)))
        : ListView.separated(
            itemCount: channelCategories.length,
            itemBuilder: (context, index) {
              return ChannelBox(
                  category: channelCategories[index], openVideo: openVideo);
            },
            separatorBuilder: (context, index) => SizedBox(height: 16),
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

class CategoryChannelsScreen extends StatefulWidget {
  final List channels;
  final Function openVideo;

  CategoryChannelsScreen({required this.channels, required this.openVideo});

  @override
  State<CategoryChannelsScreen> createState() => _CategoryChannelsScreenState();
}

class _CategoryChannelsScreenState extends State<CategoryChannelsScreen> {
  String? _selectedChannel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('القنوات'),
      ),
      body: ListView.separated(
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          return ChannelTile(
            key: ValueKey(widget.channels[index]['id']),
            channel: widget.channels[index],
            openVideo: widget.openVideo,
            isSelected: _selectedChannel == widget.channels[index]['id'],
            onChannelTap: (channelId) {
              setState(() {
                if (_selectedChannel == channelId) {
                  _selectedChannel = null;
                } else {
                  _selectedChannel = channelId;
                }
              });
            },
          );
        },
        separatorBuilder: (context, index) => SizedBox(height: 16),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (channel == null || channel['name'] == null) {
      return SizedBox.shrink();
    }

    String channelName = channel['name'] ?? 'Unknown Channel';
    String channelId = channel['id'].toString();
    List<dynamic> streamLinks = channel['StreamLink'] ?? [];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          ListTile(
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
            onTap: () {
              onChannelTap(channelId);

              List<Map<String, String>> streams = [];
              for (var streamLink in streamLinks) {
                var children = streamLink['children'];
                if (children != null && children.isNotEmpty) {
                  var linkElement = children.firstWhere(
                      (child) => child['type'] == 'link',
                      orElse: () => {});
                  if (linkElement != null &&
                      linkElement['url'] != null &&
                      linkElement['children'] != null) {
                    var streamName =
                        linkElement['children'][0]['text']?.toString() ??
                            'Unknown Stream';
                    var streamUrl = linkElement['url']?.toString() ?? '';

                    if (streamUrl.isNotEmpty) {
                      streams.add({'name': streamName, 'url': streamUrl});
                    }
                  }
                }
              }

              if (streams.isNotEmpty) {
                if (streams[0]['url'] is String) {
                  openVideo(
                      context,
                      streams[0]['url']!,
                      streams
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid Stream Format')));
                }
              }
            },
          ),
          if (isSelected)
            ...streamLinks.map((streamLink) {
              var linkElement = streamLink['children'].firstWhere(
                  (child) => child['type'] == 'link',
                  orElse: () => {});
              if (linkElement != null &&
                  linkElement['url'] != null &&
                  linkElement['children'] != null) {
                var streamName =
                    linkElement['children'][0]['text'] ?? 'Unknown Stream';
                var streamUrl = linkElement['url'];

                return ListTile(
                  title: Text(
                    streamName,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                  onTap: () {
                    openVideo(
                        context,
                        streamUrl,
                        streamLinks
                            .map((link) => {
                                  'name': link['children'].firstWhere(
                                      (child) => child['type'] == 'link',
                                      orElse: () => null)?['url'],
                                })
                            .toList());
                  },
                );
              } else {
                return SizedBox.shrink();
              }
            }).toList(),
        ],
      ),
    );
  }
}

class MatchesSection extends StatelessWidget {
  final Future<List<Match>> matches;
  final Function openVideo;

  MatchesSection({required this.matches, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Match>>(
      future: matches,
      builder: (context, snapshot) {
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
    if (match == null) {
      return SizedBox.shrink();
    }

    final teamA = match.teamA;
    final teamB = match.teamB;
    final logoA = match.logoAUrl ?? '';
    final logoB = match.logoBUrl ?? '';
    final matchTime = match.matchTime;
    final commentator = match.commentator;
    final channel = match.channel;
    final champion = match.champion;
    final streamLink = match.streamLinks;

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
        if (streams.isNotEmpty) {
          openVideo(context, firstStreamUrl,
              streams.map((e) => Map<String, dynamic>.from(e)).toList());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mic, size: 20, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(commentator, style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  SizedBox(width: 10),
                  Row(
                    children: [
                      Icon(Icons.stars, size: 20, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(champion,
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  SizedBox(width: 10),
                  Row(
                    children: [
                      Icon(Icons.tv, size: 20, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(channel, style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
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
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) => Image.asset(
                'assets/ball.png', // Use the correct path
                width: 40,
                height: 40,
                color: Colors.grey, // Optional: if you want to tint the image
              ),
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
          final articles = snapshot.data!;
          return ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
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
      return SizedBox.shrink();
    }

    final title = article['title'];
    final content = article['content'] ?? '';
    final date = article['date'] != null
        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(article['date']))
        : '';
    final link = article['link'];

    String? imageUrl;
    if (article['image'] != null && article['image'].isNotEmpty) {
      final imageData = article['image'][0];
      if (imageData != null &&
          imageData['formats'] != null &&
          imageData['formats']['small'] != null) {
        imageUrl = imageData['formats']['small']['url'];
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) =>
                      Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      Icon(Icons.image, size: 50, color: Colors.grey),
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
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
                    link != null
                        ? InkWell(
                            onTap: () async {
                              if (await canLaunchUrl(Uri.parse(link))) {
                                await launchUrl(Uri.parse(link));
                              } else {
                                throw 'Could not launch $link';
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'المزيد',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          )
                        : SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
