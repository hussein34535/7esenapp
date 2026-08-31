import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hesen/screens/login_screen.dart';
import 'package:hesen/screens/home_page.dart';
import 'package:hesen/navigation.dart';
import 'package:hesen/theme_customization_screen.dart';
import 'package:hesen/main.dart' show homeKey;

/// Cinematic brand intro â€” Netflix/Apple-TV style.
///
/// Sequence (~2.7s):
///   1. Pure black
///   2. Raw logo (no box, no halo) fades in + gently scales up
///   3. A single white light sweep glides across it
///   4. Cinematic push-in while fading to black â†’ HomePage
class AppIntroScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final void Function(bool) onThemeChanged;

  const AppIntroScreen({
    super.key,
    required this.themeProvider,
    required this.onThemeChanged,
  });

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _sweep;
  late final Animation<double> _exitZoom;
  late final Animation<double> _exitFade;
  bool _startScheduled = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.10, 0.42, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.10, 0.52, curve: Curves.easeOutCubic)),
    );
    // Drives the light-sweep band horizontally: -2.6 â†’ 2.6 crosses the logo once.
    _sweep = Tween<double>(begin: -2.6, end: 2.6).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.34, 0.64, curve: Curves.easeInOutCubic)),
    );
    _exitZoom = Tween<double>(begin: 1.0, end: 1.09).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.78, 1.0, curve: Curves.easeInCubic)),
    );
    _exitFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.83, 1.0, curve: Curves.easeIn)),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // WEB LOGIN GATE: on web, opening the app requires an account.
        final bool needsLogin = kIsWeb &&
            (FirebaseAuth.instance.currentUser == null);
        navigatorKey.currentState?.pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              if (needsLogin) {
                return const LoginScreen();
              }
              return HomePage(
                key: homeKey,
                onThemeChanged: widget.onThemeChanged,
              );
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 450),
          ),
        );
      }
    });
    // NOTE: the animation is started from didChangeDependencies() once the logo
    // is decoded â€” Flutter animations are time-based, so starting before the
    // image/engine is ready made the intro visibly jump to its final frames.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startScheduled) return;
    _startScheduled = true;

    // Decode the logo first, then play. A short timeout guarantees the intro
    // always starts even if the asset is slow or missing.
    bool started = false;
    void startOnce() {
      if (started || !mounted) return;
      started = true;
      // Begin on the next frame so the first paint is already on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward();
      });
    }

    precacheImage(const AssetImage('assets/icon/logo.png'), context)
        .then((_) => startOnce())
        .catchError((_) => startOnce());
    Future.delayed(const Duration(milliseconds: 700), startOnce);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double x = _sweep.value;

        return ColoredBox(
          color: Colors.black,
          child: ClipRect(
            child: Transform.scale(
              scale: _exitZoom.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: ShaderMask(
                          blendMode: BlendMode.srcATop,
                          // Soft 5-stop falloff â†’ a smooth metallic shine,
                          // not a hard diagonal stripe.
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment(x - 0.55, -1.4),
                            end: Alignment(x + 0.55, 1.4),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.85),
                              Colors.white.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.38, 0.5, 0.62, 1.0],
                          ).createShader(bounds),
                          child: Container(
                            width: 158,
                            height: 158,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              // Faint neutral rim so the rounded shape reads
                              // on pure black â€” no purple halo.
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.white.withValues(alpha: 0.05),
                                  blurRadius: 44,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(33),
                              child: Image.asset(
                                'assets/icon/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF12101A),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.tv_rounded,
                                    size: 72,
                                    color: Color(0xFFB388FF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Cinematic fade-out overlay
                  ColoredBox(
                    color: Colors.black.withValues(alpha: _exitFade.value),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

