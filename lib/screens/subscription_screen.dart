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
  int _selectedPackageIndex = 0;

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
          // Set default selection to the featured package
          final fIndex = _getFeaturedPackageIndex();
          if (fIndex != -1) {
            _selectedPackageIndex = fIndex;
          }
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

                        // ====== Current Plan Info Card ======
                        if (_isSubscribed && _userData != null) ...[ 
                          Builder(builder: (context) {
                            // --- Plan name ---
                            final String planName =
                                _userData!['subscriptionPlan']?.toString() ??
                                _userData!['planName']?.toString() ??
                                (_userData!['planId'] != null
                                    ? 'باقة Premium (Plan ${_userData!['planId']})'
                                    : 'باقة Premium');

                            // --- Expiry ---
                            final dynamic expiryStamp =
                                _userData!['subscriptionEnd'] ??
                                _userData!['expiryDate'] ??
                                _userData!['subscriptionExpiry'];
                            DateTime? expiry;
                            if (expiryStamp is DateTime) {
                              expiry = expiryStamp;
                            } else if (expiryStamp is String) {
                              expiry = DateTime.tryParse(expiryStamp);
                            }
                            final int remaining = expiry != null
                                ? expiry.difference(DateTime.now()).inDays
                                : -1;
                            final String daysText = remaining > 0
                                ? '$remaining يوم متبقي'
                                : remaining == 0
                                    ? 'ينتهي اليوم'
                                    : 'منتهي';

                            final bool isActive = remaining >= 0;

                            // لو الاشتراك منتهي، مش بنعرض أي بانر
                            if (!isActive) return const SizedBox.shrink();

                            const Color planColor = Colors.green;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.withValues(alpha: 0.15),
                                    Colors.green.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: planColor.withValues(alpha: 0.4),
                                    width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: planColor.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: planColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.workspace_premium_rounded,
                                      color: planColor,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Plan info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'اشتراكك الحالي',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          planName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Days badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: planColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              planColor.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      daysText,
                                      style: TextStyle(
                                        color: planColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
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
                          LayoutBuilder(builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth > 600;
                            final featuredIndex = _getFeaturedPackageIndex();
                            if (isDesktop) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(_packages.length, (index) {
                                  final pkg = _packages[index];
                                  final isFeatured = index == featuredIndex;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      child: _buildModernPackageCard(pkg, isFeatured),
                                    ),
                                  );
                                }),
                              );
                            } else {
                              // Calculate theme for the dynamically selected package button
                              Color selectedButtonColor = Colors.purpleAccent;
                              bool isSelectedStrong = false;
                              if (_packages.isNotEmpty && _selectedPackageIndex < _packages.length) {
                                final selectedPkg = _packages[_selectedPackageIndex];
                                final selectedSalePrice = selectedPkg['sale_price'];
                                final int selectedDiscountMonths = int.tryParse(selectedPkg['discount_months']?.toString() ?? '0') ?? 0;
                                final double selectedOriginalPrice = num.tryParse(selectedPkg['price'].toString())?.toDouble() ?? 0.0;
                                final double selectedSalePriceVal = num.tryParse(selectedSalePrice.toString())?.toDouble() ?? selectedOriginalPrice;
                                double selectedDiscountPercent = 0.0;
                                if (selectedOriginalPrice > 0 && selectedSalePriceVal < selectedOriginalPrice) {
                                  selectedDiscountPercent = ((selectedOriginalPrice - selectedSalePriceVal) / selectedOriginalPrice) * 100;
                                }
                                isSelectedStrong = selectedDiscountPercent > 25 || selectedDiscountMonths > 0;
                                selectedButtonColor = isSelectedStrong ? Colors.amber : Colors.purpleAccent;
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Plan options list (vertical stack of horizontal cards)
                                  ...List.generate(_packages.length, (index) {
                                    final pkg = _packages[index];
                                    final isSelected = index == _selectedPackageIndex;
                                    final isFeatured = index == featuredIndex;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedPackageIndex = index;
                                        });
                                      },
                                      child: _buildPlanOption(pkg, isSelected, isFeatured),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                  
                                  // Premium features list (static, premium looking box)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildPremiumFeature(Icons.hd_rounded, "بث بجودة Full HD & 4K بدون تقطيع"),
                                        const SizedBox(height: 10),
                                        _buildPremiumFeature(Icons.devices_rounded, "تشغيل على جميع الأجهزة (شاشة، هاتف، كمبيوتر)"),
                                        const SizedBox(height: 10),
                                        _buildPremiumFeature(Icons.support_agent_rounded, "دعم فني متواصل على مدار الساعة 24/7"),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Action Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (_packages.isEmpty) return;
                                        final selectedPkg = _packages[_selectedPackageIndex];
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PaymentScreen(package: selectedPkg),
                                          ),
                                        );
                                        if (mounted) _fetchPackages();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: selectedButtonColor,
                                        foregroundColor: isSelectedStrong ? Colors.black : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 5,
                                        shadowColor: selectedButtonColor.withValues(alpha: 0.3),
                                      ),
                                      child: Text(
                                        _isSubscribed ? 'إضافة الباقة المختارة' : 'اشترك الآن في الباقة',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                          }),

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

  int _getFeaturedPackageIndex() {
    if (_packages.isEmpty) return -1;
    int featuredIndex = -1;
    
    // 1. Check for highest discount_months > 0
    int maxDiscountMonths = 0;
    for (int i = 0; i < _packages.length; i++) {
      final dMonths = int.tryParse(_packages[i]['discount_months']?.toString() ?? '0') ?? 0;
      if (dMonths > maxDiscountMonths) {
        maxDiscountMonths = dMonths;
        featuredIndex = i;
      }
    }
    
    // 2. Check for highest discount percentage
    if (featuredIndex == -1) {
      double maxDiscountPercent = 0.0;
      for (int i = 0; i < _packages.length; i++) {
        final double originalPrice = num.tryParse(_packages[i]['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
        final double salePriceVal = num.tryParse(_packages[i]['sale_price']?.toString() ?? '0')?.toDouble() ?? originalPrice;
        if (originalPrice > 0 && salePriceVal < originalPrice) {
          double percent = ((originalPrice - salePriceVal) / originalPrice) * 100;
          if (percent > maxDiscountPercent) {
            maxDiscountPercent = percent;
            featuredIndex = i;
          }
        }
      }
    }
    
    // 3. Fallback to the middle package
    if (featuredIndex == -1) {
      featuredIndex = _packages.length ~/ 2;
    }
    
    return featuredIndex;
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

  Widget _buildModernPackageCard(dynamic pkg, bool isFeatured) {
    // Logic: Define variables first
    final salePrice = pkg['sale_price'];
    final int discountMonths = int.tryParse(pkg['discount_months']?.toString() ?? '0') ?? 0;

    // Check if discount exists and is valid (not 0, not null)
    bool hasDiscount = (salePrice != null &&
        salePrice.toString() != 'null' &&
        salePrice.toString() != '0') || discountMonths > 0;

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
    // Strong Discount (> 25% or has free months): Amber (Gold)
    // Weak/Normal Discount: PurpleAccent
    final bool isStrongOffer = discountPercent > 25 || discountMonths > 0;
    final Color themeColor = isFeatured 
        ? Colors.amberAccent 
        : (isStrongOffer ? Colors.cyanAccent : Colors.white24);

    return Container(
      margin: const EdgeInsets.only(
          bottom: 20, top: 15), // Added top margin for badge space
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isFeatured
            ? const LinearGradient(
                colors: [
                  Color(0xFF2E0249),
                  Color(0xFF190033),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : (hasDiscount
                ? LinearGradient(
                    colors: isStrongOffer
                        ? [
                            const Color(0xFF001A33),
                            const Color(0xFF000D1A)
                          ]
                        : [
                            const Color(0xFF1A1A1A),
                            const Color(0xFF2D2D2D)
                          ],
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
                  )),
        border: Border.all(
          color: isFeatured 
              ? Colors.amberAccent 
              : (hasDiscount ? themeColor : Colors.white10),
          width: isFeatured ? 2.5 : (hasDiscount ? 1.5 : 1),
        ),
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: Colors.amberAccent.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                )
              ]
            : (hasDiscount
                ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.15),
                      blurRadius: 15,
                      spreadRadius: 1,
                      offset: const Offset(0, 0),
                    )
                  ]
                : []),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isFeatured || hasDiscount)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFeatured ? Colors.amber : themeColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: (isFeatured ? Colors.amber : themeColor).withValues(
                              alpha: 0.3),
                          blurRadius: 8)
                    ],
                  ),
                  child: Text(
                    isFeatured
                        ? "الخصم الأكبر 🔥"
                        : (isStrongOffer ? "عرض قوي ⚡" : "خصم خاص ✨"),
                    style: TextStyle(
                        color: (isFeatured || isStrongOffer) ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),
            ),
          if (discountMonths > 0)
            Positioned(
              top: -14,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade700,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.4),
                        blurRadius: 10)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      discountMonths == 1
                          ? "+ شهر مجاناً"
                          : discountMonths == 2
                              ? "+ شهرين مجاناً"
                              : "+ $discountMonths شهور مجاناً",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
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
                    Expanded(
                      child: Text(
                        pkg['name'] ?? 'باقة',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFeatured 
                            ? Icons.star 
                            : (hasDiscount ? Icons.local_offer : Icons.check),
                        color: isFeatured 
                            ? Colors.amberAccent 
                            : (hasDiscount ? themeColor : Colors.white70),
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
                                  height: 1.5,
                                  fontWeight: FontWeight.w500),
                            ),
                            TextSpan(
                              text: CurrencyService.format(pkg['sale_price']),
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 32,
                                  fontFamily: 'Roboto',
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
                              height: 1.5,
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
                  child: Container(
                    decoration: isFeatured
                        ? BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.purpleAccent, Colors.blueAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purpleAccent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          )
                        : null,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentScreen(package: pkg),
                          ),
                        );
                        if (mounted) _fetchPackages();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFeatured ? Colors.transparent : Colors.white10,
                        shadowColor: isFeatured ? Colors.transparent : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isSubscribed ? 'إضافة الباقة' : 'اشتراك الآن',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildPremiumFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.purpleAccent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(dynamic pkg, bool isSelected, bool isFeatured) {
    final salePrice = pkg['sale_price'];
    final int discountMonths = int.tryParse(pkg['discount_months']?.toString() ?? '0') ?? 0;

    bool hasDiscount = (salePrice != null &&
        salePrice.toString() != 'null' &&
        salePrice.toString() != '0') || discountMonths > 0;

    final double originalPrice =
        num.tryParse(pkg['price'].toString())?.toDouble() ?? 0.0;
    final double salePriceVal =
        num.tryParse(salePrice.toString())?.toDouble() ?? originalPrice;

    double discountPercent = 0.0;
    if (originalPrice > 0 && salePriceVal < originalPrice) {
      discountPercent = ((originalPrice - salePriceVal) / originalPrice) * 100;
    }

    final bool isStrongOffer = discountPercent > 25 || discountMonths > 0;
    final Color themeColor = isFeatured 
        ? Colors.amberAccent 
        : (isStrongOffer ? Colors.cyanAccent : Colors.white24);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? themeColor.withValues(alpha: 0.08)
                : (isFeatured ? Colors.purpleAccent.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? themeColor 
                  : (isFeatured ? Colors.amberAccent.withValues(alpha: 0.5) : (isStrongOffer ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08))),
              width: isSelected ? 2.0 : (isFeatured || isStrongOffer ? 1.5 : 1.0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Radio Indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? themeColor : Colors.white30,
                    width: 2.0,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: themeColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Name and Duration
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pkg['name'] ?? 'باقة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getDurationString(pkg['duration_days']),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    if (discountMonths > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.card_giftcard, color: Colors.greenAccent, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              discountMonths == 1
                                  ? "خصم شهر كامل مجاناً"
                                  : discountMonths == 2
                                      ? "خصم شهرين مجاناً"
                                      : "خصم $discountMonths أشهر مجانية",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyService.format(hasDiscount ? salePriceVal : originalPrice),
                    style: TextStyle(
                      color: isSelected ? themeColor : Colors.white,
                      fontSize: 18,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasDiscount)
                    Text(
                      CurrencyService.format(originalPrice),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.redAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        
        // Floating Discount Badge
        if (isFeatured || hasDiscount)
          Positioned(
            top: -3,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isFeatured ? Colors.amber : themeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isFeatured
                    ? (discountMonths > 0 ? "الخصم الأكبر 🔥" : "الأكثر طلباً ⭐")
                    : (isStrongOffer ? "الأكثر توفيراً 🔥" : "خصم %${discountPercent.round()}"),
                style: TextStyle(
                  color: (isFeatured || isStrongOffer) ? Colors.black : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
