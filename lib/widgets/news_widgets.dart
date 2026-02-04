import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class NewsSection extends StatelessWidget {
  final Future<List<dynamic>> newsArticles;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const NewsSection(
      {super.key, required this.newsArticles, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    // Removed unused variables screenWidth and titleFontSize

    return FutureBuilder<List<dynamic>>(
      future: newsArticles,
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
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 600, // Responsive 3-column layout
                childAspectRatio: 1.4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                return NewsBox(
                  article: articles[index],
                  openVideo: openVideo,
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

class NewsBox extends StatefulWidget {
  final dynamic article;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const NewsBox({
    super.key,
    required this.article,
    required this.openVideo,
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
        processedLinkData = jsonDecode(processedLinkData);
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
        onTap: () {
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
              const SnackBar(
                  content: Text('No video link found for this news article.')),
            );
          }
        },
        child: Opacity(
          opacity: 1.0,
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
                  height: 180, // Reduced from 200 for better proportion
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
                          fontSize: 16, // Refined size
                          color: Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.white, // Standard text color
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(
                          color: Colors.grey.withValues(alpha: 0.2),
                          height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
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
        onTap: () {
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
              const SnackBar(
                  content: Text('No video link found for this news article.')),
            );
          }
        },
        child: Opacity(
          opacity: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: _isHovered
                ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
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
                  Expanded(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
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
                            fontSize: 16,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(
                            color: Colors.grey.withValues(alpha: 0.2),
                            height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey[900],
      child: Center(
        child: Icon(Icons.movie_creation_outlined,
            size: 50, color: Colors.grey[600]),
      ),
    );
  }
}
