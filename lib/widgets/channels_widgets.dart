import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ChannelsSection extends StatefulWidget {
  final List channelCategories;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const ChannelsSection(
      {super.key, required this.channelCategories, required this.openVideo});

  @override
  State<ChannelsSection> createState() => _ChannelsSectionState();
}

class _ChannelsSectionState extends State<ChannelsSection> {
  final Key _gridKey = UniqueKey(); // Key for the GridView

  @override
  Widget build(BuildContext context) {
    if (widget.channelCategories.isEmpty) {
      return Center(
        child: Text(
          'لا توجد قنوات لعرضها',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
      );
    }

    final bool isWindows =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;
    final double maxContainerWidth = isWindows ? 1500 : 900;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContainerWidth),
        child: GridView.builder(
          key: _gridKey,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWindows ? 30 : 16,
            vertical: 20,
          ),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isWindows ? 500 : 350,
            mainAxisExtent:
                isWindows ? 160 : 135, // Increased height for better fit
            crossAxisSpacing: isWindows ? 25 : 12,
            mainAxisSpacing: isWindows ? 25 : 12,
          ),
          itemCount: widget.channelCategories.length,
          itemBuilder: (context, index) {
            return ChannelBox(
              category: widget.channelCategories[index],
              openVideo: widget.openVideo,
            );
          },
        ),
      ),
    );
  }
}

class ChannelBox extends StatefulWidget {
  final dynamic category;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const ChannelBox({
    super.key,
    required this.category,
    required this.openVideo,
  });

  @override
  State<ChannelBox> createState() => _ChannelBoxState();
}

class _ChannelBoxState extends State<ChannelBox> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final String name = widget.category['name'] ?? 'Unknown';
    final String lowerName = name.toLowerCase();
    final bool isPremium = widget.category['is_premium'] == true;

    // Detect Windows platform for hover effects
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    final bool hasImage = widget.category['image'] != null &&
        widget.category['image'].toString().isNotEmpty;

    // --- Modern Categorical Color Palette ---
    Color baseColor;
    IconData iconData;
    List<Color> gradientColors;

    if (lowerName.contains('sport') ||
        lowerName.contains('koora') ||
        lowerName.contains('match')) {
      baseColor = Colors.green;
      iconData = Icons.sports_soccer_rounded;
      gradientColors = [
        const Color(0xFF00C853),
        const Color(0xFF2E7D32),
        const Color(0xFF1B5E20)
      ];
    } else if (lowerName.contains('movie') ||
        lowerName.contains('film') ||
        lowerName.contains('cinema')) {
      baseColor = Colors.red;
      iconData = Icons.movie_filter_rounded;
      gradientColors = [
        const Color(0xFFFF1744),
        const Color(0xFFC62828),
        const Color(0xFFB71C1C)
      ];
    } else if (lowerName.contains('news') || lowerName.contains('akhbar')) {
      baseColor = Colors.blue;
      iconData = Icons.newspaper_rounded;
      gradientColors = [
        const Color(0xFF2979FF),
        const Color(0xFF1565C0),
        const Color(0xFF0D47A1)
      ];
    } else if (lowerName.contains('serie') ||
        lowerName.contains('show') ||
        lowerName.contains('drama') ||
        lowerName.contains('مسلسل')) {
      baseColor = Colors.purple;
      iconData = Icons.video_collection_rounded;
      gradientColors = [
        const Color(0xFFD500F9),
        const Color(0xFF7B1FA2),
        const Color(0xFF4A148C)
      ];
    } else if (lowerName.contains('kid') ||
        lowerName.contains('toon') ||
        lowerName.contains('carton') ||
        lowerName.contains('أطفال')) {
      baseColor = Colors.orange;
      iconData = Icons.child_care_rounded;
      gradientColors = [
        const Color(0xFFFF9100),
        const Color(0xFFEF6C00),
        const Color(0xFFE65100)
      ];
    } else if (lowerName.contains('music') ||
        lowerName.contains('song') ||
        lowerName.contains('أغاني')) {
      baseColor = Colors.pink;
      iconData = Icons.music_note_rounded;
      gradientColors = [
        const Color(0xFFF50057),
        const Color(0xFFC2185B),
        const Color(0xFF880E4F)
      ];
    } else if (lowerName.contains('bein')) {
      baseColor = const Color(0xFF673ab7);
      iconData = Icons.live_tv_rounded;
      gradientColors = [
        const Color(0xFF9067C6),
        const Color(0xFF673AB7),
        const Color(0xFF240046)
      ];
    } else {
      baseColor = const Color(0xFF673ab7);
      iconData = Icons.tv_rounded;
      gradientColors = [
        const Color(0xFF7E57C2),
        const Color(0xFF673AB7),
        const Color(0xFF512DA8)
      ];
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CategoryChannelsScreen(
                category: widget.category,
                openVideo: widget.openVideo,
              ),
            ),
          );
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                if (_isHovered)
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    spreadRadius: -2,
                  ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // --- Background Base (Themed or Gradient) ---
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
                // Mesh/Themed Background behind glass
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasImage ? Theme.of(context).cardColor : null,
                        gradient: !hasImage
                            ? SweepGradient(
                                center: Alignment.topLeft,
                                colors: [
                                  baseColor,
                                  baseColor.withValues(alpha: 0.8),
                                  baseColor.withValues(alpha: 0.6),
                                  baseColor,
                                ],
                                stops: const [0.0, 0.4, 0.6, 1.0],
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // --- Subtle Patterns / Overlays (Only if no image) ---
                if (!hasImage)
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // --- Main Content ---
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // IMAGE OR ICON
                        Flexible(
                          child: hasImage
                              ? CachedNetworkImage(
                                  imageUrl: widget.category['image'].toString(),
                                  cacheManager: CacheManager(
                                    Config(
                                      'categoryCache',
                                      stalePeriod: const Duration(days: 30),
                                      maxNrOfCacheObjects: 100,
                                    ),
                                  ),
                                  fit: BoxFit
                                      .contain, // Show FULL image without clipping
                                  placeholder: (context, url) => const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 1.5))),
                                  errorWidget: (context, url, error) => Icon(
                                      iconData,
                                      color: baseColor,
                                      size: isDesktop ? 40 : 28),
                                )
                              : Container(
                                  width: isDesktop ? 80 : 60,
                                  height: isDesktop ? 80 : 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: Colors.white,
                                    size: isDesktop ? 48 : 28,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        SizedBox(height: isDesktop ? 16 : 14),
                        // Title
                        Text(
                          name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasImage
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87)
                                : Colors.white,
                            fontSize: isDesktop ? 22 : 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            shadows: !hasImage
                                ? const [
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Premium Badge ---
                if (isPremium)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            "PREMIUM",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- Tap Feedback Overlay ---
                if (_isPressed)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryChannelsScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const CategoryChannelsScreen(
      {super.key, required this.category, required this.openVideo});

  @override
  State<CategoryChannelsScreen> createState() => _CategoryChannelsScreenState();
}

class _CategoryChannelsScreenState extends State<CategoryChannelsScreen> {
  String? _selectedChannel;

  @override
  Widget build(BuildContext context) {
    final String categoryName = widget.category['name'] ?? 'Unknown';
    final List channels =
        widget.category['channels'] ?? widget.category['Channels'] ?? [];
    final bool isPremiumCategory = widget.category['is_premium'] == true;

    // Detect Windows platform
    final bool isWindows =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // --- Premium Sliver Header ---
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF673AB7),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                categoryName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.0,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF673AB7), Color(0xFF512DA8)],
                      ),
                    ),
                  ),
                  // Small Center Icon
                  if (widget.category['image'] != null &&
                      widget.category['image'].toString().isNotEmpty)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        width: 50,
                        height: 50,
                        child: CachedNetworkImage(
                          imageUrl: widget.category['image'].toString(),
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const SizedBox(
                            width: 20,
                            height: 20,
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white70)),
                          ),
                          errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  if (isPremiumCategory &&
                      (widget.category['image'] == null ||
                          widget.category['image'].toString().isEmpty))
                    Center(
                      child: Opacity(
                        opacity: 0.1,
                        child: Icon(Icons.stars_rounded,
                            size: 80, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // --- Channel Grid Section ---
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isWindows ? 40 : 12,
              vertical: 20,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                // Determine Grid Delegate
                SliverGridDelegate gridDelegate;
                if (isWindows) {
                  gridDelegate = const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 600,
                    childAspectRatio: 3.8,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  );
                } else {
                  gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 600,
                    mainAxisExtent:
                        95, // Increased height to prevent overflow with premium tags
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  );
                }

                return SliverGrid(
                  gridDelegate: gridDelegate,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final channel = channels[index];
                      return ChannelTile(
                        key: ValueKey(channel['id']),
                        channel: channel,
                        openVideo: widget.openVideo,
                        isSelected:
                            _selectedChannel == channel['id'].toString(),
                        onChannelTap: (channelId) {
                          setState(() {
                            _selectedChannel = (_selectedChannel == channelId)
                                ? null
                                : channelId;
                          });
                        },
                      );
                    },
                    childCount: channels.length,
                  ),
                );
              },
            ),
          ),

          // Bottom space for scrolling
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class ChannelTile extends StatefulWidget {
  final dynamic channel;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool isSelected;
  final Function(String) onChannelTap;

  const ChannelTile({
    required super.key,
    required this.channel,
    required this.openVideo,
    required this.isSelected,
    required this.onChannelTap,
  });

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  List<Map<String, String>> _extractStreamLinks(List<dynamic>? streamLinks) {
    List<Map<String, String>> streams = [];
    if (streamLinks == null) return streams;

    for (var streamLink in streamLinks) {
      if (streamLink is Map) {
        // --- FORMAT 1: Simple Object (New API) ---
        if (streamLink.containsKey('url') ||
            streamLink.containsKey('name') ||
            streamLink.containsKey('link')) {
          String? name = streamLink['name']?.toString() ?? 'Stream';

          // Try multiple keys for URL
          String? url = streamLink['url']?.toString() ??
              streamLink['link']?.toString() ??
              streamLink['src']?.toString() ??
              streamLink['stream_url']?.toString();

          // ALWAYS add, treating missing URL as implicit premium
          streams.add({'name': name, 'url': url ?? ''});
        }

        // --- FORMAT 2: Rich Text Children (Old CMS) ---
        if (streamLink.containsKey('children')) {
          for (var child in streamLink['children'] ?? []) {
            if (child is Map &&
                child.containsKey('type') &&
                child['type'] == 'link' &&
                child.containsKey('url') &&
                child.containsKey('children')) {
              for (var textChild in child['children'] ?? []) {
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

    final String channelName = widget.channel['name'] ?? 'Unknown Channel';
    final String channelId = widget.channel['id'].toString();
    final List<dynamic> streamLinks =
        widget.channel['stream_link'] ?? widget.channel['StreamLink'] ?? [];

    // Check premium status
    bool isPremium = widget.channel['is_premium'] == true;
    if (!isPremium) {
      final List categories = widget.channel['categories'] as List? ?? [];
      if (categories.any((c) => c is Map && c['is_premium'] == true)) {
        isPremium = true;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          widget.onChannelTap(channelId);
          final List<Map<String, String>> streams =
              _extractStreamLinks(streamLinks);

          if (streams.isEmpty && !isPremium) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No stream available.")),
            );
            return;
          }

          final String firstUrl =
              streams.isNotEmpty ? streams.first['url']! : '';
          widget.openVideo(
              context,
              firstUrl,
              streams.map((e) => Map<String, dynamic>.from(e)).toList(),
              'channels',
              contentId: int.tryParse(channelId),
              isPremium: isPremium);
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isSelected
                    ? [
                        const Color(0xFF9C27B0), // Vibrant Purple
                        const Color(0xFF4A148C), // Deep Purple
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ],
              ),
              border: Border.all(
                color: widget.isSelected
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                if (widget.isSelected)
                  BoxShadow(
                    color: const Color(0xFF9126AD).withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Stack(
              children: [
                // Glossy Top Highlight
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white
                              .withValues(alpha: widget.isSelected ? 0.3 : 0.1),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Selected Accent Bar (Glow)
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    top: 15,
                    bottom: 15,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // --- Channel Info ---
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                channelName,
                                style: TextStyle(
                                  color: widget.isSelected
                                      ? Colors.white
                                      : const Color(0xFFE1BEE7),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.4),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    )
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isPremium)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.amber
                                              .withValues(alpha: 0.3),
                                          width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.workspace_premium,
                                            color: Colors.amber, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          "PREMIUM",
                                          style: TextStyle(
                                            color: Colors.amber[300],
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // --- Play HUD Indicator ---
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.isSelected
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
