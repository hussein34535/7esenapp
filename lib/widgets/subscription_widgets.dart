import 'package:flutter/material.dart';
import 'package:hesen/services/currency_service.dart';
import 'package:hesen/screens/payment_screen.dart';

class SubscriptionPackageCard extends StatelessWidget {
  final dynamic pkg;
  final bool isFeatured;
  final bool isSubscribed;
  final VoidCallback onPaymentComplete;

  const SubscriptionPackageCard({
    super.key,
    required this.pkg,
    required this.isFeatured,
    required this.isSubscribed,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isFeatured
            ? const LinearGradient(
                colors: [Color(0xFF2E0249), Color(0xFF190033)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : (hasDiscount
                ? LinearGradient(
                    colors: isStrongOffer
                        ? [const Color(0xFF001A33), const Color(0xFF000D1A)]
                        : [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)],
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFeatured ? Colors.amber : themeColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: (isFeatured ? Colors.amber : themeColor)
                              .withValues(alpha: 0.3),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                              text: "${_getDurationString(pkg['duration_days'])} / ",
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
                          text: "${_getDurationString(pkg['duration_days'])} / ",
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
                if (pkg['features'] != null &&
                    (pkg['features'] as List).isNotEmpty)
                  ...(pkg['features'] as List)
                      .map((f) => _BulletPoint(text: f.toString())),
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
                        onPaymentComplete();
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
                        isSubscribed ? 'إضافة الباقة' : 'اشتراك الآن',
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
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
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
