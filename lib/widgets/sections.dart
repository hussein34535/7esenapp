import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ChannelsSection extends StatelessWidget {
  final Future<List> channelCategories;
  final Function(String) openVideo;

  ChannelsSection({required this.channelCategories, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: channelCategories,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No channels available'));
        }
        return GridView.builder(
          padding: EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final category = snapshot.data![index];
            return ChannelBox(
              category: category,
              openVideo: openVideo,
            );
          },
        );
      },
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
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No news available'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final article = snapshot.data![index];
            return NewsBox(article: article);
          },
        );
      },
    );
  }
}

class MatchesSection extends StatelessWidget {
  final Future<List> matches;
  final Function(String) openVideo;

  MatchesSection({required this.matches, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: matches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No matches available'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final match = snapshot.data![index];
            return MatchBox(
              match: match,
              openVideo: openVideo,
            );
          },
        );
      },
    );
  }
}

class MatchBox extends StatelessWidget {
  final dynamic match;
  final Function openVideo;

  MatchBox({required this.match, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    final teamA = match['teamA'] ?? 'Team A';
    final teamB = match['teamB'] ?? 'Team B';
    final matchTime = match['matchTime'] ?? '00:00';
    final streamLink = match['streamLink'] ?? [];
    final channel = match['channel'] ?? '';

    List<String> validStreamUrls = [];
    for (var link in streamLink) {
      if (link['children'] != null) {
        for (var child in link['children']) {
          if (child['url'] != null) {
            validStreamUrls.add(child['url']);
          }
        }
      }
    }

    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        onTap: () {
          if (validStreamUrls.isNotEmpty) {
            openVideo(validStreamUrls[0], validStreamUrls);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('لا توجد روابط للبث')),
            );
          }
        },
        title: Row(
          children: [
            Expanded(child: Text(teamA, textAlign: TextAlign.start)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                matchTime,
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(child: Text(teamB, textAlign: TextAlign.end)),
          ],
        ),
        subtitle: channel.isNotEmpty ? Text(channel) : null,
      ),
    );
  }
}
