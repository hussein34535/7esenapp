import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hesen/navigation.dart';
import 'package:hesen/web_utils.dart'
    if (dart.library.io) 'package:hesen/web_utils_stub.dart';
import 'package:hesen/firebase_api.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/services/data_processor.dart';
import 'package:hesen/services/resend_service.dart';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/models/highlight_model.dart';
import 'package:hesen/widgets.dart';
import 'package:hesen/theme_customization_screen.dart';
import 'package:hesen/telegram_dialog.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:hesen/screens/subscription_screen.dart';
import 'package:hesen/screens/profile_screen.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:hesen/video_player_screen.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

part 'package:hesen/mixins/home_page_data_mixin.dart';
part 'package:hesen/mixins/home_page_ui_mixin.dart';

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const HomePage({super.key, required this.onThemeChanged});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver, HomePageDataMixin, HomePageUIMixin {
  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    _startInitializationSequence();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _userSubscription?.cancel();
    _windowsStatusTimer?.cancel();
    super.dispose();
  }
}
