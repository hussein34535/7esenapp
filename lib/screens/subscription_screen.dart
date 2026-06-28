import 'package:flutter/material.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:hesen/widgets/subscription_widgets.dart';
import 'package:hesen/widgets/in_app_notification.dart';
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
  bool _isActivatingTrial = false;

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

                        // ====== Free Trial Banner / Card ======
                        if (!_isSubscribed) ...[
                          if (_userData == null) ...[
                            _buildRegisterForTrialBanner(),
                          ] else if (_userData!['trialUsed'] != true) ...[
                            _buildActivateTrialCard(),
                          ],
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
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List.generate(_packages.length, (index) {
                                    final pkg = _packages[index];
                                    final isFeatured = index == featuredIndex;
                                    
                                    final planIdStr = pkg['id']?.toString();
                                    final userPlanIdStr = _userData?['planId']?.toString();
                                    final userPlanName = _userData?['subscriptionPlan']?.toString() ?? _userData?['planName']?.toString();
                                    final isCurrentPlan = _isSubscribed && (
                                      (userPlanIdStr != null && planIdStr == userPlanIdStr) ||
                                      (userPlanName != null && pkg['name']?.toString().toLowerCase() == userPlanName.toLowerCase())
                                    );

                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5),
                                        child: SubscriptionPackageCard(
                                          pkg: pkg,
                                          isFeatured: isFeatured,
                                          isSubscribed: _isSubscribed,
                                          isCurrentPlan: isCurrentPlan,
                                          onPaymentComplete: _fetchPackages,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            } else {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Cupertino-Style Segmented Control (Apple Selector)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    clipBehavior: Clip.none,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C1C1E), // iOS System Gray 6
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: List.generate(_packages.length, (index) {
                                        final pkg = _packages[index];
                                        final isSelected = index == _selectedPackageIndex;
                                        final String pkgName = (pkg['name'] ?? '').toString();
                                        
                                        return Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedPackageIndex = index;
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(vertical: 9),
                                              clipBehavior: Clip.none,
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFF2C2C2E) : Colors.transparent, // iOS System Gray 4 background
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: isSelected ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.15),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ] : null,
                                              ),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.center,
                                                children: [
                                                  Text(
                                                    pkgName,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.white : Colors.white38, // White text when active, muted when inactive
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  if (_getPackageDiscountPercent(pkg) > 0)
                                                    Positioned(
                                                      top: -14, // Lowered down slightly
                                                      right: -6, // Adjusted position
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // Slightly larger padding
                                                        decoration: BoxDecoration(
                                                          color: Colors.black, // Premium AMOLED black background
                                                          borderRadius: BorderRadius.circular(20), // Oval/Capsule shape like iOS
                                                          border: Border.all(
                                                            color: Colors.white.withValues(alpha: 0.15),
                                                            width: 1.0,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withValues(alpha: 0.3),
                                                              blurRadius: 4,
                                                              offset: const Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          "-${_getPackageDiscountPercent(pkg)}%",
                                                          style: const TextStyle(
                                                            color: Colors.redAccent, // Vibrant red accent for the discount number
                                                            fontSize: 10.5, // Slightly larger font size
                                                            fontWeight: FontWeight.bold,
                                                            height: 1,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Selected Card Details (Apple-style)
                                  Builder(
                                    builder: (context) {
                                      final selectedPkg = _packages[_selectedPackageIndex];
                                      final isFeatured = _selectedPackageIndex == featuredIndex;

                                      final planIdStr = selectedPkg['id']?.toString();
                                      final userPlanIdStr = _userData?['planId']?.toString();
                                      final userPlanName = _userData?['subscriptionPlan']?.toString() ?? _userData?['planName']?.toString();
                                      final isCurrentPlan = _isSubscribed && (
                                        (userPlanIdStr != null && planIdStr == userPlanIdStr) ||
                                        (userPlanName != null && selectedPkg['name']?.toString().toLowerCase() == userPlanName.toLowerCase())
                                      );

                                      return SubscriptionPackageCard(
                                        pkg: selectedPkg,
                                        isFeatured: isFeatured,
                                        isSubscribed: _isSubscribed,
                                        isCurrentPlan: isCurrentPlan,
                                        onPaymentComplete: _fetchPackages,
                                      );
                                    }
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

  int _getPackageDiscountPercent(dynamic pkg) {
    final double originalPrice = num.tryParse(pkg['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
    final double salePriceVal = num.tryParse(pkg['sale_price']?.toString() ?? '0')?.toDouble() ?? originalPrice;
    if (originalPrice > 0 && salePriceVal < originalPrice && salePriceVal > 0) {
      return ((originalPrice - salePriceVal) / originalPrice * 100).round();
    }
    return 0;
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
        if (originalPrice > 0 && salePriceVal < originalPrice && salePriceVal > 0) {
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
  }  Widget _buildRegisterForTrialBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'سجل حسابك الآن واحصل على 3 أيام تجربة مجانية! 🎁',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              _checkSubscriptionStatus();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('سجل الآن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivateTrialCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'عرض خاص: يمكنك تجربة الباقة المميزة لمدة 3 أيام مجاناً! 🎉',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isActivatingTrial ? null : () async {
              setState(() => _isActivatingTrial = true);
              try {
                final success = await AuthService().startTrial();
                if (mounted) {
                  if (success) {
                    InAppNotification.show(
                      context: context,
                      message: 'تم تفعيل التجربة المجانية بنجاح! 🎉',
                      type: NotificationType.success,
                      icon: Icons.check_circle_outline,
                    );
                    _checkSubscriptionStatus();
                    _fetchPackages();
                  } else {
                    InAppNotification.show(
                      context: context,
                      message: 'فشل تفعيل التجربة.',
                      type: NotificationType.error,
                      icon: Icons.error_outline,
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  InAppNotification.show(
                    context: context,
                    message: 'خطأ: $e',
                    type: NotificationType.error,
                    icon: Icons.error_outline,
                  );
                }
              } finally {
                if (mounted) setState(() => _isActivatingTrial = false);
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isActivatingTrial
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5))
                : const Text('تفعيل مجاني', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
