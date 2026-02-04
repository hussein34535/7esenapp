import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hesen/main.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/services/currency_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hesen/services/cloudinary_service.dart';
import 'package:hesen/services/resend_service.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> package;

  const PaymentScreen({super.key, required this.package});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<dynamic> _paymentMethods = [];
  bool _isLoadingMethods = true;
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _paymentIdController = TextEditingController();
  bool _isCheckingCoupon = false;

  bool _isCouponValid = false;
  double _discountPercent = 0.0;

  // Selection State
  dynamic _selectedMethodId;

  // Image Upload State
  File? _receiptImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchPaymentData();
  }

  Future<void> _fetchPaymentData() async {
    try {
      final methods = await ApiService.fetchPaymentMethods();
      if (mounted) {
        setState(() {
          _paymentMethods = methods;

          // Append "Other Ways" (Telegram Redirect)
          _paymentMethods.add({
            'id': 'telegram_contact',
            'name': 'طرق دفع أخرى',
            'image': null, // Will use icon
            'number': 'اضغط هنا للتواصل عبر تيليجرام',
            'is_telegram': true,
          });

          _isLoadingMethods = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching payment data: $e");
      if (mounted) {
        setState(() => _isLoadingMethods = false);
      }
    }
  }

  Future<void> _verifyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isCheckingCoupon = true;
    });

    try {
      final result = await ApiService.verifyCoupon(code);
      if (mounted) {
        setState(() {
          _isCheckingCoupon = false;
          if (result['valid'] == true) {
            _isCouponValid = true;
            _discountPercent = (result['discount_percent'] ?? 0).toDouble();
          } else {
            _isCouponValid = false;
            _discountPercent = 0.0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingCoupon = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _receiptImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _submitPaymentRequest(double finalPrice) async {
    if (_receiptImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى رفع صورة الإيصال أولاً')),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Upload Image (Cloudinary)
      final imageUrl = await CloudinaryService.uploadImage(_receiptImage!);

      // 2. Submit to API

      await ApiService.submitPaymentRequest(
          user.uid, int.parse(widget.package['id'].toString()), imageUrl,
          paymentIdentifier: _paymentIdController.text.trim());

      // 3. Notify Admin via Email
      await ResendService.sendAdminPaymentNotification(
        userEmail: user.email ?? 'Unknown User',
        packageName: widget.package['name'] ?? 'Premium Package',
        imageUrl: imageUrl,
        paymentIdentifier: _paymentIdController.text.trim(),
      );

      // Trigger fast polling on Windows to catch activation
      if (!kIsWeb && Platform.isWindows) {
        homeKey.currentState?.startFastPolling();
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("تم استلام طلبك بنجاح",
                style: TextStyle(color: Colors.white)),
            content: const Text(
              "سيقوم المسؤول بمراجعة الإيصال وتفعيل اشتراكك قريباً. شكراً لك!",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close PaymentScreen
                  Navigator.pop(context); // Close SubscriptionScreen (optional)
                },
                child: const Text("حسناً",
                    style: TextStyle(color: Colors.purpleAccent)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Payment Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Price
    final double originalPrice =
        num.tryParse(widget.package['price'].toString())?.toDouble() ?? 0.0;

    // SALE PRICE LOGIC
    double basePrice = originalPrice;
    if (widget.package['sale_price'] != null &&
        widget.package['sale_price'].toString() != '0' &&
        widget.package['sale_price'].toString() != 'null') {
      basePrice =
          num.tryParse(widget.package['sale_price'].toString())?.toDouble() ??
              originalPrice;
    }

    double finalPrice = basePrice;
    if (_isCouponValid && _discountPercent > 0) {
      finalPrice = basePrice * (1 - (_discountPercent / 100));
    }

    // Check if confirm is enabled
    final bool canConfirm =
        _selectedMethodId != null && _receiptImage != null && !_isUploading;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إتمام الدفع',
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
          // Background Effects
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: _isUploading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(color: Colors.purpleAccent),
                        SizedBox(height: 20),
                        Text("جاري رفع الإيصال وتأكيد الطلب...",
                            style: TextStyle(color: Colors.white))
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Summary Card
                        _buildSummaryCard(
                            widget.package, originalPrice, finalPrice),
                        const SizedBox(height: 30),

                        // Coupon Section
                        const Text(
                          "لديك كود خصم؟",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _buildCouponSection(),
                        const SizedBox(height: 30),

                        // Payment Methods
                        const Text(
                          "اختر طريقة الدفع",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        if (_isLoadingMethods)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.purpleAccent))
                        else if (_paymentMethods.isEmpty)
                          const Text("لا توجد طرق دفع متاحة حالياً",
                              style: TextStyle(color: Colors.grey))
                        else
                          ..._paymentMethods
                              .map((m) => _buildPaymentMethodCard(m)),

                        // Receipt Upload Section (Only show if method selected)
                        if (_selectedMethodId != null) ...[
                          const SizedBox(height: 30),
                          const Text(
                            "إثبات الدفع",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          _buildUploadSection(),
                        ],

                        const SizedBox(height: 30),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 20),

                        // Confirm Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: canConfirm
                                ? () => _submitPaymentRequest(finalPrice)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canConfirm
                                  ? const Color(0xFF0088CC)
                                  : Colors.grey.shade800,
                              disabledBackgroundColor: Colors.grey.shade900,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: canConfirm
                                        ? Colors.white
                                        : Colors.white38),
                                const SizedBox(width: 10),
                                Text(
                                  'إرسال الطلب',
                                  style: TextStyle(
                                      color: canConfirm
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "بعد التحويل، يرجى رفع صورة الإيصال لتفعيل اشتراكك.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: _receiptImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_receiptImage!,
                    fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_upload_outlined,
                      size: 40, color: Colors.purpleAccent),
                  SizedBox(height: 10),
                  Text("اضغط لرفع صورة الإيصال",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
      Map<String, dynamic> pkg, double original, double finalPrice) {
    bool hasSale = pkg['sale_price'] != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pkg['name'] ?? 'باقة',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            pkg['description'] ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("الإجمالي:", style: TextStyle(color: Colors.white70)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isCouponValid || hasSale)
                    Text(
                      "$original",
                      style: const TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    CurrencyService.format(finalPrice),
                    style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _couponController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'أدخل الكود هنا',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isCheckingCoupon ? null : _verifyCoupon,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent.withValues(alpha: 0.8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isCheckingCoupon
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("تطبيق",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final bool isSelected = _selectedMethodId == method['id'];

    return GestureDetector(
      onTap: () async {
        if (method['id'] == 'telegram_contact') {
          final url = Uri.parse('https://t.me/tv_7esen');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
          return; // Do not select
        }
        setState(() {
          _selectedMethodId = method['id'];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.purple.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? Colors.purpleAccent : Colors.white12,
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Radio Indicator
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isSelected ? Colors.purpleAccent : Colors.grey,
                        width: 2),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                  color: Colors.purpleAccent,
                                  shape: BoxShape.circle)))
                      : null,
                ),

                if (method['image'] != null && method['image']['url'] != null)
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(method['image']['url']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: method['is_telegram'] == true
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: method['is_telegram'] == true
                        ? const Center(
                            child: Icon(FontAwesomeIcons.telegram,
                                color: Colors.blue, size: 24))
                        : const Icon(Icons.payment, color: Colors.white70),
                  ),

                const SizedBox(width: 15), // Increased spacing

                Expanded(
                  child: Text(
                    method['name'] ?? 'طريقة دفع',
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16),
                  ),
                ),
              ],
            ),
            if (isSelected && method['number'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      method['number'],
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const Icon(Icons.copy, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ],

            // Integrated Input Field with Dynamic Label
            if (isSelected && method['id'] != 'telegram_contact') ...[
              const SizedBox(height: 15),
              TextField(
                controller: _paymentIdController,
                decoration: InputDecoration(
                  labelText:
                      method['input_label'] ?? 'رقم المحفظة / رقم العملية',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: '010xxxxxxx',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black38,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon:
                      const Icon(Icons.edit, color: Colors.purpleAccent),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType
                    .text, // Text instead of number for flexibility
              ),
            ],

            if (isSelected && method['instructions'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  method['instructions'],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
