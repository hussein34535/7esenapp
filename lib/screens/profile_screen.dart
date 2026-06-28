import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:intl/intl.dart';
import 'package:hesen/screens/subscription_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hesen/services/cloudinary_service.dart';
import 'package:hesen/widgets/in_app_notification.dart';

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
      // أولاً: حمّل الكاش فوراً عشان الشاشة تبان بسرعة
      final cached = await _authService.getCachedUserDataOnly();
      if (mounted && cached != null) {
        setState(() {
          _userData = cached;
          _isLoading = false; // وقف اللودينج بالكاش
        });
      }

      // ثانياً: اجلب البيانات الجديدة في الخلفية
      final user = _authService.currentUser;
      if (user != null) {
        try {
          await user.reload();
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
        InAppNotification.show(
          context: context,
          message: 'تم تحديث الصورة الشخصية بنجاح',
          type: NotificationType.success,
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingProfile = false);
        InAppNotification.show(
          context: context,
          message: 'فشل تحديث الصورة: $e',
          type: NotificationType.error,
          icon: Icons.error_outline,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    Widget bodyContent = user == null
        ? Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1.5,
                      ),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.circleUser,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'لست مسجل دخول',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'سجل دخولك الآن للاستمتاع بالمحتوى المميز',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildGradientButton(
                    text: 'تسجيل الدخول / إنشاء حساب',
                    icon: Icons.login_rounded,
                    colors: [const Color(0xFF7C52D8), const Color(0xFF5E35B1)],
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      if (!mounted) return;
                      _fetchUserData();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          )
        : _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7C52D8),
                ),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // Avatar Section
                      Center(
                        child: Column(
                          children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: isSubscribed
                                        ? [const Color(0xFF00C853), const Color(0xFFB9F6CA)]
                                        : [const Color(0xFF7C52D8), const Color(0xFFB39DDB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isSubscribed
                                              ? const Color(0xFF00C853)
                                              : const Color(0xFF7C52D8))
                                          .withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFF1E1E2C),
                                  backgroundImage: photoUrl != null
                                      ? CachedNetworkImageProvider(photoUrl)
                                      : null,
                                  child: _isUploadingProfile
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : (photoUrl == null
                                          ? const FaIcon(
                                              FontAwesomeIcons.user,
                                              size: 40,
                                              color: Colors.white70,
                                            )
                                          : null),
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
                                      color: const Color(0xFF7C52D8),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF0C091A),
                                        width: 2,
                                      ),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSubscribed
                                  ? const LinearGradient(
                                      colors: [Color(0xFF00C853), Color(0xFF00E676)],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF616161), Color(0xFF757575)],
                                    ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (isSubscribed
                                          ? const Color(0xFF00C853)
                                          : const Color(0xFF616161))
                                      .withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              isSubscribed ? 'اشتراك نشط' : 'باقة مجانية',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Subscription Details Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تفاصيل الاشتراك',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildDetailTile(
                            icon: Icons.card_membership_rounded,
                            iconColor: const Color(0xFF7C52D8),
                            label: 'الخطة الحالية',
                            value: plan,
                            valueColor: Colors.white,
                          ),
                          if (subscriptionDuration.isNotEmpty)
                            _buildDetailTile(
                              icon: Icons.timer_outlined,
                              iconColor: Colors.blueAccent,
                              label: 'مدة الاشتراك',
                              value: subscriptionDuration,
                              valueColor: Colors.white,
                            ),
                          _buildDetailTile(
                            icon: Icons.calendar_today_rounded,
                            iconColor: Colors.tealAccent,
                            label: 'تاريخ الانتهاء',
                            value: expiryDate,
                            valueColor: Colors.white,
                          ),
                          if (daysRemaining.isNotEmpty)
                            _buildDetailTile(
                              icon: Icons.hourglass_empty_rounded,
                              iconColor: Colors.amberAccent,
                              label: 'الوقت المتبقي',
                              value: daysRemaining,
                              valueColor: Colors.amberAccent,
                            ),
                          _buildDetailTile(
                            icon: Icons.offline_pin_rounded,
                            iconColor: isSubscribed ? const Color(0xFF00C853) : Colors.redAccent,
                            label: 'الحالة',
                            value: isSubscribed ? 'نشط' : 'غير نشط',
                            valueColor: isSubscribed ? const Color(0xFF00C853) : Colors.redAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    _buildGradientButton(
                      text: 'تجديد الاشتراك',
                      icon: Icons.workspace_premium_rounded,
                      colors: [const Color(0xFF7C52D8), const Color(0xFF5E35B1)],
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionScreen(),
                          ),
                        );
                      },
                    ),
                    if (isSubscribed) ...[
                      const SizedBox(height: 10),
                      _buildOutlineButton(
                        text: 'إلغاء الاشتراك',
                        icon: Icons.cancel_outlined,
                        color: Colors.redAccent,
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF14121E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                              ),
                              title: const Text('إلغاء الاشتراك',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: const Text(
                                'هل أنت متأكد من رغبتك في إلغاء الاشتراك؟ سيتم إيقاف جميع الميزات المميزة والبث المباشر فوراً.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('تراجع',
                                      style: TextStyle(color: Colors.white54)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('تأكيد الإلغاء',
                                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            setState(() => _isLoading = true);
                            final success = await _authService.cancelSubscription();
                            if (mounted) {
                              setState(() => _isLoading = false);
                              if (success) {
                                InAppNotification.show(
                                  context: context,
                                  message: 'تم إلغاء الاشتراك بنجاح ونودّعك بكل ودّ 😔',
                                  type: NotificationType.success,
                                  icon: Icons.check_circle_outline,
                                );
                                _fetchUserData();
                              } else {
                                InAppNotification.show(
                                  context: context,
                                  message: 'فشل إلغاء الاشتراك. يرجى المحاولة لاحقاً.',
                                  type: NotificationType.error,
                                  icon: Icons.error_outline,
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildOutlineButton(
                      text: 'تسجيل الخروج',
                      icon: Icons.logout_rounded,
                      color: Colors.redAccent,
                      onPressed: _signOut,
                    ),
                  ],
                ),
              ),
            );

    final Widget scaffoldContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('حسابي'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: bodyContent,
    );

    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (isWindows) {
      return _buildAmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: scaffoldContent,
          ),
        ),
      );
    }

    return _buildAmbientBackground(
      child: scaffoldContent,
    );
  }

  Widget _buildAmbientBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF090616), Color(0xFF030206)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C52D8).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  center: const Alignment(-0.8, -0.7),
                  radius: 1.0,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00C853).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  center: const Alignment(0.8, 0.7),
                  radius: 1.2,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    VoidCallback? onCopy,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
              onPressed: onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
    required List<Color> colors,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 20),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
