import 'package:flutter/material.dart';
import 'package:hesen/models/match_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class ChannelsSection extends StatefulWidget {
  final List channelCategories;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading; // -->> استقبل الحالة هنا

  const ChannelsSection(
      {super.key,
      required this.channelCategories,
      required this.openVideo,
      required this.isAdLoading});

  @override
  State<ChannelsSection> createState() => _ChannelsSectionState();
}

class _ChannelsSectionState extends State<ChannelsSection> {
  Key _gridKey = UniqueKey(); // Key for the GridView
  double? _itemHeight;

  @override
  Widget build(BuildContext context) {
    // Detect Windows platform (excluding Web)
    final bool isWindows =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    // Desktop: Allow wider max width for 3-4 columns
    // Mobile: Keep original 800 constraint
    final double maxContainerWidth = isWindows ? 1400 : 800;

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
                  // On Windows: Use slightly simpler height fixed logic via aspect ratio or fixed delegate
                  // Mobile: 72/80 logic
                  _itemHeight ??= 80;

                  // Determine Grid Delegate based on Platform
                  SliverGridDelegate gridDelegate;

                  if (isWindows) {
                    // Windows: Responsive grid finding optimal column count
                    // Max item width ~300. This will create 3 columns on ~900px, 4 on ~1200px etc.
                    gridDelegate =
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 3.5, // Wide, short cards for desktop
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    );
                  } else {
                    // Mobile: Original Logic (1 or 2 columns)
                    gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          orientation == Orientation.portrait ? 1 : 2,
                      childAspectRatio: _calculateAspectRatio(
                          orientation, constraints), //Dynamic
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    );
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContainerWidth),
                      child: GridView.builder(
                        key: _gridKey,
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate: gridDelegate,
                        itemCount: widget.channelCategories.length,
                        padding: EdgeInsets.all(isWindows ? 20 : 10),
                        itemBuilder: (context, index) {
                          return ChannelBox(
                              category: widget.channelCategories[index],
                              openVideo: widget.openVideo,
                              isAdLoading: widget.isAdLoading);
                        },
                      ),
                    ),
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

class ChannelBox extends StatefulWidget {
  final dynamic category;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading;

  const ChannelBox({
    super.key,
    required this.category,
    required this.openVideo,
    required this.isAdLoading,
  });

  @override
  State<ChannelBox> createState() => _ChannelBoxState();
}

class _ChannelBoxState extends State<ChannelBox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Detect Windows platform for hover effects
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    // Use name to determine icon (optional polish)
    final String name = widget.category['name'] ?? 'Unknown';
    IconData iconData = Icons.tv;
    if (name.toLowerCase().contains('sport')) iconData = Icons.sports_soccer;
    if (name.toLowerCase().contains('movie')) iconData = Icons.movie;
    if (name.toLowerCase().contains('news')) iconData = Icons.newspaper;

    if (!isDesktop) {
      // --- MOBILE LAYOUT (Original) ---
      return Card(
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
        child: InkWell(
          borderRadius: BorderRadius.circular(25.0),
          onTap: widget.isAdLoading
              ? null
              : () {
                  List channelsToPass = widget.category['channels'] ?? [];
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryChannelsScreen(
                        channels: channelsToPass,
                        openVideo: widget.openVideo,
                        isAdLoading: widget.isAdLoading,
                      ),
                    ),
                  );
                },
          child: Opacity(
            opacity: widget.isAdLoading ? 0.5 : 1.0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF673ab7),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- DESKTOP LAYOUT (Enhanced) ---
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform:
            _isHovered ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
        child: Card(
          elevation: _isHovered ? 8 : 4,
          shadowColor: _isHovered ? const Color(0xFF673ab7) : Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.0),
            side: _isHovered
                ? const BorderSide(color: Color(0xFF673ab7), width: 2)
                : BorderSide.none,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isHovered
                    ? [
                        Theme.of(context).cardColor,
                        Theme.of(context).cardColor.withOpacity(0.9),
                      ]
                    : [
                        Theme.of(context).cardColor,
                        Theme.of(context).cardColor,
                      ],
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(25.0),
              onTap: widget.isAdLoading
                  ? null
                  : () {
                      List channelsToPass = widget.category['channels'] ?? [];
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CategoryChannelsScreen(
                            channels: channelsToPass,
                            openVideo: widget.openVideo,
                            isAdLoading: widget.isAdLoading,
                          ),
                        ),
                      );
                    },
              child: Opacity(
                opacity: widget.isAdLoading ? 0.5 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon with subtle animation
                      Icon(
                        iconData,
                        color: const Color(0xFF673ab7),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      // Text
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF673ab7), // Purple user requested
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryChannelsScreen extends StatefulWidget {
  final List channels;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading; // -->> استقبل الحالة هنا

  const CategoryChannelsScreen(
      {super.key,
      required this.channels,
      required this.openVideo,
      required this.isAdLoading});

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
            // Detect Windows platform
            final bool isWindows =
                defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;
            final double maxContainerWidth = isWindows ? 1400 : 800;

            //  Calculate the item height *only* once.  VERY IMPORTANT.
            _itemHeight ??= 72; // Or get it from your original ChannelBox

            // Determine Grid Delegate
            SliverGridDelegate gridDelegate;
            if (isWindows) {
              gridDelegate = const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                childAspectRatio: 3.5,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              );
            } else {
              gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: orientation == Orientation.portrait ? 1 : 2,
                childAspectRatio: _calculateAspectRatio(
                    orientation, constraints), // Calculate dynamically
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContainerWidth),
                child: GridView.builder(
                  key: _gridKey,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: gridDelegate,
                  itemCount: widget.channels.length,
                  padding: EdgeInsets.all(isWindows ? 20 : 8),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      // Enforce the height - For Windows grid delegte, height is controlled by aspect ratio
                      // But SizedBox keeps content constrained if needed.
                      // Actually for MaxCrossAxisExtent, explicit height might conflict if ratio is set.
                      // Let's rely on delegate for Windows, keep fixed height for Mobile.
                      height: isWindows ? null : _itemHeight,
                      child: ChannelTile(
                        key: ValueKey(widget.channels[index]['id']),
                        channel: widget.channels[index],
                        openVideo: widget.openVideo,
                        isSelected:
                            _selectedChannel == widget.channels[index]['id'],
                        onChannelTap: (channelId) {
                          setState(() {
                            _selectedChannel = (_selectedChannel == channelId)
                                ? null
                                : channelId;
                          });
                        },
                        isAdLoading: widget.isAdLoading, // -->> مرر الحالة
                      ),
                    );
                  },
                ),
              ),
            );
          });
        },
      ),
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

class ChannelTile extends StatefulWidget {
  final dynamic channel;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isSelected;
  final Function(String) onChannelTap;
  final bool isAdLoading;

  const ChannelTile({
    required super.key,
    required this.channel,
    required this.openVideo,
    required this.isSelected,
    required this.onChannelTap,
    required this.isAdLoading,
  });

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  bool _isHovered = false;

  List<Map<String, String>> _extractStreamLinks(List<dynamic>? streamLinks) {
    List<Map<String, String>> streams = [];
    if (streamLinks == null) return streams;

    for (var streamLink in streamLinks) {
      if (streamLink is Map) {
        // --- FORMAT 1: Simple Object (New API) ---
        if (streamLink.containsKey('url') || streamLink.containsKey('name')) {
          String? name = streamLink['name']?.toString() ?? 'Stream';
          String? url = streamLink['url']?.toString();

          // ALWAYS add, treating missing URL as implicit premium
          streams.add({'name': name, 'url': url ?? ''});
        }

        // --- FORMAT 2: Rich Text Children (Old CMS) ---
        if (streamLink.containsKey('children')) {
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
                      streamUrl = 'https://st9.onrender.com$streamUrl';
                    }
                    streams.add({'name': streamName, 'url': streamUrl});
                  }
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
    if (widget.channel == null || widget.channel['name'] == null) {
      return const SizedBox.shrink();
    }

    String channelName = widget.channel['name'] ?? 'Unknown Channel';
    String channelId = widget.channel['id'].toString();
    List<dynamic> streamLinks =
        widget.channel['stream_link'] ?? widget.channel['StreamLink'] ?? [];

    // Detect Windows platform for hover effects
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    // Optional: Determine icon based on channel name if desired
    IconData iconData = Icons.live_tv;

    if (!isDesktop) {
      // --- MOBILE LAYOUT (Original) ---
      return Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(25.0),
          onTap: widget.isAdLoading
              ? null
              : () {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  widget.onChannelTap(channelId);

                  // Calculate isPremium status
                  List<dynamic> categories = widget.channel['categories'] ?? [];
                  bool isPremiumCategory =
                      categories.any((c) => c['is_premium'] == true);

                  // Also check individual links for premium flag
                  bool isPremiumLink =
                      streamLinks.any((l) => l['is_premium'] == true);
                  bool isPremium = isPremiumCategory || isPremiumLink;

                  List<Map<String, String>> streams =
                      _extractStreamLinks(streamLinks);

                  // Auto-detect premium if ANY stream has an empty URL
                  if (streams.any((s) => s['url']!.isEmpty)) {
                    isPremium = true;
                  }

                  // Add premium check to allow empty streams if premium
                  if (streams.isEmpty && !isPremium) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text("No stream available.")),
                    );
                    return;
                  }

                  String firstUrl =
                      streams.isNotEmpty ? streams.first['url']! : '';

                  widget.openVideo(
                      context,
                      firstUrl,
                      streams.map((e) => Map<String, dynamic>.from(e)).toList(),
                      'channels',
                      contentId: int.tryParse(channelId),
                      isPremium: isPremium);
                },
          child: Opacity(
            opacity: widget.isAdLoading ? 0.5 : 1.0,
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
        ),
      );
    }

    // --- DESKTOP LAYOUT (Enhanced) ---
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _isHovered
            ? (Matrix4.identity()..scale(1.03)) // Slight scale on hover
            : Matrix4.identity(),
        child: Card(
          elevation: _isHovered ? 8 : 4,
          shadowColor: _isHovered ? const Color(0xFF673ab7) : Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.0),
            side: _isHovered || widget.isSelected
                ? const BorderSide(color: Color(0xFF673ab7), width: 2)
                : BorderSide.none,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isHovered
                    ? [
                        Theme.of(context).cardColor,
                        Theme.of(context).cardColor.withOpacity(0.9),
                      ]
                    : [
                        Theme.of(context).cardColor,
                        Theme.of(context).cardColor,
                      ],
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(25.0),
              onTap: widget.isAdLoading
                  ? null
                  : () {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      widget.onChannelTap(channelId);

                      // Calculate isPremium status
                      List<dynamic> categories =
                          widget.channel['categories'] ?? [];
                      bool isPremiumCategory =
                          categories.any((c) => c['is_premium'] == true);

                      // Also check individual links for premium flag
                      bool isPremiumLink =
                          streamLinks.any((l) => l['is_premium'] == true);
                      bool isPremium = isPremiumCategory || isPremiumLink;

                      List<Map<String, String>> streams =
                          _extractStreamLinks(streamLinks);

                      // Auto-detect premium if ANY stream has an empty URL
                      if (streams.any((s) => s['url']!.isEmpty)) {
                        isPremium = true;
                      }

                      // Add premium check
                      if (streams.isEmpty && !isPremium) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text("No stream available.")),
                        );
                        return;
                      }

                      String firstUrl =
                          streams.isNotEmpty ? streams.first['url']! : '';

                      widget.openVideo(
                          context,
                          firstUrl,
                          streams
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList(),
                          'channels',
                          contentId: int.tryParse(channelId),
                          isPremium: isPremium);
                    },
              child: Opacity(
                opacity: widget.isAdLoading ? 0.5 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Channel Icon
                      Icon(
                        iconData,
                        color: const Color(0xFF673ab7),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          channelName,
                          style: const TextStyle(
                            color: Color(0xFF673ab7),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading; // -->> استقبل الحالة هنا

  const MatchesSection(
      {super.key,
      required this.matches,
      required this.openVideo,
      required this.isAdLoading});

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

          final allMatches = [
            ...liveMatches,
            ...upcomingMatches,
            ...finishedMatches
          ];

          // Detect Windows platform
          final bool isWindows =
              defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

          if (isWindows) {
            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Force 3 columns
                childAspectRatio: 2.5, // Wider cards for premium look
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: allMatches.length,
              itemBuilder: (context, index) {
                return MatchBox(
                  match: allMatches[index],
                  openVideo: openVideo,
                  isAdLoading: isAdLoading,
                );
              },
            );
          }

          return ListView(
            children: allMatches
                .map((match) => MatchBox(
                    match: match,
                    openVideo: openVideo,
                    isAdLoading: isAdLoading))
                .toList(),
          );
        }
      }, // End builder method
    ); // End FutureBuilder
  }
}

class MatchBox extends StatefulWidget {
  final Match match;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading;

  const MatchBox({
    super.key,
    required this.match,
    required this.openVideo,
    required this.isAdLoading,
  });

  @override
  State<MatchBox> createState() => _MatchBoxState();
}

class _MatchBoxState extends State<MatchBox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final teamA = widget.match.teamA;
    final teamB = widget.match.teamB;
    String logoA = widget.match.logoAUrl ?? '';
    String logoB = widget.match.logoBUrl ?? '';
    final matchTime = widget.match.matchTime;
    final commentator = widget.match.commentator ?? '';
    final channel = widget.match.channel ?? '';
    final champion = widget.match.champion ?? '';
    final streamLink = widget.match.streamLinks;

    if (logoA.isNotEmpty && !logoA.startsWith('http')) {
      logoA = 'https://st9.onrender.com$logoA';
    }
    if (logoB.isNotEmpty && !logoB.startsWith('http')) {
      logoB = 'https://st9.onrender.com$logoB';
    }

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
      // Only add streams with valid URLs
      final url = streamLinkItem.url;
      if (url != null && url.isNotEmpty) {
        streams.add({
          'name':
              streamLinkItem.name.isNotEmpty ? streamLinkItem.name : 'Stream',
          'url': url
        });
      }
    }

    // Detect Windows platform for hover effects
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    if (!isDesktop) {
      // --- MOBILE LAYOUT (Original) ---
      return GestureDetector(
        onTap: widget.isAdLoading
            ? null
            : () {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                bool isPremium = widget.match.isPremium;

                if (streams.isEmpty && !isPremium) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('لا يوجد رابط للبث المباشر')),
                  );
                  return;
                }

                String firstUrl =
                    streams.isNotEmpty ? streams.first['url']! : '';

                widget.openVideo(
                  context,
                  firstUrl,
                  streams.map((e) => Map<String, dynamic>.from(e)).toList(),
                  'matches',
                  contentId: widget.match.id,
                  isPremium: isPremium,
                );
              },
        child: Opacity(
          opacity: widget.isAdLoading ? 0.5 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              // Gradient Background for Premium Look
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF141414), Colors.black], // Dark default
              ),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            margin: const EdgeInsets.all(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTeamLogo(logoA, size: 55),
                              SizedBox(height: 8),
                              Text(teamA,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: borderColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              timeStatus,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTeamLogo(logoB, size: 55),
                              SizedBox(height: 8),
                              Text(teamB,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: Colors.white10),
                  SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(commentator,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events,
                                size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(champion,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tv, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(channel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // --- DESKTOP LAYOUT (Enhanced) ---
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isAdLoading
            ? null
            : () {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                bool isPremium = widget.match.isPremium;

                if (streams.isEmpty && !isPremium) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('لا يوجد رابط للبث المباشر')),
                  );
                  return;
                }

                String firstUrl =
                    streams.isNotEmpty ? streams.first['url']! : '';

                widget.openVideo(
                  context,
                  firstUrl,
                  streams.map((e) => Map<String, dynamic>.from(e)).toList(),
                  'matches',
                  contentId: widget.match.id,
                  isPremium: isPremium,
                );
              },
        child: Opacity(
          opacity: widget.isAdLoading ? 0.5 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: _isHovered
                ? (Matrix4.identity()..scale(1.02)) // Slight scale
                : Matrix4.identity(),
            decoration: BoxDecoration(
              // Gradient Background for Premium Look
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isHovered
                    ? [
                        const Color(0xFF2A2A2A),
                        const Color(0xFF1A1A1A)
                      ] // Lighter on hover
                    : [const Color(0xFF141414), Colors.black], // Dark default
              ),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFF673ab7)
                    : Colors.white.withOpacity(0.1),
                width: _isHovered ? 2 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF673ab7).withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            margin: const EdgeInsets.all(8),
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        // Team A
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildTeamLogo(logoA, size: 50),
                                  const SizedBox(height: 6),
                                  Text(teamA,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            // Time/Score
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: borderColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  timeStatus,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            // Team B
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildTeamLogo(logoB, size: 50),
                                  const SizedBox(height: 6),
                                  Text(teamB,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Channel Name
                      Text(
                        channel,
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                            fontWeight: FontWeight.w400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Divider Line (Centered, not full width)
                      Container(
                        width: 80,
                        height: 1,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 6),
                      // Commentator & Champion Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (commentator.isNotEmpty)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic,
                                      size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      commentator,
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (champion.isNotEmpty)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events,
                                      size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      champion,
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String logoUrl, {double size = 60}) {
    return SizedBox(
      width: size,
      height: size,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain, // Maintain aspect ratio
              // Use memCacheHeight/Width to improve quality/performance relation
              // If pixelation is the issue, we avoid resizing too small here.
              // Actually, simply removing resize params ensures we get full quality,
              // but we rely on 'fit' to scale down visually.
              filterQuality: FilterQuality.high, // Ensure high quality scaling
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => Image.asset(
                'assets/no-image.png',
                width: size * 0.8,
                height: size * 0.8,
                color: Colors.grey[600],
              ),
            )
          : Image.asset(
              'assets/no-image.png',
              width: size * 0.8,
              height: size * 0.8,
              color: Colors.grey[600],
            ),
    );
  }
}

class NewsSection extends StatelessWidget {
  final Future<List<dynamic>> newsArticles;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading; // -->> استقبل الحالة هنا

  const NewsSection(
      {super.key,
      required this.newsArticles,
      required this.openVideo,
      required this.isAdLoading});

  @override
  Widget build(BuildContext context) {
    // Removed unused variables screenWidth and titleFontSize

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
          final articles = snapshot.data!;

          final bool isWindows =
              defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

          if (isWindows) {
            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.1, // Adjusted for fixed image height
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                return NewsBox(
                  article: articles[index],
                  openVideo: openVideo,
                  isAdLoading: isAdLoading,
                );
              },
            );
          }

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
                    return NewsBox(
                        article: article,
                        openVideo: openVideo,
                        isAdLoading: isAdLoading); // -->> مرر الحالة
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

class NewsBox extends StatefulWidget {
  final dynamic article;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading;

  const NewsBox({
    super.key,
    required this.article,
    required this.openVideo,
    required this.isAdLoading,
  });

  @override
  State<NewsBox> createState() => _NewsBoxState();
}

class _NewsBoxState extends State<NewsBox> {
  bool _isHovered = false;

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
    final title = widget.article['title'];
    final date = widget.article['date'] != null
        ? DateFormat('dd-MM-yyyy')
            .format(DateTime.parse(widget.article['date']))
        : '';
    final linkData = widget.article['link'];

    dynamic processedLinkData = linkData;
    if (processedLinkData is String &&
        processedLinkData.trim().startsWith('[')) {
      try {
        processedLinkData = json.decode(processedLinkData);
      } catch (e) {
        debugPrint("Error decoding link JSON: $e");
      }
    }

    final List<Map<String, String>> streams = [];
    if (processedLinkData is String && processedLinkData.isNotEmpty) {
      streams.add({'name': 'Watch', 'url': processedLinkData});
    } else if (processedLinkData is List) {
      streams.addAll(_extractStreamLinks(processedLinkData));
    }

    String? imageUrl;
    final imageObj = widget.article['image'];
    if (imageObj != null) {
      if (imageObj is String) {
        imageUrl = imageObj;
      } else if (imageObj is Map) {
        imageUrl = imageObj['url'];
      } else if (imageObj is List && imageObj.isNotEmpty) {
        imageUrl = imageObj[0]['url'];
      }
    }

    // Detect Windows platform for hover effects
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    if (!isDesktop) {
      // --- MOBILE LAYOUT (Original) ---
      return GestureDetector(
        onTap: widget.isAdLoading
            ? null
            : () {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                bool isPremium = widget.article['is_premium'] ?? false;
                int? id = int.tryParse(widget.article['id']?.toString() ?? '');

                if (streams.isNotEmpty || isPremium) {
                  String firstStreamUrl =
                      streams.isNotEmpty ? streams[0]['url'] ?? '' : '';
                  widget.openVideo(
                      context,
                      firstStreamUrl,
                      streams.map((e) => Map<String, dynamic>.from(e)).toList(),
                      'news',
                      contentId: id,
                      isPremium: isPremium);
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                        content:
                            Text('No video link found for this news article.')),
                  );
                }
              },
        child: Opacity(
          opacity: widget.isAdLoading ? 0.5 : 1.0,
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0)),
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl ?? '',
                  placeholder: (context, url) =>
                      Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
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
        ),
      );
    }

    // --- DESKTOP LAYOUT (Enhanced) ---
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isAdLoading
            ? null
            : () {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                bool isPremium = widget.article['is_premium'] ?? false;
                int? id = int.tryParse(widget.article['id']?.toString() ?? '');

                if (streams.isNotEmpty || isPremium) {
                  String firstStreamUrl =
                      streams.isNotEmpty ? streams[0]['url'] ?? '' : '';
                  widget.openVideo(
                      context,
                      firstStreamUrl,
                      streams.map((e) => Map<String, dynamic>.from(e)).toList(),
                      'news',
                      contentId: id,
                      isPremium: isPremium);
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                        content:
                            Text('No video link found for this news article.')),
                  );
                }
              },
        child: Opacity(
          opacity: widget.isAdLoading ? 0.5 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: _isHovered
                ? (Matrix4.identity()..scale(1.02))
                : Matrix4.identity(),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  side: _isHovered
                      ? const BorderSide(color: Color(0xFF673ab7), width: 2)
                      : BorderSide.none),
              clipBehavior: Clip.antiAlias,
              elevation: _isHovered ? 8 : 4,
              shadowColor: _isHovered ? const Color(0xFF673ab7) : null,
              margin: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl ?? '',
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => _buildPlaceholder(),
                    height: 180, // Slightly reduced to fit text
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading; // -->> استقبل الحالة هنا

  const GoalsSection({
    super.key,
    required this.goalsArticles,
    required this.openVideo,
    required this.isAdLoading, // -->> استقبل الحالة هنا
  });

  @override
  Widget build(BuildContext context) {
    // Removed unused variables screenWidth and titleFontSize

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

        // Detect Windows platform
        final bool isWindows =
            defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

        if (isWindows) {
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1, // Reverted to better proportions
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              return GoalBox(
                goal: goals[index],
                openVideo: openVideo,
                isAdLoading: isAdLoading,
              );
            },
          );
        }

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
                  return GoalBox(
                    goal: goals[index],
                    openVideo: openVideo,
                    isAdLoading: isAdLoading,
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

class GoalBox extends StatefulWidget {
  final dynamic goal;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isAdLoading;

  const GoalBox({
    super.key,
    required this.goal,
    required this.openVideo,
    required this.isAdLoading,
  });

  @override
  State<GoalBox> createState() => _GoalBoxState();
}

class _GoalBoxState extends State<GoalBox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.goal['title'] ?? '';
    final urlData = widget.goal['url'];
    debugPrint("FULL GOAL DATA: ${widget.goal}");
    debugPrint("DEBUG GOAL URL: $urlData");

    dynamic processedUrlData = urlData;
    if (processedUrlData is String && processedUrlData.trim().startsWith('[')) {
      try {
        processedUrlData = json.decode(processedUrlData);
      } catch (e) {
        debugPrint("Error decoding goal JSON: $e");
      }
    }

    List<Map<String, dynamic>> streamLinks = [];
    if (processedUrlData is String && processedUrlData.isNotEmpty) {
      streamLinks.add({'name': 'Watch', 'url': processedUrlData});
    } else if (processedUrlData is List) {
      for (var item in processedUrlData) {
        if (item is Map &&
            item['type'] == 'paragraph' &&
            item['children'] is List) {
          for (var child in item['children']) {
            if (child is Map &&
                child['type'] == 'link' &&
                child['url'] != null) {
              streamLinks.add({
                'name': child['children']?[0]['text'] ?? 'Link',
                'url': child['url'],
              });
            }
          }
        }
      }
    }

    final imageObj = widget.goal['image'];
    String? imageUrl;
    if (imageObj != null) {
      if (imageObj is String) {
        imageUrl = imageObj;
      } else if (imageObj is Map) {
        imageUrl = imageObj['url'];
      } else if (imageObj is List && imageObj.isNotEmpty) {
        imageUrl = imageObj[0]['url'];
      }
    }

    final time = widget.goal['time'] ?? '';

    // Detect Windows platform for hover effects
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    if (!isDesktop) {
      // --- MOBILE LAYOUT (Original) ---
      return GestureDetector(
        onTap: widget.isAdLoading
            ? null
            : () {
                bool isPremium = widget.goal['is_premium'] ?? false;
                int? id = int.tryParse(widget.goal['id']?.toString() ?? '');

                if (streamLinks.isNotEmpty || isPremium) {
                  String firstUrl =
                      streamLinks.isNotEmpty ? streamLinks[0]['url'] : '';
                  widget.openVideo(context, firstUrl, streamLinks, 'goals',
                      contentId: id, isPremium: isPremium);
                }
              },
        child: Opacity(
          opacity: widget.isAdLoading ? 0.5 : 1.0,
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0)),
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
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
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium!.color,
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

    // --- DESKTOP LAYOUT (Enhanced) ---
    return MouseRegion(
      onEnter: (_) => isDesktop ? setState(() => _isHovered = true) : null,
      onExit: (_) => isDesktop ? setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.isAdLoading
            ? null
            : () {
                bool isPremium = widget.goal['is_premium'] ?? false;
                int? id = int.tryParse(widget.goal['id']?.toString() ?? '');

                if (streamLinks.isNotEmpty || isPremium) {
                  String firstUrl =
                      streamLinks.isNotEmpty ? streamLinks[0]['url'] : '';
                  widget.openVideo(context, firstUrl, streamLinks, 'goals',
                      contentId: id, isPremium: isPremium);
                }
              },
        child: Opacity(
          opacity: widget.isAdLoading ? 0.5 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: _isHovered
                ? (Matrix4.identity()..scale(1.02))
                : Matrix4.identity(),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  side: _isHovered
                      ? const BorderSide(color: Color(0xFF673ab7), width: 2)
                      : BorderSide.none),
              clipBehavior: Clip.antiAlias,
              elevation: _isHovered ? 8 : 4,
              shadowColor: _isHovered ? const Color(0xFF673ab7) : null,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.movie, size: 50, color: Colors.grey),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
