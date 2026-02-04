import 'package:flutter/material.dart';
import 'package:hesen/models/highlight_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

class HighlightsSection extends StatelessWidget {
  final Future<List<Highlight>> highlights;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const HighlightsSection(
      {super.key, required this.highlights, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Highlight>>(
      future: highlights,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'خطأ في استرجاع الملخصات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge!.color),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'لا توجد ملخصات لعرضها',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge!.color),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          final items = snapshot.data!;
          final bool isWindows =
              defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

          if (isWindows) {
            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    600, // Responsive columns for 3nd column layout
                childAspectRatio: 1.4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return HighlightBox(
                  highlight: items[index],
                  openVideo: openVideo,
                );
              },
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return HighlightBox(
                  highlight: items[index], openVideo: openVideo);
            },
          );
        }
      },
    );
  }
}

class HighlightBox extends StatefulWidget {
  final Highlight highlight;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const HighlightBox({
    super.key,
    required this.highlight,
    required this.openVideo,
  });

  @override
  State<HighlightBox> createState() => _HighlightBoxState();
}

class _HighlightBoxState extends State<HighlightBox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String? imageUrl = widget.highlight.imageUrl;
    String title = widget.highlight.title;
    bool isPremium = widget.highlight.isPremium;

    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http')) {
      imageUrl = 'https://st9.onrender.com$imageUrl';
    }

    List<Map<String, dynamic>> streams = widget.highlight.sources
        .map((s) => {'name': s.name, 'url': s.url})
        .toList();

    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;
    void handleTap() {
      String firstUrl = streams.isNotEmpty
          ? streams[0]['url'] ?? ''
          : widget.highlight.primaryUrl;
      widget.openVideo(
        context,
        firstUrl,
        streams,
        'highlights',
        contentId: widget.highlight.id,
        isPremium: isPremium,
      );
    }

    if (!isDesktop) {
      // --- MOBILE LAYOUT (Safe for ListView) ---
      return GestureDetector(
        onTap: handleTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Container
              Stack(
                children: [
                  SizedBox(
                    height: 200, // Slightly taller
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isPremium)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars, color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "Premium",
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Play Icon Overlay
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ],
              ),

              // Text Content
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
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.video_library,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'اضغط للمشاهدة',
                          style: TextStyle(
                            color: Colors.grey[600],
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
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: (isDesktop && _isHovered)
              ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
              : Matrix4.identity(),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
              side: (isDesktop && _isHovered)
                  ? const BorderSide(color: Color(0xFF673ab7), width: 2)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            elevation: (isDesktop && _isHovered) ? 8 : 4,
            shadowColor:
                (isDesktop && _isHovered) ? const Color(0xFF673ab7) : null,
            margin: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl ?? '',
                    placeholder: (context, url) =>
                        const Center(child: const CircularProgressIndicator()),
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
                          color: Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(
                          color: Colors.grey.withValues(alpha: 0.2),
                          height: 12),
                      if (isPremium)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.stars, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  "Premium",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
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
