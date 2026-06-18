import 'package:flutter/material.dart';
import 'package:hesen/navigation.dart';
import 'package:hesen/screens/home_page.dart';
import 'package:hesen/screens/pwa_install_screen.dart';
import 'package:hesen/notification_page.dart';
import 'package:hesen/theme_customization_screen.dart';
import 'package:hesen/main.dart' show homeKey;
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  final Future<void> initFuture;

  const MyApp({super.key, required this.initFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
            ),
          );
        }
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return MaterialApp(
              title: '7eSen TV',
              debugShowCheckedModeBanner: false,
              themeMode: themeProvider.themeMode,
              theme: ThemeData(
                brightness: Brightness.light,
                primaryColor: themeProvider.getPrimaryColor(false),
                scaffoldBackgroundColor:
                    themeProvider.getScaffoldBackgroundColor(false),
                cardColor: themeProvider.getCardColor(false),
                colorScheme: ColorScheme.light(
                  primary: themeProvider.getPrimaryColor(false),
                  secondary: themeProvider.getSecondaryColor(false),
                  surface: Colors.white,
                  error: Colors.red,
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  onSurface: Colors.black,
                  onError: Colors.white,
                  brightness: Brightness.light,
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: themeProvider.getAppBarBackgroundColor(
                    false,
                  ),
                  foregroundColor: Colors.white,
                  iconTheme: const IconThemeData(color: Colors.white),
                  titleTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                fontFamily: 'Cairo',
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.black),
                  bodyMedium: TextStyle(color: Colors.black),
                  bodySmall: TextStyle(color: Colors.black),
                ),
              ),
              darkTheme: ThemeData(
                fontFamily: 'Cairo',
                brightness: Brightness.dark,
                primaryColor: themeProvider.getPrimaryColor(true),
                scaffoldBackgroundColor:
                    themeProvider.getScaffoldBackgroundColor(true),
                cardColor: themeProvider.getCardColor(true),
                colorScheme: ColorScheme.dark(
                  primary: themeProvider.getPrimaryColor(true),
                  secondary: themeProvider.getSecondaryColor(true),
                  surface: const Color(0xFF1C1C1C),
                  error: Colors.red,
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  onSurface: Colors.white,
                  onError: Colors.white,
                  brightness: Brightness.dark,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  foregroundColor: Colors.white,
                  iconTheme: IconThemeData(color: Colors.white),
                  titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              initialRoute: '/',
              routes: {
                '/pwa_install': (context) => const PwaInstallScreen(),
                '/': (context) => HomePage(
                      key: homeKey,
                      onThemeChanged: (isDarkMode) {
                        themeProvider.setThemeMode(
                          isDarkMode ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                '/Notification_screen': (context) => const NotificationPage(),
              },
              navigatorKey: navigatorKey,
            );
          },
        );
      },
    );
  }
}
