import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:hesen/services/cloudinary_service.dart';
import 'package:hesen/widgets/in_app_notification.dart';

class LoginScreen extends StatefulWidget {
  /// When true, this screen is the app's entry gate (no route to pop back
  /// to): the back button is hidden and a successful sign-in fires
  /// [onLoginSuccess] instead of popping.
  final bool isInitialGate;

  /// Called after a successful sign-in/sign-up when [isInitialGate] is true.
  /// Callers use it to navigate to HomePage (which needs their theme callback).
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.isInitialGate = false, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Official multicolor Google "G" drawn natively (no icon-font approximation).
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final double stroke = s * 0.235;
    final double outerR = s * 0.5;
    final double ringR = outerR - stroke / 2;
    final Offset c = Offset(s / 2, s / 2);
    final Rect ring = Rect.fromCircle(center: c, radius: ringR);

    // Ring segments are split exactly at the diagonals (45°, 135°, 225°, 315°).
    void segment(double startDeg, double sweepDeg, Color color) {
      final Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = color;
      canvas.drawArc(ring, startDeg * pi / 180, sweepDeg * pi / 180, false, p);
    }

    // Screen angles (y-down): East=0, South=90, West=180, North=270.
    segment(315, 90, const Color(0xFF4285F4)); // right → blue (upper part)
    segment(45, 90, const Color(0xFF34A853)); // bottom-right → green
    segment(135, 90, const Color(0xFFFBBC05)); // bottom-left → yellow
    segment(225, 90, const Color(0xFFEA4335)); // top → red

    // Blue horizontal bar of the "G" from center to the outer edge.
    final Paint barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - stroke / 2, ringR + stroke / 2, stroke),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Signup
  bool _isForgotPassword = false; // Forgot Password flow

  /// Routes after a successful auth: gate mode goes to HomePage via the
  /// caller's callback, otherwise pop back to the previous screen.
  void _handleAuthSuccess() {
    if (!mounted) return;
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _profileImage = pickedFile;
        _profileImageBytes = bytes;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isForgotPassword) {
        await _authService.sendPasswordResetEmail(_emailController.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isForgotPassword = false;
          _isLogin = true;
        });
        return;
      }

      if (_isLogin) {
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('device_id');
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          deviceId: deviceId,
        );
        _handleAuthSuccess();
        return;
      }

      if (_profileImage == null) {
        if (mounted) {
          InAppNotification.show(
            context: context,
            message: 'برجاء اختيار صورة شخصية',
            type: NotificationType.error,
            icon: Icons.error_outline,
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final imageUrl = await CloudinaryService.uploadImage(_profileImage!);
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
        deviceId: deviceId,
        imageUrl: imageUrl,
      );
      try {
        await _authService.startTrial();
      } catch (e) {
        debugPrint("Error starting trial automatically: $e");
      }
      await _authService.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب. تم إرسال رابط التحقق إلى بريدك'),
            backgroundColor: Colors.green,
          ),
        );
        _handleAuthSuccess();
      }
    } catch (e) {
      String message = 'حدث خطأ غير متوقع، برجاء المحاولة لاحقاً';
      if (e is FirebaseAuthException) {
        debugPrint("Firebase Auth Error: ${e.code} - ${e.message}");
        switch (e.code) {
          case 'user-not-found':
          case 'invalid-email':
          case 'invalid-credential':
            message = 'خطأ في البريد الإلكتروني أو كلمة المرور';
            break;
          case 'wrong-password':
            message = 'كلمة المرور غير صحيحة';
            break;
          case 'email-already-in-use':
            message = 'هذا البريد الإلكتروني مسجل بالفعل';
            break;
          case 'weak-password':
            message = 'كلمة المرور ضعيفة جداً، يجب أن تكون 6 أحرف على الأقل';
            break;
          case 'network-request-failed':
            message = 'فشل الاتصال بالإنترنت، برجاء التأكد من الشبكة';
            break;
          case 'too-many-requests':
            message =
                'تم إرسال طلبات كثيرة جداً، برجاء الانتظار قليلاً والمحاولة لاحقاً';
            break;
          case 'user-disabled':
            message = 'تم تعطيل هذا الحساب، برجاء التواصل مع الدعم';
            break;
          case 'operation-not-allowed':
            message = 'هذه العملية غير مسموح بها حالياً';
            break;
          case 'unknown':
          case 'unknown-error':
          case 'internal-error':
            message = 'عفواً.. تأكد من صحة البريد وكلمة المرور وحاول مجدداً';
            break;
          default:
            message = 'بيانات الدخول غير صحيحة أو حدث خطأ في النظام';
        }
      } else {
        message = e.toString().replaceFirst('Exception: ', '');
      }

      if (mounted) {
        debugPrint("Auth Final Message: $message");
        InAppNotification.show(
          context: context,
          message: message,
          type: NotificationType.error,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialLogin(Future<UserCredential?> Function() loginMethod) async {
    setState(() => _isLoading = true);
    try {
      final cred = await loginMethod();
      if (cred != null) {
        _handleAuthSuccess();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final Map<String, String> socialErrors = {
          'popup-blocked': 'المتصفح منع نافذة جوجل — اسمح بالنوافذ المنبثقة',
          'popup-closed-by-user': '',
          'cancelled-popup-request': '',
          'unauthorized-domain':
              'الدومين غير مصرّح له في إعدادات Firebase (Authorized domains)',
          'operation-not-allowed': 'تسجيل الدخول بجوجل غير مفعّل حالياً',
          'network-request-failed': 'فشل الاتصال بالإنترنت',
        };
        final msg = socialErrors[e.code];
        if (msg != null && msg.isNotEmpty) {
          InAppNotification.show(
            context: context,
            message: msg,
            type: NotificationType.error,
            icon: Icons.error_outline,
          );
        } else if (msg == null) {
          InAppNotification.show(
            context: context,
            message: 'فشل تسجيل الدخول (${e.code})',
            type: NotificationType.error,
            icon: Icons.error_outline,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        InAppNotification.show(
          context: context,
          message: 'فشل تسجيل الدخول: $e',
          type: NotificationType.error,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildSocialButton({
    required String text,
    required Widget iconWidget,
    required Color backgroundColor,
    required Color foregroundColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: iconWidget,
        label: Text(
          text,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor ?? Colors.transparent, width: borderColor != null ? 1 : 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Dark Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Gate mode is the root route — there is nowhere to go back to.
        automaticallyImplyLeading: !widget.isInitialGate,
        leading: widget.isInitialGate
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '7eSen TV',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isForgotPassword
                        ? 'نسيت كلمة المرور'
                        : _isLogin
                            ? 'تسجيل الدخول'
                            : 'إنشاء حساب جديد',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Profile Image Picker (Only for Signup)
                  if (!_isLogin && !_isForgotPassword) ...[
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF1E1E1E),
                              backgroundImage: _profileImageBytes != null
                                  ? MemoryImage(_profileImageBytes!)
                                  : null,
                              child: _profileImageBytes == null
                                  ? const Icon(Icons.person,
                                      size: 50, color: Colors.grey)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.purple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // Name Field (Only for Signup & Not verifying)
                  if (!_isLogin && !_isForgotPassword) ...[
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.purple, width: 1),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'برجاء إدخال اسمك';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.purple, width: 1),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !value.contains('@')) {
                        return 'برجاء إدخال بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password Field (Only for Login/Signup)
                  if (!_isForgotPassword) ...[
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.purple, width: 1),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isForgotPassword = true;
                              _isLogin = false;
                            });
                          },
                          child: const Text('نسيت كلمة المرور؟',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Action Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673ab7), // Purple
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isForgotPassword
                              ? 'إرسال رابط إعادة التعيين'
                              : _isLogin
                                  ? 'دخول'
                                  : 'إنشاء حساب',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Toggle Button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_isForgotPassword) {
                          _isForgotPassword = false;
                          _isLogin = true;
                        } else {
                          _isLogin = !_isLogin;
                        }
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _isForgotPassword
                          ? 'الرجوع لتسجيل الدخول'
                          : _isLogin
                              ? 'ليس لديك حساب؟ سجل الآن'
                              : 'لديك حساب بالفعل؟ سجل الدخول',
                      style: const TextStyle(color: Colors.purpleAccent),
                    ),
                  ),

                  // Divider "or"
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('أو', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ),
                      Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Google Sign In Button
                  _buildSocialButton(
                    text: 'تسجيل الدخول بواسطة Google',
                    iconWidget: const _GoogleLogo(size: 22),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    onPressed: () => _handleSocialLogin(AuthService().signInWithGoogle),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
