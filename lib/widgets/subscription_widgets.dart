import 'package:flutter/material.dart';
import 'package:hesen/services/currency_service.dart';
import 'package:hesen/screens/payment_screen.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/login_screen.dart';

class SubscriptionPackageCard extends StatelessWidget {
  final dynamic pkg;
  final bool isFeatured;
  final bool isSubscribed;
  final bool isCurrentPlan;
  final VoidCallback onPaymentComplete;

  const SubscriptionPackageCard({
    super.key,
    required this.pkg,
    required this.isFeatured,
    required this.isSubscribed,
    required this.isCurrentPlan,
    required this.onPaymentComplete,
  });

  String _getDurationString(dynamic days) {
    int d = int.tryParse(days.toString()) ?? 30;
    if (d == 30) return "شهر";
    if (d == 60) return "شهرين";
    if (d == 90) return "3 شهور";
    if (d == 180) return "6 شهور";
    if (d == 365 || d == 360) return "سنة";
    return "$d يوم";
  }

  @override
  Widget build(BuildContext context) {
    final salePrice = pkg['sale_price'];
    final int discountMonths = int.tryParse(pkg['discount_months']?.toString() ?? '0') ?? 0;

    final double originalPrice =
        num.tryParse(pkg['price'].toString())?.toDouble() ?? 0.0;
    final double salePriceVal =
        num.tryParse(salePrice.toString())?.toDouble() ?? originalPrice;

    bool hasDiscount = (salePriceVal < originalPrice && salePriceVal > 0) || discountMonths > 0;

    final String pkgName = (pkg['name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32), // Apple-style rounded corner (smooth 32px like iOS modal sheets)
        color: const Color(0xFF1C1C1E), // iOS System Gray 6 (Premium dark grey background)
        border: Border.all(
          color: isCurrentPlan
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : (isFeatured ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08)),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Plan Name & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pkgName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5, // Apple-style tight tracking
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          "خطتك الحالية",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Text(
                          "موصى به",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Short Description (only if it doesn't contain newlines)
            if (pkg['description'] != null &&
                !pkg['description'].toString().contains('\n') &&
                pkg['description'].toString().trim().isNotEmpty) ...[
              Text(
                pkg['description'].toString(),
                style: const TextStyle(
                  color: Colors.white54, // Muted Apple label
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Price Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  CurrencyService.format(hasDiscount ? salePriceVal : originalPrice),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'SF Pro Display', // Apple SF font fallback
                    fontFamilyFallback: [
                      'SF Pro Text',
                      '-apple-system',
                      'BlinkMacSystemFont',
                      'Segoe UI',
                      'Roboto',
                      'sans-serif',
                    ],
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "/ ${_getDurationString(pkg['duration_days'])}",
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Slashed Original Price (if discount exists)
            if (hasDiscount && salePriceVal < originalPrice && salePriceVal > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    CurrencyService.format(originalPrice),
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 14,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],

            // Gift / Promo months
            if (discountMonths > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.greenAccent, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      discountMonths == 1
                          ? "خصم شهر كامل مجاناً"
                          : discountMonths == 2
                              ? "خصم شهرين مجاناً"
                              : "خصم $discountMonths أشهر مجانية",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Primary Action Button (Apple Capsule Style)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isCurrentPlan
                    ? null
                    : () async {
                        final currentUser = AuthService().currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الرجاء تسجيل الدخول أو إنشاء حساب أولاً للاشتراك'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                          onPaymentComplete();
                          return;
                        }
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentScreen(package: pkg),
                          ),
                        );
                        onPaymentComplete();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan
                      ? Colors.transparent
                      : Colors.white,
                  foregroundColor: isCurrentPlan
                      ? Colors.white30
                      : Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24), // Apple Capsule Button Shape
                    side: isCurrentPlan
                        ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  isCurrentPlan
                      ? 'خطتك الحالية'
                      : (isSubscribed ? 'ترقية الاشتراك' : 'اشترك الآن'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 20),

            // Features Header
            const Text(
              "الميزات المتضمنة:",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Features Checklist
            Builder(
              builder: (context) {
                final desc = pkg['description']?.toString() ?? '';
                if (desc.contains('\n')) {
                  final lines = desc
                      .split('\n')
                      .map((l) => l.trim())
                      .where((l) => l.isNotEmpty)
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines.map((line) => _BulletPoint(text: line)).toList(),
                  );
                } else if (pkg['features'] != null && (pkg['features'] as List).isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: (pkg['features'] as List)
                        .map((f) => _BulletPoint(text: f.toString()))
                        .toList(),
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _BulletPoint(text: "بث بجودة Full HD & 4K بدون تقطيع"),
                      _BulletPoint(text: "تشغيل على جميع الأجهزة في نفس الوقت"),
                      _BulletPoint(text: "دعم فني متواصل على مدار الساعة 24/7"),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded, // iOS round checklist style
            color: Colors.greenAccent,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumFeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const PremiumFeatureItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
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
}
