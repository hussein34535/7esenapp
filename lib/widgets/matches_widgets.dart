import 'package:flutter/material.dart';
import 'package:hesen/models/match_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class MatchesSection extends StatelessWidget {
  final Future<List<Match>> matches;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const MatchesSection(
      {super.key, required this.matches, required this.openVideo});

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
                    matchDateTimeWithToday.add(const Duration(minutes: 110)))) {
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
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 600, // Responsive 3-column layout
                childAspectRatio: 2.2, // Reverted to elegant/compact look
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: allMatches.length,
              itemBuilder: (context, index) {
                return MatchBox(
                  match: allMatches[index],
                  openVideo: openVideo,
                );
              },
            );
          }

          return ListView(
            children: allMatches
                .map((match) => MatchBox(match: match, openVideo: openVideo))
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

  const MatchBox({
    super.key,
    required this.match,
    required this.openVideo,
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

    Color borderColor; // Controls the "Status" box in the middle
    Color badgeColor; // Controls the "Champion" badge at the bottom

    if (matchDateTimeWithToday.isBefore(now) &&
        now.isBefore(
            matchDateTimeWithToday.add(const Duration(minutes: 110)))) {
      timeStatus = 'مباشر';
      borderColor = Colors.red;
      badgeColor = Colors.red.withValues(alpha: 0.5); // Lighter/Transparent Red
    } else if (now
        .isAfter(matchDateTimeWithToday.add(const Duration(minutes: 110)))) {
      timeStatus = 'انتهت المباراة';
      borderColor = Colors.grey[800]!; // Status box = Chic Dark Grey
      badgeColor = Colors.grey[800]!; // Badge = Chic Dark Grey
    } else {
      timeStatus = DateFormat('hh:mm a').format(matchDateTimeWithToday);
      borderColor = Colors.blueAccent;
      badgeColor =
          Colors.blueAccent.withValues(alpha: 0.5); // Lighter/Transparent Blue
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

    // --- UNIFIED LAYOUT (Uses Desktop Design for All) ---
    // Combined logic for both Mobile and Windows as requested by user ("Restore shape").
    // Adjusted for more vertical breathing room and closer metadata items.

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          bool isPremium = widget.match.isPremium;
          String firstUrl = streams.isNotEmpty ? streams.first['url']! : '';

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
          opacity: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: _isHovered
                ? Matrix4.diagonal3Values(1.02, 1.02, 1.0) // Slight scale
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
                    : Colors.white.withValues(alpha: 0.1),
                width: _isHovered ? 2 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF673ab7).withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            margin: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- TEAMS & SCORE (Centered) ---
                    // Added Top Padding as requested to separate logos from top border
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // TEAM A
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTeamLogo(logoA, size: 45),
                                const SizedBox(height: 6),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    teamA,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // TIME / VS
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      borderColor, // Solid Fill as requested ("مسمط")
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  timeStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // TEAM B
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTeamLogo(logoB, size: 45),
                                const SizedBox(height: 6),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    teamB,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- DIVIDER ---
                    const SizedBox(height: 8),
                    Container(
                      width: 120, // Subtle short divider
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 8),

                    // --- METADATA (Channel & Commentator) ---
                    // Adjusted spacing: Increased gap and bottom padding to clear the badge
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 45),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Channel
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tv,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    channel.isEmpty ? 'غير محدد' : channel,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Increased Gap
                          if (commentator.isNotEmpty)
                            const SizedBox(width: 130),

                          // Commentator
                          if (commentator.isNotEmpty)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic,
                                      size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      commentator,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // --- CHAMPION TRIANGLE BADGE ---
                if (champion.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CustomPaint(
                        painter: TrianglePainter(color: badgeColor),
                        child: Container(
                          // Added Bottom Padding to separate text from bottom edge
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                          child: Text(
                            champion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.match.isPremium)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: Icon(Icons.stars, color: Colors.amber, size: 18),
                  ),
              ],
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
                  Center(child: CircularProgressIndicator()),
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

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Trapezoid shape pointing up from bottom
    path.moveTo(0, size.height); // Bottom Left
    path.lineTo(size.width, size.height); // Bottom Right
    path.lineTo(size.width - 8, 0); // Top Right (inset)
    path.lineTo(8, 0); // Top Left (inset)
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
