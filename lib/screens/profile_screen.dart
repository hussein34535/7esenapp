import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:intl/intl.dart';
import 'package:hesen/screens/subscription_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hesen/services/cloudinary_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Prevent UI freeze on Web by delaying data fetch slightly
    Future.delayed(Duration.zero, () {
      _fetchUserData();
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.reload(); // Force refresh auth token
        } catch (e) {
          debugPrint("Web Auth Warning: $e");
        }
      }

      final data = await _authService.getUserData();
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    // Navigate back to Login or Home (which will redirect)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  bool _isUploadingProfile = false;

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploadingProfile = true);

      // 1. Upload to Cloudinary
      // Pass XFile directly (CloudinaryService now accepts XFile)
      final String imageUrl = await CloudinaryService.uploadImage(image);

      // 2. Update Auth & Firestore
      await _authService.updateProfilePicture(imageUrl);

      // 3. Refresh UI
      await _fetchUserData();
      await _authService.currentUser
          ?.reload(); // Reload Firebase User to get new photoURL

      if (mounted) {
        setState(() => _isUploadingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الصورة الشخصية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF141414) : Colors.grey[100]!;
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color accentColor = const Color(0xFF673ab7); // Deep Purple

    final user = _authService.currentUser;
    final email = user?.email ?? 'No User Data';
    final isSubscribed = _userData?['isSubscribed'] == true;
    String plan = _userData?['subscriptionPlan'] ??
        (_userData?['planId'] != null
            ? 'Premium (Plan ${_userData!['planId']})'
            : (isSubscribed ? 'Premium' : 'باقة مجانية'));

    final photoUrl =
        user?.photoURL ?? _userData?['image_url'] ?? _userData?['photoUrl'];

    String expiryDate = 'غير محدد';
    String daysRemaining = '';
    String subscriptionDuration = _userData?['subscriptionDuration'] ?? '';

    // Handle multiple formats: subscriptionEnd (API), subscriptionExpiry/expiryDate (Old Firestore)
    if (_userData?['subscriptionEnd'] != null ||
        _userData?['subscriptionExpiry'] != null ||
        _userData?['expiryDate'] != null) {
      try {
        final dynamic timestamp = _userData?['subscriptionEnd'] ??
            _userData?['subscriptionExpiry'] ??
            _userData?['expiryDate'];
        DateTime? expiryDateTime;

        if (timestamp is DateTime) {
          expiryDateTime = timestamp;
        } else if (timestamp is String) {
          expiryDateTime = DateTime.tryParse(timestamp);
        } else if (timestamp != null &&
            timestamp.runtimeType.toString().contains('Timestamp')) {
          expiryDateTime = (timestamp as dynamic).toDate();
        }

        if (expiryDateTime != null) {
          expiryDate = DateFormat('yyyy-MM-dd').format(expiryDateTime);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final expiryDateOnly = DateTime(
              expiryDateTime.year, expiryDateTime.month, expiryDateTime.day);
          final difference = expiryDateOnly.difference(today).inDays;

          if (difference > 0) {
            daysRemaining = '$difference يوم متبقي';
          } else if (difference == 0) {
            daysRemaining = 'ينتهي اليوم';
          } else {
            daysRemaining = 'منتهي';
          }
        }
      } catch (e) {
        expiryDate = 'Invalid Date';
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('حسابي'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ... (Login Prompt - unchanged)
                  Icon(FontAwesomeIcons.circleUser,
                      size: 80, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 20),
                  Text(
                    'لست مسجل دخول',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'سجل دخولك الآن للاستمتاع بالمحتوى المميز',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      // Refresh after return
                      _fetchUserData();
                      setState(() {});
                    },
                    child: const Text('تسجيل الدخول / إنشاء حساب',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: accentColor))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar Section
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color:
                                            accentColor.withValues(alpha: 0.5),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            accentColor.withValues(alpha: 0.2),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Hero(
                                    tag: 'profile_avatar',
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: const Color(0xFF2A2A2A),
                                      backgroundImage: photoUrl != null
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: _isUploadingProfile
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : (photoUrl == null
                                              ? Icon(FontAwesomeIcons.user,
                                                  size: 40, color: accentColor)
                                              : null),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _isUploadingProfile
                                        ? null
                                        : _pickAndUploadImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: bgColor, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSubscribed
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSubscribed
                                        ? Colors.green
                                        : Colors.grey),
                              ),
                              child: Text(
                                isSubscribed ? 'اشتراك نشط' : 'باقة مجانية',
                                style: TextStyle(
                                  color:
                                      isSubscribed ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Subscription Details Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تفاصيل الاشتراك',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor.withValues(alpha: 0.7),
                              ),
                            ),
                            const Divider(height: 30),
                            _buildRow('الخطة الحالية', plan, textColor),
                            if (subscriptionDuration.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildRow('مدة الاشتراك', subscriptionDuration,
                                  textColor),
                            ],
                            const SizedBox(height: 16),
                            _buildRow('تاريخ الانتهاء', expiryDate, textColor),
                            if (daysRemaining.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildRow(
                                  'الوقت المتبقي', daysRemaining, Colors.amber),
                            ],
                            const SizedBox(height: 16),
                            _buildRow(
                                'الحالة',
                                isSubscribed ? 'نشط' : 'غير نشط',
                                isSubscribed ? Colors.green : Colors.redAccent),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SubscriptionScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'تجديد الاشتراك',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.redAccent.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
