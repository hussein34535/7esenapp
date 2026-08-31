part of 'package:hesen/screens/home_page.dart';

mixin HomePageUIMixin on HomePageDataMixin {
  void openVideo(BuildContext context, String? initialUrl,
      List<Map<String, dynamic>> streamLinks, String sourceSection,
      {int? contentId, bool isPremium = false}) {
    if (isPremium) {
      String apiType = sourceSection;
      if (sourceSection == 'channels') apiType = 'channel';
      if (sourceSection == 'goals') apiType = 'goal';
      if (sourceSection == 'news') apiType = 'news';
      if (sourceSection == 'matches') apiType = 'match';
      _navigateToVideoPlayer(context, initialUrl ?? '', streamLinks,
          isLocked: true, contentId: contentId, category: apiType);
      return;
    }
    _navigateToVideoPlayer(context, initialUrl ?? '', streamLinks);
  }

  Future<void> _navigateToVideoPlayer(BuildContext context, String initialUrl,
      List<Map<String, dynamic>> streamLinks,
      {bool isLocked = false, int? contentId, String? category}) async {
    final videoScreen = VideoPlayerScreen(
      initialUrl: initialUrl,
      streamLinks: streamLinks,
      isLocked: isLocked,
      contentId: contentId,
      category: category,
    );
    if (kIsWeb) {
      await navigatorKey.currentState?.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => videoScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } else {
      await navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => videoScreen));
    }
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];
    if (!_isSubscribed) {
      actions.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.black87, size: 17),
              label: const Text('PRO',
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5)),
            ),
          ),
        ),
      );
    }

    Color packageColor = const Color(0xFFDFBA73); // Muted Champagne Gold
    if (_subscriptionPlan != null) {
      final plan = _subscriptionPlan!.toLowerCase();
      if (plan.contains('ultra') ||
          plan.contains('الترا') ||
          plan.contains('ألترا')) {
        packageColor =
            const Color(0xFF9F7AEA); // Premium Soft Purple/Violet for Ultra
      } else if (plan.contains('pro') || plan.contains('برو')) {
        packageColor = const Color(0xFF00F0FF); // Cyan for Pro
      } else if (plan.contains('شهري') || plan.contains('month')) {
        packageColor = const Color(0xFF759CD8); // Soft Pastel Slate Blue
      } else if (plan.contains('سنوي') || plan.contains('year')) {
        packageColor = const Color(0xFFDFBA73); // Muted Champagne Gold
      } else if (plan.contains('اسبوع') || plan.contains('week')) {
        packageColor = const Color(0xFF7FB08A); // Soft Sage Green
      }
    }

    String planDisplayName = 'PRO';
    if (_subscriptionPlan != null) {
      final planLower = _subscriptionPlan!.toLowerCase();
      if (planLower.contains('شهري') || planLower.contains('month')) {
        planDisplayName = 'شهري';
      } else if (planLower.contains('سنوي') || planLower.contains('year')) {
        planDisplayName = 'سنوي';
      } else if (planLower.contains('اسبوع') || planLower.contains('week')) {
        planDisplayName = 'أسبوعي';
      } else {
        planDisplayName = 'PRO'; // اسم مختصر وأنيق بدلًا من الأسماء الطويلة
      }
    }

    actions.add(
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
                  ? 10.0
                  : 8.0,
          vertical: 4.0,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()));
          },
          child: Hero(
            tag: 'profile_avatar',
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isSubscribed
                          ? [packageColor, packageColor.withValues(alpha: 0.6)]
                          : [Colors.grey.shade700, Colors.grey.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: (!kIsWeb &&
                            defaultTargetPlatform == TargetPlatform.windows)
                        ? 24
                        : 19.5,
                    backgroundColor: const Color(0xFF121212),
                    backgroundImage: _userProfileImage != null
                        ? CachedNetworkImageProvider(_userProfileImage!)
                        : null,
                    child: _userProfileImage != null
                        ? null
                        : (_userName != null && _userName!.isNotEmpty
                            ? Text(_userName![0].toUpperCase(),
                                style: TextStyle(
                                    color: _isSubscribed
                                        ? packageColor
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (!kIsWeb &&
                                            defaultTargetPlatform ==
                                                TargetPlatform.windows)
                                        ? 20
                                        : 15))
                            : Icon(Icons.person,
                                color:
                                    _isSubscribed ? packageColor : Colors.white,
                                size: (!kIsWeb &&
                                        defaultTargetPlatform ==
                                            TargetPlatform.windows)
                                    ? 26
                                    : 21)),
                  ),
                ),
                if (_isSubscribed)
                  Positioned(
                    bottom: -5,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: packageColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5))
                          ],
                        ),
                        child: Text(
                          planDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return actions;
  }

  Widget _buildSearchBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withAlpha((0.5 * 255).round())),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث عن قناة...',
                    hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color),
                    prefixIcon: Icon(Icons.search,
                        color: Theme.of(context).colorScheme.secondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    isDense: true,
                  ),
                  onChanged: _filterChannels,
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.white),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.white),
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _isSearchBarVisible = false;
                    _searchController.clear();
                    _filterChannels('');
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lazy tabs: a section is only built once the user opens it, then it stays
    // mounted so switching back is instant and scroll position is preserved.
    // This avoids loading/decoding the images of all five sections at startup —
    // the main source of jank on iOS web.
    _visitedTabs.add(_selectedIndex);
    final List<Widget> sections = List<Widget>.generate(5, (int i) {
      if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
      return RepaintBoundary(child: _buildSectionContent(i));
    });

    if (kIsWeb && _isLoading) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFF7C52D8))));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(AppBar().preferredSize.height),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              icon:
                  const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    final theme = Theme.of(context);
                    final isLight = theme.brightness == Brightness.light;
                    final secondaryColor = theme.colorScheme.secondary;

                    return Directionality(
                      textDirection: TextDirection.rtl,
                      // Cache the sheet's raster so the slide-in animation
                      // doesn't repaint this whole tree every frame.
                      child: RepaintBoundary(
                        child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Drag Handle
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.textTheme.bodyLarge?.color
                                      ?.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Profile Header Card
                              if (_userName != null)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isLight
                                          ? [
                                              Colors.grey.shade100,
                                              Colors.grey.shade200
                                            ]
                                          : [
                                              theme.scaffoldBackgroundColor,
                                              theme.scaffoldBackgroundColor
                                                  .withValues(alpha: 0.6)
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: theme.dividerColor
                                          .withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // User Avatar
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: _isSubscribed
                                                ? [
                                                    const Color(0xFFFFD700),
                                                    const Color(0xFFFFA500)
                                                  ]
                                                : [
                                                    secondaryColor,
                                                    secondaryColor.withValues(
                                                        alpha: 0.6)
                                                  ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: (_isSubscribed
                                                      ? const Color(0xFFFFA500)
                                                      : secondaryColor)
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            )
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            _userName!.isNotEmpty
                                                ? _userName![0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Name and Plan Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _userName ?? 'المستخدم',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Plan tag
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _isSubscribed
                                                    ? Colors.amber
                                                        .withValues(alpha: 0.15)
                                                    : Colors.grey.withValues(
                                                        alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _isSubscribed
                                                        ? Icons.star_rounded
                                                        : Icons
                                                            .star_border_rounded,
                                                    size: 14,
                                                    color: _isSubscribed
                                                        ? Colors.amber.shade700
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _isSubscribed
                                                        ? 'عضوية PRO المميزة'
                                                        : 'باقة مجانية',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _isSubscribed
                                                          ? Colors
                                                              .amber.shade800
                                                          : Colors
                                                              .grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Edit button
                                      Material(
                                        color: Colors.transparent,
                                        child: IconButton(
                                          icon: Icon(Icons.edit_rounded,
                                              color: secondaryColor, size: 22),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _showEditNameDialog();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Premium Promotion Card (Only for non-subscribers)
                              if (!_isSubscribed)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8E2DE2),
                                        Color(0xFF4A00E0)
                                      ], // Deep violet gradient
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4A00E0)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.diamond_rounded,
                                            color: Colors.amber, size: 30),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'ترقية إلى 7esen PRO',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'افتح مميزات حصرية وتجربة أسرع بدون إعلانات',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const SubscriptionScreen()),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.black87,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'اشتراك',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (!_isSubscribed) const SizedBox(height: 20),

                              // Section Title
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'الإعدادات والخيارات',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyLarge?.color
                                        ?.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Options Grid
                              Row(
                                children: [
                                  // Theme Customization Card
                                  Expanded(
                                    child: _buildMenuCard(
                                      context: context,
                                      icon: Icons.color_lens_rounded,
                                      iconColor: secondaryColor,
                                      title: 'تخصيص الألوان',
                                      subtitle: 'تغيير ثيم التطبيق',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const ThemeCustomizationScreen()),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Dark Mode Card
                                  Expanded(
                                    child: _buildDarkModeCard(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Notifications Card
                                  Expanded(
                                    child: _buildMenuCard(
                                      context: context,
                                      icon: Icons.notifications_active_rounded,
                                      iconColor: Colors.blue.shade600,
                                      title: 'التنبيهات',
                                      subtitle: 'إعدادات الإشعارات',
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Telegram Card
                                  Expanded(
                                    child: _buildMenuCard(
                                      context: context,
                                      icon: FontAwesomeIcons.telegram,
                                      iconColor: const Color(0xFF229ED9),
                                      title: 'تيليجرام',
                                      subtitle: 'مجتمع القناة الرسمي',
                                      onTap: () async {
                                        Navigator.pop(context);
                                        final Uri telegramUri =
                                            Uri.parse('https://t.me/tv_7esen');
                                        try {
                                          if (await canLaunchUrl(telegramUri)) {
                                            await launchUrl(telegramUri,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          } else if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'لا يمكن فتح رابط التحديث.')));
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'حدث خطأ عند فتح الرابط.')));
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Search Card
                                  Expanded(
                                    child: _buildMenuCard(
                                      context: context,
                                      icon: Icons.search_rounded,
                                      iconColor: Colors.teal.shade600,
                                      title: 'البحث السريع',
                                      subtitle: 'ابحث عن القنوات والمباريات',
                                      onTap: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          _isSearchBarVisible = true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Privacy Policy Card
                                  Expanded(
                                    child: _buildMenuCard(
                                      context: context,
                                      icon: Icons.privacy_tip_rounded,
                                      iconColor: Colors.blueGrey.shade600,
                                      title: 'سياسة الخصوصية',
                                      subtitle: 'شروط الاستخدام والأمان',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  PrivacyPolicyPage()),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              if (_isSubscribed) ...[
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade700
                                            .withValues(alpha: 0.1),
                                        Colors.orange.shade700
                                            .withValues(alpha: 0.1)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.amber.shade500
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.workspace_premium_rounded,
                                          color: Colors.amber.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'تستمتع بمميزات 7esen PRO ✨',
                                          style: TextStyle(
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      ),
                    );
                  },
                );
              },
            ),
            title: Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _userName != null
                        ? Builder(builder: (context) {
                            // Long names overflow the bar — greet by first name only.
                            final String firstName = _userName!
                                .trim()
                                .split(RegExp(r'\s+'))
                                .first;
                            return RichText(
                              // Anchor the greeting next to the menu (left edge).
                              textAlign: TextAlign.left,
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                children: [
                                  const TextSpan(text: 'أهلاً بك '),
                                  TextSpan(
                                    text: firstName,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB388FF),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            actions: _buildAppBarActions(),
          ),
        ),
      ),
      body: _isSearchBarVisible
          ? _buildSearchBar()
          : Builder(
              builder: (context) {
                if (_isLoading && channels.isEmpty) {
                  return _buildShimmerPlaceholder();
                } else if (_hasError) {
                  return _buildGeneralErrorWidget();
                } else {
                  return RefreshIndicator(
                    color: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Theme.of(context).cardColor,
                    onRefresh: () => _refreshSection(_selectedIndex),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: sections,
                      ),
                    ),
                  );
                }
              },
            ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        color: _isDarkMode ? Colors.black : const Color(0xFF7C52D8),
        buttonBackgroundColor: Theme.of(context).cardColor,
        animationDuration: const Duration(milliseconds: 180),
        animationCurve: Curves.decelerate,
        items: [
          _buildNavItem(0, Icons.tv, 'قنوات'),
          _buildNavItem(1, 'assets/replay.png', 'أخبار'),
          _buildNavItem(2, 'assets/goal.png', 'أهداف'),
          _buildNavItem(3, 'assets/table.png', 'مباريات'),
          _buildNavItem(4, Icons.video_library_rounded, 'ملخصات'),
        ],
        index: _selectedIndex,
        onTap: (index) {
          if (!mounted) return;
          setState(() {
            _selectedIndex = index;
            _visitedTabs.add(index);
          });
          SharedPreferences.getInstance().then((prefs) {
            prefs.setInt('last_selected_index', index);
          });
        },
        height: 65,
      ),
    );
  }

  Widget _buildNavItem(int index, dynamic iconDataOrPath, String label) {
    final bool isSelected = _selectedIndex == index;
    final Color activeColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Theme.of(context).primaryColor;
    final Color inactiveColor = Colors.white.withValues(alpha: 0.7);
    final Color itemColor = isSelected ? activeColor : inactiveColor;

    Widget iconWidget;
    if (iconDataOrPath is IconData) {
      iconWidget =
          Icon(iconDataOrPath, size: isSelected ? 28 : 26, color: itemColor);
    } else {
      iconWidget = Image.asset(
        iconDataOrPath as String,
        width: isSelected ? 28 : 26,
        height: isSelected ? 28 : 26,
        color: itemColor,
      );
    }

    return SizedBox(
      height: 46,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 2),
          AnimatedOpacity(
            opacity: isSelected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 20),
          Text(
            _lastError.isNotEmpty
                ? _lastError
                : 'حدث خطأ أثناء تحميل البيانات.',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.white,
                fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            'الرجاء التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color ??
                    Colors.white70,
                fontSize: 14),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _retryLoadingData,
            icon: const Icon(Icons.replay),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.red[400], size: 60),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0:
        if (_channelsHasError) {
          return _buildSectionErrorWidget(
              'فشل تحميل القنوات. الرجاء المحاولة مرة أخرى.', _retryChannels);
        }
        return Column(
          children: [
            _buildSubscriptionBanner(),
            Expanded(
              child: ChannelsSection(
                channelCategories: _filteredChannels,
                openVideo: openVideo,
              ),
            ),
          ],
        );
      case 1:
        if (_newsHasError) {
          return _buildSectionErrorWidget(
              'فشل تحميل الأخبار. الرجاء المحاولة مرة أخرى.', _retryNews);
        }
        return NewsSection(
            newsArticles: news, openVideo: openVideo);
      case 2:
        if (_goalsHasError) {
          return _buildSectionErrorWidget(
              'فشل تحميل الأهداف. الرجاء المحاولة مرة أخرى.', _retryGoals);
        }
        return GoalsSection(
            goalsArticles: goals,
            openVideo: openVideo,
            userName: _userName);
      case 3:
        if (_matchesHasError) {
          return _buildSectionErrorWidget(
              'فشل تحميل المباريات. الرجاء المحاولة مرة أخرى.', _retryMatches);
        }
        return MatchesSection(
            matches: matches, openVideo: openVideo);
      case 4:
        if (_highlightsHasError) {
          return _buildSectionErrorWidget(
              'فشل تحميل الملخصات. الرجاء المحاولة مرة أخرى.',
              _retryHighlights);
        }
        return HighlightsSection(
            highlights: highlights, openVideo: openVideo);
      default:
        return const Center(child: Text('قسم غير معروف'));
    }
  }

  Widget _buildSubscriptionBanner() {
    return const SizedBox.shrink();
  }

  Widget _buildShimmerPlaceholder() {
    final bool isWideScreen = MediaQuery.of(context).size.width > 600;

    // Grid of Category Boxes
    if (_selectedIndex == 0) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 1500 : 900),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isWideScreen ? 24 : 16,
              vertical: 20,
            ),
            gridDelegate: isWideScreen
                ? const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 500,
                    mainAxisExtent: 160,
                    crossAxisSpacing: 25,
                    mainAxisSpacing: 25,
                  )
                : const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisExtent: 90,
                    mainAxisSpacing: 10,
                  ),
            itemCount: 8,
            itemBuilder: (context, index) {
              return const ShimmerLoading(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.all(Radius.circular(24.0)),
              );
            },
          ),
        ),
      );
    }

    // List for news, goals, matches, highlights
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ShimmerLoading(
            width: double.infinity,
            height: _selectedIndex == 3 ? 140 : 180,
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
          ),
        );
      },
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required dynamic icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.grey.shade50
            : theme.cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: icon is IconData
                      ? Icon(icon, color: iconColor, size: 24)
                      : FaIcon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDarkModeCard(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.grey.shade50
            : theme.cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isDarkMode,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      widget.onThemeChanged(value);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'المظهر المظلم',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isDarkMode ? 'مفعل الآن' : 'غير مفعل',
              style: TextStyle(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
