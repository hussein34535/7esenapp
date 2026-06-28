import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:hesen/services/currency_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String packageName;
  final double price;
  final int durationDays;
  final DateTime? expiryDate;

  const PaymentSuccessScreen({
    super.key,
    required this.packageName,
    required this.price,
    this.durationDays = 30,
    this.expiryDate,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _cardSlideAnimation;

  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Main layout animations controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Springy scale animation for the checkmark
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Fade animation for text elements
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    // Slide and fade up animation for the details card
    _cardSlideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Confetti physics controller
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        _updateParticles();
      });

    // Start animations
    _mainController.forward();
    
    // Delay confetti slightly for maximum impact when checkmark pops
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _initializeConfetti();
        _confettiController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _initializeConfetti() {
    final colors = [
      Colors.purpleAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.amberAccent,
      Colors.pinkAccent,
      Colors.deepPurpleAccent,
    ];

    // Create 70 particles blasting outward from the center-top
    for (int i = 0; i < 75; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = _random.nextDouble() * 8 + 3;
      _particles.add(
        ConfettiParticle(
          x: _random.nextDouble() * 400 + 50, // spread across width
          y: -20 - _random.nextDouble() * 100, // start above screen
          vx: cos(angle) * speed * 0.5,
          vy: _random.nextDouble() * 5 + 3, // downward speed
          size: _random.nextDouble() * 8 + 6,
          color: colors[_random.nextInt(colors.length)],
          rotation: _random.nextDouble() * pi,
          rotationSpeed: (_random.nextDouble() * 0.1 - 0.05) * 2,
          swayOffset: _random.nextDouble() * pi * 2,
          swaySpeed: _random.nextDouble() * 0.05 + 0.02,
        ),
      );
    }
  }

  void _updateParticles() {
    setState(() {
      for (final p in _particles) {
        // Gravity
        p.vy += 0.08;
        // Friction
        p.vx *= 0.99;
        
        // Position update
        p.x += p.vx;
        p.y += p.vy;
        
        // Sway / wind simulation
        p.x += sin(p.y * 0.02 + p.swayOffset) * 0.6;
        
        // Rotation
        p.rotation += p.rotationSpeed;

        // Reset particle if it goes below screen (to keep some falling action)
        if (p.y > MediaQuery.of(context).size.height + 20) {
          p.y = -20;
          p.x = _random.nextDouble() * MediaQuery.of(context).size.width;
          p.vy = _random.nextDouble() * 4 + 2;
          p.vx = _random.nextDouble() * 2 - 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime expiry = widget.expiryDate ??
        DateTime.now().add(Duration(days: widget.durationDays));
    final String formattedExpiry =
        intl.DateFormat('yyyy-MM-dd').format(expiry);

    return Scaffold(
      backgroundColor: const Color(0xFF07070A), // Premium dark theme background
      body: Stack(
        children: [
          // Background Glows (Radial Gradients)
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.15),
                    blurRadius: 120,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.12),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Custom Confetti Celebration Overlay
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: ConfettiPainter(_particles),
            ),
          ),

          // Main Content
          SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    
                    // 1. Springy scaling success checkmark
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.greenAccent,
                              Colors.teal.shade400,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          // Internal drawing path animation
                          child: AnimatedBuilder(
                            animation: _mainController,
                            builder: (context, child) {
                              // We draw the checkmark progress between 0.3 and 0.8 of the controller
                              double progress = 0.0;
                              if (_mainController.value > 0.3) {
                                progress = (_mainController.value - 0.3) / 0.4;
                                if (progress > 1.0) progress = 1.0;
                              }
                              return CustomPaint(
                                size: const Size(60, 60),
                                painter: CheckmarkPainter(progress: progress),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 2. Animated Congratulations Texts
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const Text(
                            "تم الدفع بنجاح! 🎉",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "تم تفعيل اشتراكك وتأكيده بنجاح. استمتع الآن بالمشاهدة الحصرية بدون توقف!",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),

                    // 3. Glassmorphic Subscription Details Card
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _cardSlideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "تفاصيل الاشتراك",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 15),
                            _buildDetailRow(
                              "الباقة المختارة",
                              widget.packageName,
                              textColor: Colors.white,
                              valueColor: Colors.purpleAccent,
                              isBold: true,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              "القيمة المدفوعة",
                              CurrencyService.format(widget.price),
                              valueColor: Colors.amberAccent,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              "مدة الاشتراك",
                              widget.durationDays == 30
                                  ? "شهر كامل (30 يوم)"
                                  : widget.durationDays == 365
                                      ? "سنة كاملة (12 شهر)"
                                      : "${widget.durationDays} يوم",
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              "تاريخ الانتهاء",
                              formattedExpiry,
                              valueColor: Colors.purpleAccent.shade100,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              "حالة الدفع",
                              "مكتملة ومؤكدة",
                              valueColor: Colors.greenAccent,
                              icon: Icons.verified_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 45),

                    // 4. Glowing Start Watching Button
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            // Pop payment screens to return to home/main application
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  color: Colors.white, size: 24),
                              SizedBox(width: 10),
                              Text(
                                "ابدأ المشاهدة الآن",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color textColor = Colors.white54,
    Color valueColor = Colors.white,
    bool isBold = false,
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: textColor, fontSize: 13),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: valueColor, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Custom Painter for checkmark drawing path
class CheckmarkPainter extends CustomPainter {
  final double progress;

  CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Coordinates relative to the canvas size
    final start = Offset(size.width * 0.22, size.height * 0.48);
    final bend = Offset(size.width * 0.45, size.height * 0.69);
    final end = Offset(size.width * 0.78, size.height * 0.32);

    // Checkmark is split into two sections:
    // Section 1: left to middle bend (approx 35% of total movement)
    // Section 2: middle bend to right top (approx 65% of total movement)
    if (progress > 0) {
      path.moveTo(start.dx, start.dy);
      
      if (progress <= 0.35) {
        final t = progress / 0.35;
        path.lineTo(
          start.dx + (bend.dx - start.dx) * t,
          start.dy + (bend.dy - start.dy) * t,
        );
      } else {
        path.lineTo(bend.dx, bend.dy);
        final t = (progress - 0.35) / 0.65;
        path.lineTo(
          bend.dx + (end.dx - bend.dx) * t,
          bend.dy + (end.dy - bend.dy) * t,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Confetti Particle Physics and Data Model
class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;
  double swayOffset;
  double swaySpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.swayOffset,
    required this.swaySpeed,
  });
}

// Custom Painter to draw multiple celebration particles
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      // Mix of rectangular ribbons and circular dots
      if (p.size.toInt() % 2 == 0) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.6,
            height: p.size * 0.8,
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}
