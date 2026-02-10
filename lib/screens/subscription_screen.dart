import 'package:flutter/material.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/services/currency_service.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/payment_screen.dart';
// cloud_firestore import removed (not needed, prevents Web crash)
import 'dart:ui'; // For formatting

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<dynamic> _packages = [];
  bool _isLoading = true;
  bool _isSubscribed = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    final authService = AuthService();
    final data = await authService.getUserData();
    if (mounted) {
      setState(() {
        _userData = data;
        _isSubscribed = data != null && data['isSubscribed'] == true;
      });
    }
  }

  Future<void> _fetchPackages() async {
    try {
      final packages = await ApiService.fetchPackages();
      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching packages: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Deep black background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('خطط الاشتراك',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Colors.purpleAccent))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "اختر الباقة المناسبة لك",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "استمتع بمشاهدة غير محدودة وجهودة عالية",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 30),

                        // Remaining Days Header (If Subscribed)
                        if (_isSubscribed &&
                            _userData != null &&
                            (_userData!['expiryDate'] != null ||
                                _userData!['subscriptionExpiry'] != null)) ...[
                          Builder(builder: (context) {
                            final dynamic expiryStamp =
                                _userData!['expiryDate'] ??
                                    _userData!['subscriptionExpiry'];
                            DateTime? expiry;

                            if (expiryStamp is DateTime) {
                              expiry = expiryStamp;
                            } else if (expiryStamp is String) {
                              expiry = DateTime.tryParse(expiryStamp);
                            }

                            if (expiry == null) return const SizedBox.shrink();

                            final remaining =
                                expiry.difference(DateTime.now()).inDays;
                            final daysText =
                                remaining > 0 ? "$remaining يوم" : "منتهي";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.blueAccent),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.timer,
                                      color: Colors.blueAccent),
                                  const SizedBox(width: 10),
                                  Text(
                                    "المتبقي في اشتراكك: $daysText",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        if (_packages.isEmpty)
                          const Center(
                              child: Text("لا توجد باقات متاحة حالياً",
                                  style: TextStyle(color: Colors.white54)))
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _packages.map((pkg) {
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  child: _buildModernPackageCard(pkg),
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 20),
                        // Trust Badge / Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.security, color: Colors.green, size: 16),
                            SizedBox(width: 5),
                            Text("دفع آمن 100% • تفعيل فوري",
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getDurationString(dynamic days) {
    int d = int.tryParse(days.toString()) ?? 30;
    if (d == 30) return "شهر";
    if (d == 60) return "شهرين";
    if (d == 90) return "3 شهور";
    if (d == 180) return "6 شهور";
    if (d == 365 || d == 360) return "سنة";
    return "$d يوم";
  }

  Widget _buildModernPackageCard(dynamic pkg) {
    // Logic: Define variables first
    final salePrice = pkg['sale_price'];

    // Check if discount exists and is valid (not 0, not null)
    bool hasDiscount = salePrice != null &&
        salePrice.toString() != 'null' &&
        salePrice.toString() != '0';

    // Logic: Calculate Discount Percentage
    final double originalPrice =
        num.tryParse(pkg['price'].toString())?.toDouble() ?? 0.0;
    final double salePriceVal =
        num.tryParse(salePrice.toString())?.toDouble() ?? originalPrice;

    double discountPercent = 0.0;
    if (originalPrice > 0 && salePriceVal < originalPrice) {
      discountPercent = ((originalPrice - salePriceVal) / originalPrice) * 100;
    }

    // Determine Theme Color based on Discount Strength
    // Strong Discount (> 25%): Amber (Gold)
    // Weak/Normal Discount: PurpleAccent
    final bool isStrongOffer = discountPercent > 25;
    final Color themeColor = isStrongOffer ? Colors.amber : Colors.purpleAccent;

    return Container(
      margin: const EdgeInsets.only(
          bottom: 20, top: 10), // Added top margin for badge space
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: hasDiscount
            ? LinearGradient(
                colors: isStrongOffer
                    ? [
                        const Color(0xFF2E0249),
                        const Color(0xFF570A57)
                      ] // Deep Purple/Gold mix
                    : [
                        const Color(0xFF1A1A1A),
                        const Color(0xFF2D2D2D)
                      ], // Darker for weak
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: hasDiscount ? themeColor : Colors.white10,
          width: hasDiscount ? 2 : 1,
        ),
        boxShadow: hasDiscount
            ? [
                BoxShadow(
                  color: themeColor.withValues(
                      alpha: isStrongOffer ? 0.3 : 0.15), // Reduced opacity
                  blurRadius: 15, // Reduced blur
                  spreadRadius: 1, // Reduced spread
                  offset: const Offset(0, 0),
                )
              ]
            : [],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hasDiscount)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: themeColor.withValues(
                              alpha: 0.3), // Reduced badge shadow
                          blurRadius: 8)
                    ],
                  ),
                  child: Text(
                    isStrongOffer ? "عرض قوي 🔥" : "خصم خاص ✨",
                    style: TextStyle(
                        color: isStrongOffer ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pkg['name'] ?? 'باقة',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasDiscount
                            ? (isStrongOffer ? Icons.star : Icons.local_offer)
                            : Icons.check,
                        color: hasDiscount ? themeColor : Colors.white70,
                        size: 20,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                if (pkg['description'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      pkg['description'],
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 15),
                if (pkg['sale_price'] != null &&
                    pkg['sale_price'].toString() != 'null' &&
                    pkg['sale_price'].toString() != '0')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CurrencyService.format(pkg['price'] ?? 0),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.redAccent,
                        ),
                      ),
                      RichText(
                        textDirection: TextDirection.rtl,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  "${_getDurationString(pkg['duration_days'])} / ",
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  height: 1.5, // Align baseline
                                  fontWeight: FontWeight.w500),
                            ),
                            TextSpan(
                              text: CurrencyService.format(pkg['sale_price']),
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 32,
                                  fontFamily:
                                      'Roboto', // Enforce font for numbers
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  RichText(
                    textDirection: TextDirection.rtl,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text:
                              "${_getDurationString(pkg['duration_days'])} / ",
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              height: 1.5, // Align baseline
                              fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: CurrencyService.format(pkg['price'] ?? 0),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 10),
                // Features from API
                if (pkg['features'] != null &&
                    (pkg['features'] as List).isNotEmpty)
                  ...(pkg['features'] as List)
                      .map((f) => _buildBulletPoint(f.toString())),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(package: pkg),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10, // Unified Color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isSubscribed ? 'إضافة الباقة' : 'اشتراك الآن',
                      style: const TextStyle(
                        color: Colors.white, // Unified Text Color
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.greenAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
