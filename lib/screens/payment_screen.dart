import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hesen/main.dart';
import 'package:hesen/services/api_service.dart';
import 'package:hesen/services/currency_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hesen/services/cloudinary_service.dart';
import 'package:hesen/services/resend_service.dart';
import 'package:hesen/widgets/in_app_notification.dart';
import 'package:hesen/screens/payment_success_screen.dart';

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
  final TextEditingController _walletPhoneController = TextEditingController();
  bool _isCheckingCoupon = false;

  bool _isCouponValid = false;
  double _discountPercent = 0.0;

  // Selection State
  dynamic _selectedMethodId;

  // Image Upload State
  XFile? _receiptImage;
  Uint8List? _receiptImageBytes;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchPaymentData();
  }

  @override
  void dispose() {
    _couponController.dispose();
    _paymentIdController.dispose();
    _walletPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentData() async {
    try {
      final methods = await ApiService.fetchPaymentMethods();
      if (mounted) {
        setState(() {
          _paymentMethods = List.from(methods);
        });
      }
    } catch (e) {
      debugPrint("Error fetching payment data: $e");
    } finally {
      if (mounted) {
        setState(() {
          // Insert Fawaterak Visa/Card
          _paymentMethods.insert(0, {
            'id': 'fawaterak_card',
            'name': 'Ø§Ù„Ø¯ÙØ¹ Ø¨Ø§Ù„Ø¨Ø·Ø§Ù‚Ø© Ø§Ù„Ø¨Ù†ÙƒÙŠØ© (ÙÙŠØ²Ø§ / Ù…Ø§Ø³ØªØ±ÙƒØ§Ø±Ø¯)',
            'image': null,
            'is_fawaterak': true,
            'fawaterak_type': 'card',
          });

          // Insert Fawaterak Fawry
          _paymentMethods.insert(1, {
            'id': 'fawaterak_fawry',
            'name': 'Ø§Ù„Ø¯ÙØ¹ Ø§Ù„ÙÙˆØ±ÙŠ (ÙÙˆØ±ÙŠ)',
            'image': null,
            'is_fawaterak': true,
            'fawaterak_type': 'fawry',
          });

          // Insert Fawaterak Mobile Wallet
          _paymentMethods.insert(2, {
            'id': 'fawaterak_wallet',
            'name': 'Ø§Ù„Ù…Ø­Ø§ÙØ¸ Ø§Ù„Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠØ© (ÙÙˆØ¯Ø§ÙÙˆÙ† ÙƒØ§Ø´ / Ø§ØªØµØ§Ù„Ø§Øª / Ø¥Ù„Ø®)',
            'image': null,
            'is_fawaterak': true,
            'fawaterak_type': 'wallet',
          });

          // Append "Other Ways" (Telegram Contact)
          _paymentMethods.add({
            'id': 'telegram_contact',
            'name': 'Ø·Ø±Ù‚ Ø¯ÙØ¹ Ø£Ø®Ø±Ù‰',
            'image': null, // Will use icon
            'is_telegram': true,
          });

          _isLoadingMethods = false;
        });
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
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _receiptImage = pickedFile;
          _receiptImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        InAppNotification.show(
          context: context,
          message: 'Error picking image: $e',
          type: NotificationType.error,
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _submitPaymentRequest(double finalPrice) async {
    if (_receiptImage == null) {
      if (mounted) {
        InAppNotification.show(
          context: context,
          message: 'ÙŠØ±Ø¬Ù‰ Ø±ÙØ¹ ØµÙˆØ±Ø© Ø§Ù„Ø¥ÙŠØµØ§Ù„ Ø£ÙˆÙ„Ø§Ù‹',
          type: NotificationType.error,
          icon: Icons.error_outline,
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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        homeKey.currentState?.startFastPolling();
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("ØªÙ… Ø§Ø³ØªÙ„Ø§Ù… Ø·Ù„Ø¨Ùƒ Ø¨Ù†Ø¬Ø§Ø­",
                style: TextStyle(color: Colors.white)),
            content: const Text(
              "Ø³ÙŠÙ‚ÙˆÙ… Ø§Ù„Ù…Ø³Ø¤ÙˆÙ„ Ø¨Ù…Ø±Ø§Ø¬Ø¹Ø© Ø§Ù„Ø¥ÙŠØµØ§Ù„ ÙˆØªÙØ¹ÙŠÙ„ Ø§Ø´ØªØ±Ø§ÙƒÙƒ Ù‚Ø±ÙŠØ¨Ø§Ù‹. Ø´ÙƒØ±Ø§Ù‹ Ù„Ùƒ!",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close PaymentScreen
                  Navigator.pop(context); // Close SubscriptionScreen (optional)
                },
                child: const Text("Ø­Ø³Ù†Ø§Ù‹",
                    style: TextStyle(color: Colors.purpleAccent)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Payment Error: $e");
      if (mounted) {
        InAppNotification.show(
          context: context,
          message: 'Ø­Ø¯Ø« Ø®Ø·Ø£: $e',
          type: NotificationType.error,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleFawaterakPayment(double finalPrice) async {
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Determine method ('fawry', 'wallet', or 'card')
      final String paymentMethod = _selectedMethodId == 'fawaterak_fawry'
          ? 'fawry'
          : _selectedMethodId == 'fawaterak_wallet'
              ? 'wallet'
              : 'card';

      // 2. Create Fawaterak session on backend
      final couponCode = _couponController.text.trim();
      final phone = _selectedMethodId == 'fawaterak_wallet' ? _walletPhoneController.text.trim() : null;

      if (_selectedMethodId == 'fawaterak_wallet' && (phone == null || phone.length < 11)) {
        throw Exception("ÙŠØ±Ø¬Ù‰ Ø¥Ø¯Ø®Ø§Ù„ Ø±Ù‚Ù… Ù…Ø­ÙØ¸Ø© ØµØ­ÙŠØ­ Ù…ÙƒÙˆÙ† Ù…Ù† 11 Ø±Ù‚Ù…Ø§Ù‹");
      }

      final result = await ApiService.createFawaterakSession(
        user.uid,
        int.parse(widget.package['id'].toString()),
        paymentMethod,
        couponCode: _isCouponValid ? couponCode : null,
        phone: phone,
      );

      if (result['success'] != true) {
        throw Exception(result['error'] ?? "ÙØ´Ù„ Ø¥Ù†Ø´Ø§Ø¡ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ù…Ù† Ø§Ù„Ø³ÙŠØ±ÙØ±");
      }

      // Trigger fast polling on Windows to catch activation if paid
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        homeKey.currentState?.startFastPolling();
      }

      // 3. Show fawaterak receipt details dialog or redirect if it's a redirect payment (Visa)
      if (mounted) {
        final paymentData = result['paymentData'] ?? {};
        if (paymentData['redirectTo'] != null && paymentData['redirectTo'].toString().isNotEmpty) {
          final url = Uri.parse(paymentData['redirectTo'].toString());
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            throw Exception("Ù„Ø§ ÙŠÙ…ÙƒÙ† ÙØªØ­ Ø±Ø§Ø¨Ø· Ø§Ù„Ø¯ÙØ¹ Ø¨Ø§Ù„Ø¨Ø·Ø§Ù‚Ø© Ø§Ù„Ø¨Ù†ÙƒÙŠØ©");
          }
          // Do not pop payment screen; show real-time verification dialog
          _showFawaterakSuccessDialog(result, finalPrice);
        } else {
          _showFawaterakSuccessDialog(result, finalPrice);
        }
      }
    } catch (e) {
      debugPrint("Fawaterak Payment Error: $e");
      if (mounted) {
        InAppNotification.show(
          context: context,
          message: 'Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ ØªÙ‡ÙŠØ¦Ø© Ø§Ù„Ø¯ÙØ¹: $e',
          type: NotificationType.error,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showFawaterakSuccessDialog(Map<String, dynamic> result, double finalPrice) {
    final method = result['paymentMethod']; // 'fawry', 'wallet', or 'card'
    final paymentData = result['paymentData'] ?? {};
    final dialogOpenTime = DateTime.now().toUtc();

    if (method == 'wallet' || method == 'card') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final user = FirebaseAuth.instance.currentUser;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                method == 'wallet' ? "Ø¬Ø§Ø±ÙŠ ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø¯ÙØ¹..." : "Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ø¥ØªÙ…Ø§Ù… Ø§Ù„Ø¯ÙØ¹ Ø¨Ø§Ù„Ø¨Ø·Ø§Ù‚Ø©...",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: StreamBuilder<DocumentSnapshot>(
                stream: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() : const Stream.empty(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    if (data['isSubscribed'] == true) {
                      bool isNewPayment = false;
                      final lastPaymentStr = data['lastPaymentTime'];
                      if (lastPaymentStr != null) {
                        final lastPayment = DateTime.tryParse(lastPaymentStr);
                        // Check if the payment happened recently (within the last 2 minutes of opening this dialog)
                        if (lastPayment != null && lastPayment.isAfter(dialogOpenTime.subtract(const Duration(minutes: 2)))) {
                           isNewPayment = true;
                        }
                      }

                      if (isNewPayment) {
                        // Success detected in realtime!
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           if (Navigator.canPop(context)) Navigator.of(context).pop(); // Close dialog
                           
                           // Navigate to PaymentSuccessScreen and replace the payment screen!
                           Navigator.of(context).pushReplacement(
                             MaterialPageRoute(
                               builder: (context) => PaymentSuccessScreen(
                                 packageName: widget.package['name'] ?? 'Ø¨Ø§Ù‚Ø© Premium',
                                 price: finalPrice,
                                 durationDays: int.tryParse(widget.package['duration_days']?.toString() ?? '30') ?? 30,
                               ),
                             ),
                           );
                        });
                      }
                    }
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      const CircularProgressIndicator(color: Colors.purpleAccent),
                      const SizedBox(height: 25),
                      Text(
                        method == 'wallet'
                            ? "ÙˆØµÙ„ØªÙƒ Ø±Ø³Ø§Ù„Ø© Ø¹Ù„Ù‰ Ø±Ù‚Ù… Ø§Ù„Ù…Ø­ÙØ¸Ø© Ù…Ù† Ù…Ø²ÙˆØ¯ Ø§Ù„Ø®Ø¯Ù…Ø© ÙÙŠÙ‡Ø§ ÙƒÙ„ ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ø¯ÙØ¹.\nØ£ÙƒÙ‘Ø¯ Ø§Ù„Ø¹Ù…Ù„ÙŠØ© Ø¨Ø±Ù‚Ù…Ùƒ Ø§Ù„Ø³Ø±ÙŠØŒ ÙˆØ³ÙŠØªÙ… ØªÙØ¹ÙŠÙ„ Ø§Ø´ØªØ±Ø§ÙƒÙƒ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹."
                            : "ØªÙ… ÙØªØ­ ØµÙØ­Ø© Ø§Ù„Ø¯ÙØ¹ ÙÙŠ Ø§Ù„Ù…ØªØµÙØ­. ÙŠØ±Ø¬Ù‰ Ø¥Ø¯Ø®Ø§Ù„ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¨Ø·Ø§Ù‚Ø© ÙˆØ¥ÙƒÙ…Ø§Ù„ Ø§Ù„Ø¯ÙØ¹ Ù‡Ù†Ø§Ùƒ.\n\nØ³ÙŠØªÙ… ØªÙØ¹ÙŠÙ„ Ø­Ø³Ø§Ø¨Ùƒ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹ ÙÙˆØ± Ù†Ø¬Ø§Ø­ Ø§Ù„Ø¹Ù…Ù„ÙŠØ©. Ù„Ø§ ØªÙ‚Ù… Ø¨Ø¥ØºÙ„Ø§Ù‚ Ù‡Ø°Ù‡ Ø§Ù„Ù†Ø§ÙØ°Ø©.",
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (method == 'wallet' && paymentData['meezaReference'] != null && paymentData['meezaReference'].toString().isNotEmpty)
                        Text(
                          "Ø§Ù„Ø±Ù‚Ù… Ø§Ù„Ù…Ø±Ø¬Ø¹ÙŠ: ${paymentData['meezaReference']}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        )
                      else if (method != 'wallet')
                        const Text(
                          "ØªØ£ÙƒØ¯ Ù…Ù† Ø¹Ø¯Ù… Ø¥ØºÙ„Ø§Ù‚ Ù‡Ø°Ù‡ Ø§Ù„ØµÙØ­Ø© Ø­ØªÙ‰ ÙŠØªÙ… ØªØ­ÙˆÙŠÙ„Ùƒ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  );
                },
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Allow manual exit if it gets stuck
                  },
                  child: const Text("Ø¥Ù„ØºØ§Ø¡ / Ø§Ù„Ø¯ÙØ¹ Ù„Ø§Ø­Ù‚Ø§Ù‹", style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String title = "";
        String codeLabel = "";
        String paymentCode = "";
        String detailsText = "";
        List<Widget> extraDetails = [];

        if (method == 'fawry') {
          title = "Ø±Ù‚Ù… Ø§Ù„Ø¯ÙØ¹ Ø¹Ø¨Ø± ÙÙˆØ±ÙŠ";
          codeLabel = "ÙƒÙˆØ¯ Ø§Ù„Ø¯ÙØ¹ (Fawry Code)";
          paymentCode = paymentData['fawryCode']?.toString() ?? '';
          final expireDate = paymentData['expireDate'] ?? '';
          
          detailsText = "ØªÙˆØ¬Ù‡ Ø¥Ù„Ù‰ Ø£Ù‚Ø±Ø¨ Ù…Ù†ÙØ° ÙÙˆØ±ÙŠ Ø£Ùˆ ÙƒØ´Ùƒ ÙˆØ§Ø·Ù„Ø¨ Ø§Ù„Ø¯ÙØ¹ Ù„Ø®Ø¯Ù…Ø© (ÙÙˆØ§ØªÙŠØ±Ùƒ) Ø¨Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø§Ù„ÙƒÙˆØ¯ Ø§Ù„Ù…ÙˆØ¶Ø­ Ø£Ø¹Ù„Ø§Ù‡.";
          
          if (expireDate.isNotEmpty) {
            extraDetails.add(
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "ØªØ§Ø±ÙŠØ® Ø§Ù„ØµÙ„Ø§Ø­ÙŠØ©: $expireDate",
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        } 

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                codeLabel,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Large code container with copy button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SelectableText(
                        paymentCode,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.purpleAccent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: paymentCode));
                        InAppNotification.show(
                          context: context,
                          message: 'ØªÙ… Ù†Ø³Ø® ÙƒÙˆØ¯ Ø§Ù„Ø¯ÙØ¹ Ø¨Ù†Ø¬Ø§Ø­',
                          type: NotificationType.success,
                          icon: Icons.check_circle_outline,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              ...extraDetails,
              const SizedBox(height: 15),
              Text(
                detailsText,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close PaymentScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text("Ø­Ø³Ù†Ø§Ù‹ØŒ ØªÙ…", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Price
    final double originalPrice =
        num.tryParse(widget.package['price'].toString())?.toDouble() ?? 0.0;

    // SALE PRICE LOGIC: Only apply if sale_price is less than price and greater than 0
    double basePrice = originalPrice;
    final double salePriceVal =
        num.tryParse(widget.package['sale_price']?.toString() ?? '')?.toDouble() ?? 0.0;
    if (salePriceVal < originalPrice && salePriceVal > 0) {
      basePrice = salePriceVal;
    }

    double finalPrice = basePrice;
    if (_isCouponValid && _discountPercent > 0) {
      finalPrice = basePrice * (1 - (_discountPercent / 100));
    }

    // Check if confirm is enabled
    final bool isFawaterak = _selectedMethodId == 'fawaterak_fawry' || _selectedMethodId == 'fawaterak_wallet' || _selectedMethodId == 'fawaterak_card';
    final bool isTelegramContact = _selectedMethodId == 'telegram_contact';
    bool canConfirm = _selectedMethodId != null &&
        !isTelegramContact &&
        (isFawaterak || _receiptImage != null) &&
        !_isUploading;
        
    if (_selectedMethodId == 'fawaterak_wallet' && _walletPhoneController.text.trim().length < 11) {
      canConfirm = false;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Ø¥ØªÙ…Ø§Ù… Ø§Ù„Ø¯ÙØ¹',
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
                        Text("Ø¬Ø§Ø±ÙŠ Ø±ÙØ¹ Ø§Ù„Ø¥ÙŠØµØ§Ù„ ÙˆØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø·Ù„Ø¨...",
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
                          "Ù„Ø¯ÙŠÙƒ ÙƒÙˆØ¯ Ø®ØµÙ…ØŸ",
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
                          "Ø§Ø®ØªØ± Ø·Ø±ÙŠÙ‚Ø© Ø§Ù„Ø¯ÙØ¹",
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
                          const Text("Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ø±Ù‚ Ø¯ÙØ¹ Ù…ØªØ§Ø­Ø© Ø­Ø§Ù„ÙŠØ§Ù‹",
                              style: TextStyle(color: Colors.grey))
                        else
                          ..._paymentMethods
                              .map((m) => _buildPaymentMethodCard(m)),

                        // Receipt Upload Section (Only show if method selected and it's not Fawaterak/Paymob)
                        if (_selectedMethodId != null && !isFawaterak && !isTelegramContact) ...[
                          const SizedBox(height: 30),
                          const Text(
                            "Ø¥Ø«Ø¨Ø§Øª Ø§Ù„Ø¯ÙØ¹",
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

                        // Confirm Button (hidden for Telegram contact)
                        if (!isTelegramContact) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: canConfirm
                                  ? () {
                                      if (isFawaterak) {
                                        _handleFawaterakPayment(finalPrice);
                                      } else {
                                        _submitPaymentRequest(finalPrice);
                                      }
                                    }
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
                                    isFawaterak ? 'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø¯ÙØ¹' : 'Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø·Ù„Ø¨',
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
                          Text(
                            isFawaterak
                                ? "Ø§Ø¶ØºØ· Ù„ØªÙˆÙ„ÙŠØ¯ ÙƒÙˆØ¯ Ø§Ù„Ø¯ÙØ¹ Ø§Ù„Ø®Ø§Øµ Ø¨Ù€ ÙÙˆØ±ÙŠ Ø£Ùˆ Ø§Ù„Ù…Ø­ÙØ¸Ø©."
                                : "Ø¨Ø¹Ø¯ Ø§Ù„ØªØ­ÙˆÙŠÙ„ØŒ ÙŠØ±Ø¬Ù‰ Ø±ÙØ¹ ØµÙˆØ±Ø© Ø§Ù„Ø¥ÙŠØµØ§Ù„ Ù„ØªÙØ¹ÙŠÙ„ Ø§Ø´ØªØ±Ø§ÙƒÙƒ.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
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
        child: _receiptImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_receiptImageBytes!,
                    fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_upload_outlined,
                      size: 40, color: Colors.purpleAccent),
                  SizedBox(height: 10),
                  Text("Ø§Ø¶ØºØ· Ù„Ø±ÙØ¹ ØµÙˆØ±Ø© Ø§Ù„Ø¥ÙŠØµØ§Ù„",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
      Map<String, dynamic> pkg, double original, double finalPrice) {
    final double salePriceVal = num.tryParse(pkg['sale_price']?.toString() ?? '')?.toDouble() ?? 0.0;
    bool hasSale = salePriceVal < original && salePriceVal > 0;
    final int discountMonths = int.tryParse(pkg['discount_months']?.toString() ?? '0') ?? 0;
    final bool hasAnyDiscount = hasSale || _isCouponValid || discountMonths > 0;

    // Saved amount
    final double savedAmount = original - finalPrice;
    final double savedPercent = original > 0 ? (savedAmount / original * 100) : 0.0;

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
            pkg['name'] ?? 'Ø¨Ø§Ù‚Ø©',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            pkg['description'] ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 15),

          // Original price (struck through if there's any discount)
          if (hasAnyDiscount)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ø§Ù„Ø³Ø¹Ø± Ø§Ù„Ø£ØµÙ„ÙŠ:", style: TextStyle(color: Colors.white54, fontSize: 14)),
                Text(
                  CurrencyService.format(original),
                  style: const TextStyle(
                    color: Colors.white38,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

          // Sale discount breakdown
          if (hasSale) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ø®ØµÙ… Ø§Ù„Ø¨Ø§Ù‚Ø©:", style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(
                  "- ${CurrencyService.format(original - salePriceVal)}",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],

          // Coupon discount breakdown
          if (_isCouponValid && _discountPercent > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Ø®ØµÙ… ÙƒÙˆØ¨ÙˆÙ† (${_discountPercent.toStringAsFixed(0)}%):",
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(
                  "- ${CurrencyService.format(salePriceVal - finalPrice >= 0 ? (hasSale ? salePriceVal * (_discountPercent / 100) : original * (_discountPercent / 100)) : 0)}",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],

          // Free months gift
          if (discountMonths > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.greenAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    discountMonths == 1
                        ? "Ø®ØµÙ… Ø´Ù‡Ø± ÙƒØ§Ù…Ù„ Ù…Ø¬Ø§Ù†Ø§Ù‹"
                        : discountMonths == 2
                            ? "Ø®ØµÙ… Ø´Ù‡Ø±ÙŠÙ† Ù…Ø¬Ø§Ù†Ø§Ù‹"
                            : "Ø®ØµÙ… $discountMonths Ø£Ø´Ù‡Ø± Ù…Ø¬Ø§Ù†ÙŠØ©",
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],

          const Divider(color: Colors.white12, height: 24),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ:", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (savedAmount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "ÙˆÙÙ‘Ø±Øª ${CurrencyService.format(savedAmount)} (${savedPercent.toStringAsFixed(0)}%)",
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Text(
                    CurrencyService.format(finalPrice),
                    style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 26,
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
              hintText: 'Ø£Ø¯Ø®Ù„ Ø§Ù„ÙƒÙˆØ¯ Ù‡Ù†Ø§',
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
                : const Text("ØªØ·Ø¨ÙŠÙ‚",
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
          // Select it instead of auto-redirecting
          setState(() {
            _selectedMethodId = method['id'];
          });
          return;
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

                if (method['image'] is Map && method['image']['url'] != null)
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
                          : Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: method['is_telegram'] == true
                        ? const Center(
                            child: Icon(Icons.payment,
                                color: Colors.white60, size: 26))
                        : method['id'] == 'fawaterak_fawry'
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/fawry_logo.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : method['id'] == 'fawaterak_wallet'
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/wallets_combined.png',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.credit_card_rounded,
                                        color: Colors.blueAccent, size: 24),
                                  ),
                  ),

                const SizedBox(width: 15), // Increased spacing

                Expanded(
                  child: Text(
                    method['name'] ?? 'Ø·Ø±ÙŠÙ‚Ø© Ø¯ÙØ¹',
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16),
                  ),
                ),
              ],
            ),
            if (isSelected && method['id'] == 'telegram_contact') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0088CC).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFF0088CC), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ù„Ù„ØªÙˆØ§ØµÙ„ Ù…Ø¹Ù†Ø§ ÙˆØªÙØ¹ÙŠÙ„ Ø§Ø´ØªØ±Ø§ÙƒÙƒ Ø¹Ø¨Ø± Ø·Ø±Ù‚ Ø¯ÙØ¹ Ø£Ø®Ø±Ù‰ØŒ Ø§Ø¶ØºØ· Ø§Ù„Ø²Ø± Ø¨Ø§Ù„Ø£Ø³ÙÙ„ Ù„Ù„ØªÙˆØ§ØµÙ„ Ø¹Ø¨Ø± ØªÙŠÙ„ÙŠØ¬Ø±Ø§Ù….',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://t.me/he_s_en');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.telegram, color: Colors.white, size: 18),
                  label: const Text('ØªÙˆØ§ØµÙ„ Ù…Ø¹Ù†Ø§ Ø¹Ø¨Ø± ØªÙŠÙ„ÙŠØ¬Ø±Ø§Ù…',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],

            if (isSelected && method['number'] != null && method['id'] != 'telegram_contact') ...[
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

            // Fawaterak Wallet Phone Input Field
            if (isSelected && method['id'] == 'fawaterak_wallet') ...[
              const SizedBox(height: 15),
              TextField(
                controller: _walletPhoneController,
                decoration: InputDecoration(
                  labelText: 'Ø±Ù‚Ù… Ø§Ù„Ù…Ø­ÙØ¸Ø© (Ø§Ù„Ø°ÙŠ Ø³ØªØ¯ÙØ¹ Ù…Ù†Ù‡)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: '01xxxxxxxxx',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black38,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.phone_android, color: Colors.purpleAccent),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                onChanged: (val) {
                  setState(() {}); // to update canConfirm if needed
                },
              ),
            ],

            // Integrated Input Field with Dynamic Label
            if (isSelected && method['id'] != 'telegram_contact' && method['is_fawaterak'] != true) ...[
              const SizedBox(height: 15),
              TextField(
                controller: _paymentIdController,
                decoration: InputDecoration(
                  labelText:
                      method['input_label'] ?? 'Ø±Ù‚Ù… Ø§Ù„Ù…Ø­ÙØ¸Ø© / Ø±Ù‚Ù… Ø§Ù„Ø¹Ù…Ù„ÙŠØ©',
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
