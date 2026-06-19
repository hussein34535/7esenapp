part of 'package:hesen/screens/home_page.dart';

mixin HomePageUIMixin on HomePageDataMixin {
  void openVideo(BuildContext context, String? initialUrl, List<Map<String, dynamic>> streamLinks, String sourceSection, {int? contentId, bool isPremium = false}) {
    if (isPremium) {
      String apiType = sourceSection;
      if (sourceSection == 'channels') apiType = 'channel';
      if (sourceSection == 'goals') apiType = 'goal';
      if (sourceSection == 'news') apiType = 'news';
      if (sourceSection == 'matches') apiType = 'match';
      _navigateToVideoPlayer(context, initialUrl ?? '', streamLinks, isLocked: true, contentId: contentId, category: apiType);
      return;
    }
    _navigateToVideoPlayer(context, initialUrl ?? '', streamLinks);
  }

  Future<void> _navigateToVideoPlayer(BuildContext context, String initialUrl, List<Map<String, dynamic>> streamLinks, {bool isLocked = false, int? contentId, String? category}) async {
    final videoScreen = VideoPlayerScreen(
      initialUrl: initialUrl, streamLinks: streamLinks, isLocked: isLocked, contentId: contentId, category: category,
    );
    if (kIsWeb) {
      await navigatorKey.currentState?.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => videoScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } else {
      await navigatorKey.currentState?.push(MaterialPageRoute(builder: (context) => videoScreen));
    }
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];
    if (!_isSubscribed) {
      actions.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: ElevatedButton.icon(
              onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SubscriptionScreen())); },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.workspace_premium_rounded, color: Colors.black87, size: 18),
              label: const Text('اشترك الآن', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
            ),
          ),
        ),
      );
    }

    Color packageColor = Colors.amber.shade400;
    if (_subscriptionPlan != null) {
      final plan = _subscriptionPlan!.toLowerCase();
      if (plan.contains('شهري') || plan.contains('month')) { packageColor = Colors.blue.shade400; }
      else if (plan.contains('سنوي') || plan.contains('year')) { packageColor = Colors.amber.shade400; }
      else if (plan.contains('اسبوع') || plan.contains('week')) { packageColor = Colors.green.shade400; }
    }

    actions.add(
      Padding(
        padding: EdgeInsets.only(left: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ? 10.0 : 8.0, right: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ? 10.0 : 8.0, bottom: 12.0),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () { Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProfileScreen())); },
          child: Hero(
            tag: 'profile_avatar',
            child: Stack(
              alignment: Alignment.center, clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isSubscribed ? [packageColor, packageColor.withValues(alpha: 0.6)] : [Colors.grey.shade700, Colors.grey.shade900],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28, backgroundColor: const Color(0xFF121212),
                    backgroundImage: _userProfileImage != null ? CachedNetworkImageProvider(_userProfileImage!) : null,
                    child: _userProfileImage != null ? null
                        : (_userName != null && _userName!.isNotEmpty
                            ? Text(_userName![0].toUpperCase(), style: TextStyle(color: _isSubscribed ? packageColor : Colors.white, fontWeight: FontWeight.bold, fontSize: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ? 18 : 12))
                            : Icon(Icons.person, color: _isSubscribed ? packageColor : Colors.white, size: (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ? 24 : 16)),
                  ),
                ),
                if (_isSubscribed && _subscriptionExpiryDays != null)
                  Positioned(
                    bottom: -10, left: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      constraints: const BoxConstraints(minWidth: 24), alignment: Alignment.center,
                      child: Text('${_subscriptionExpiryDays!.replaceAll(RegExp(r'[^0-9]'), '')} يوم', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, height: 1.0)),
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
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withAlpha((0.5 * 255).round())),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث عن قناة...',
                    hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.secondary),
                    border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), isDense: true,
                  ),
                  onChanged: _filterChannels,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white),
                onPressed: () {
                  if (!mounted) return;
                  setState(() { _isSearchBarVisible = false; _searchController.clear(); _filterChannels(''); });
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
    if (kIsWeb && _isLoading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFF7C52D8))));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(AppBar().preferredSize.height),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
            color: Theme.of(context).appBarTheme.backgroundColor,
          ),
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
              onPressed: () {
                showModalBottomSheet(
                  context: context, backgroundColor: Theme.of(context).cardColor,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  builder: (BuildContext context) {
                    return Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            if (_userName != null)
                              ListTile(
                                leading: Icon(Icons.person, color: Theme.of(context).colorScheme.secondary, size: 28),
                                title: Text(_userName ?? 'المستخدم', style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () { Navigator.pop(context); _showEditNameDialog(); }),
                              ),
                            const Divider(),
                            ListTile(
                              leading: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.amber),
                              title: const Text('وضع التشغيل'),
                              trailing: Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value: _isDarkMode, activeThumbColor: Colors.purple,
                                  onChanged: (value) { setState(() { _isDarkMode = value; }); widget.onThemeChanged(value); Navigator.pop(context); },
                                ),
                              ),
                            ),
                            ListTile(leading: const Icon(Icons.notifications_active_outlined, color: Colors.blue), title: const Text('التنبيهات'), onTap: () { Navigator.pop(context); }),
                            ListTile(
                              leading: const Icon(Icons.diamond, color: Colors.amber),
                              title: const Text('الاشتراك المميز', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())); },
                            ),
                            ListTile(
                              leading: Icon(Icons.color_lens, color: Theme.of(context).colorScheme.secondary),
                              title: Text('تخصيص الألوان', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)),
                              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeCustomizationScreen())); },
                            ),
                            ListTile(
                              leading: FaIcon(FontAwesomeIcons.telegram, color: Theme.of(context).colorScheme.secondary),
                              title: Text('Telegram', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)),
                              onTap: () async {
                                Navigator.pop(context);
                                final Uri telegramUri = Uri.parse('https://t.me/tv_7esen');
                                try {
                                  if (await canLaunchUrl(telegramUri)) { await launchUrl(telegramUri, mode: LaunchMode.externalApplication); }
                                  else if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح رابط التحديث.'))); }
                                } catch (e) { if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ عند فتح الرابط.'))); } }
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.search, color: Theme.of(context).colorScheme.secondary),
                              title: Text('البحث', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)),
                              onTap: () { Navigator.pop(context); setState(() { _isSearchBarVisible = true; }); },
                            ),
                            ListTile(
                              leading: Icon(Icons.privacy_tip_rounded, color: Theme.of(context).colorScheme.secondary),
                              title: Text('سياسة الخصوصية', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)),
                              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyPolicyPage())); },
                            ),
                          ],
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
                        ? RichText(
                            textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                            text: TextSpan(
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
                              children: [
                                const TextSpan(text: 'أهلاً بك '),
                                TextSpan(
                                  text: _userName,
                                  style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold,
                                    foreground: _isDarkMode
                                        ? (Paint()..shader = LinearGradient(
                                            colors: [Colors.blue.shade800, Colors.deepPurple.shade700, Colors.blue.shade500],
                                            begin: Alignment.centerLeft, end: Alignment.centerRight,
                                          ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0))
                                          )
                                        : null,
                                    color: _isDarkMode ? null : const Color(0xFFF8F8F8),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            actions: _buildAppBarActions(),
          ),
        ),
      ),
      body: _isSearchBarVisible ? _buildSearchBar()
          : Builder(
              builder: (context) {
                if (_isLoading && channels.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
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
                        children: [
                          _buildSectionContent(0),
                          _buildSectionContent(1),
                          _buildSectionContent(2),
                          _buildSectionContent(3),
                          _buildSectionContent(4),
                        ],
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
        animationDuration: const Duration(milliseconds: 300),
        items: [
          const Icon(Icons.tv, size: 30, color: Colors.white),
          Image.asset('assets/replay.png', width: 30, height: 30, color: Colors.white),
          Image.asset('assets/goal.png', width: 30, height: 30, color: Colors.white),
          Image.asset('assets/table.png', width: 30, height: 30, color: Colors.white),
          const Icon(Icons.video_library_rounded, size: 30, color: Colors.white),
        ],
        index: _selectedIndex,
        onTap: (index) { if (!mounted) return; setState(() { _selectedIndex = index; }); },
        height: 60,
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
            _lastError.isNotEmpty ? _lastError : 'حدث خطأ أثناء تحميل البيانات.',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text('الرجاء التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.', textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _retryLoadingData,
            icon: const Icon(Icons.replay),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), textStyle: const TextStyle(fontSize: 16),
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
              message, textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0,
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
          return _buildSectionErrorWidget('فشل تحميل القنوات. الرجاء المحاولة مرة أخرى.', _retryChannels);
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
          return _buildSectionErrorWidget('فشل تحميل الأخبار. الرجاء المحاولة مرة أخرى.', _retryNews);
        }
        return NewsSection(newsArticles: Future.value(news), openVideo: openVideo);
      case 2:
        if (_goalsHasError) {
          return _buildSectionErrorWidget('فشل تحميل الأهداف. الرجاء المحاولة مرة أخرى.', _retryGoals);
        }
        return GoalsSection(goalsArticles: Future.value(goals), openVideo: openVideo, userName: _userName);
      case 3:
        if (_matchesHasError) {
          return _buildSectionErrorWidget('فشل تحميل المباريات. الرجاء المحاولة مرة أخرى.', _retryMatches);
        }
        return MatchesSection(matches: Future.value(matches), openVideo: openVideo);
      case 4:
        if (_highlightsHasError) {
          return _buildSectionErrorWidget('فشل تحميل الملخصات. الرجاء المحاولة مرة أخرى.', _retryHighlights);
        }
        return HighlightsSection(highlights: Future.value(highlights), openVideo: openVideo);
      default:
        return const Center(child: Text('قسم غير معروف'));
    }
  }

  Widget _buildSubscriptionBanner() {
    final bool isDesktop = (defaultTargetPlatform == TargetPlatform.windows || 
                           defaultTargetPlatform == TargetPlatform.linux || 
                           defaultTargetPlatform == TargetPlatform.macOS) && !kIsWeb;
    final double maxBannerWidth = isDesktop ? 1200 : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBannerWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;

              if (!_isSubscribed) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C52D8), Color(0xFF4A148C), Color(0xFF311B92)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Positioned(right: -30, top: -30, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                          child: Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: isWide ? 3 : 0,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), shape: BoxShape.circle),
                                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 32),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('اشترك في الباقة المميزة لـ حسن TV 👑', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                          const SizedBox(height: 4),
                                          Text('شاهد كافة القنوات، بدون إعلانات، بجودة عالية وبث مستقر!', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontFamily: 'Cairo')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isWide) const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('اشترك الآن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'Cairo')),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black87),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.teal.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 24),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('اشتراكك نشط: ${_subscriptionPlan ?? "الباقة المميزة"} 💎', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                if (_subscriptionExpiryDays != null) ...[
                                  const SizedBox(height: 2),
                                  Text(_subscriptionExpiryDays!, style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                ],
                              ],
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())); },
                          style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                          child: Row(
                            children: [
                              const Text('التفاصيل', style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
