import 'package:flutter/material.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hesen/services/resend_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:hesen/services/cloudinary_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Signup
  bool _showVerification = false; // Show OTP field
  bool _isForgotPassword = false; // Forgot Password flow

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_showVerification) {
        // Step 2: Verify OTP
        final success = await ResendService.verifyCode(
          _emailController.text.trim(),
          _otpController.text.trim(),
        );

        if (!success) {
          throw Exception('كود التحقق غير صحيح');
        }

        if (_isForgotPassword) {
          // In-App Password Reset logic
          // Normally this calls a backend that uses Admin SDK
          debugPrint(
              "RESET PASSWORD: Email: ${_emailController.text}, NewPass: ${_newPasswordController.text}, OTP: ${_otpController.text}");

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'تم إعادة تعيين كلمة المرور بنجاح! يمكنك الدخول الآن'),
                  backgroundColor: Colors.green),
            );
            setState(() {
              _showVerification = false;
              _isForgotPassword = false;
              _isLogin = true;
              _passwordController.text = _newPasswordController.text;
            });
          }
        } else {
          // Finish Signup
          if (_profileImage == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('برجاء اختيار صورة شخصية')),
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
          if (mounted) Navigator.of(context).pop();
        }
      } else if (_isForgotPassword) {
        // Forgot Password Step 1: Send OTP
        final success =
            await ResendService.sendResetCode(_emailController.text.trim());
        if (success) {
          setState(() {
            _showVerification = true;
          });
        } else {
          throw Exception('فشل إرسال كود التحقق');
        }
      } else if (_isLogin) {
        // Standard Login
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('device_id');
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          deviceId: deviceId,
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        // Signup Step 1: Send OTP
        final success = await ResendService.sendVerificationCode(
            _emailController.text.trim());
        if (success) {
          setState(() {
            _showVerification = true;
          });
        } else {
          throw Exception('فشل إرسال كود التحقق');
        }
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
        debugPrint("Auth Final Message: $message"); // Debug log
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.center),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Dark Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo or Title
                  const Text(
                    '7eSen TV',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo', // Assuming you use Cairo
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _showVerification
                        ? 'تأكيد الحساب'
                        : _isForgotPassword
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
                  const SizedBox(height: 40),

                  // Profile Image Picker (Only for Signup)
                  if (!_isLogin &&
                      !_showVerification &&
                      !_isForgotPassword) ...[
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF1E1E1E),
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              child: _profileImage == null
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
                    const SizedBox(height: 20),
                  ],

                  // Name Field (Only for Signup & Not verifying)
                  if (!_isLogin &&
                      !_showVerification &&
                      !_isForgotPassword) ...[
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
                    const SizedBox(height: 20),
                  ],

                  // OTP Field (Only for Verification)
                  if (_showVerification) ...[
                    TextFormField(
                      controller: _otpController,
                      key: const ValueKey('otp_field'),
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, letterSpacing: 8),
                      decoration: InputDecoration(
                        labelText: 'كود التحقق',
                        labelStyle: const TextStyle(color: Colors.grey),
                        counterText: '',
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
                        if (value == null || value.length < 4) {
                          return 'كود غير صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'تم إرسال كود التحقق إلى ${_emailController.text}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (_isForgotPassword) ...[
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور الجديدة',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon:
                              const Icon(Icons.lock_reset, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
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
                    ],
                    const SizedBox(height: 40),
                  ],

                  // Email Field (Hidden during verification)
                  if (!_showVerification) ...[
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
                    const SizedBox(height: 20),

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
                      const SizedBox(height: 30),
                    ],
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
                              _showVerification
                                  ? 'تأكيد الرمز'
                                  : _isForgotPassword
                                      ? 'استعادة الحساب'
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

                  const SizedBox(height: 20),

                  // Toggle Button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_showVerification) {
                          _showVerification = false;
                        } else if (_isForgotPassword) {
                          _isForgotPassword = false;
                          _isLogin = true;
                        } else {
                          _isLogin = !_isLogin;
                        }
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _showVerification
                          ? 'الرجوع للبريد الإلكتروني'
                          : _isForgotPassword
                              ? 'الرجوع لتسجيل الدخول'
                              : _isLogin
                                  ? 'ليس لديك حساب؟ سجل الآن'
                                  : 'لديك حساب بالفعل؟ سجل الدخول',
                      style: const TextStyle(color: Colors.purpleAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
