import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:intl/intl.dart';

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
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final data = await _authService.getUserData();
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });
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
    final plan = _userData?['subscriptionPlan'] ?? 'Free';

    String expiryDate = 'N/A';
    if (_userData?['subscriptionExpiry'] != null) {
      // Handle Timestamp or String
      try {
        final timestamp = _userData!['subscriptionExpiry'];
        if (timestamp is DateTime) {
          expiryDate = DateFormat('yyyy-MM-dd').format(timestamp);
        } else if (timestamp != null &&
            timestamp.runtimeType.toString().contains('Timestamp')) {
          // Firestore Timestamp (dynamic check to avoid import issues if not explicit)
          expiryDate =
              DateFormat('yyyy-MM-dd').format((timestamp as dynamic).toDate());
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
                  Icon(FontAwesomeIcons.circleUser,
                      size: 80, color: Colors.grey.withOpacity(0.5)),
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
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: accentColor.withOpacity(0.2),
                              child: Icon(FontAwesomeIcons.user,
                                  size: 40, color: accentColor),
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
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSubscribed
                                        ? Colors.green
                                        : Colors.grey),
                              ),
                              child: Text(
                                isSubscribed ? 'Premium Active' : 'Free Plan',
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
                              color: Colors.black.withOpacity(0.05),
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
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                            const Divider(height: 30),
                            _buildRow('الخطة الحالية', plan, textColor),
                            const SizedBox(height: 16),
                            _buildRow('تاريخ الانتهاء', expiryDate, textColor),
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
                            // TODO: Implement Renewal Logic / Webview
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('سيتم إضافة بوابة الدفع قريباً')),
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
                                color: Colors.redAccent.withOpacity(0.5)),
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
