import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

class ResendService {
  static const String _resendApiUrl = 'https://api.resend.com/emails';

  // In-memory store for OTPs (Email -> Code)
  // For production, this should be handled on a backend.
  static final Map<String, String> _otpCache = {};

  /// Sends a verification code to the specified email using Resend.
  static Future<bool> sendVerificationCode(String email) async {
    final apiKey = dotenv.env['RESEND_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("ResendService Error: RESEND_API_KEY not found in .env");
      return false;
    }

    // Generate 6-digit OTP
    final code = (Random().nextInt(900000) + 100000).toString();
    _otpCache[email] = code;

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '7eSen TV <auth@7esentv.com>',
          'to': [email],
          'subject': 'كود التحقق - 7eSen TV',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
              <h1 style="color: #673ab7; text-align: center;">7eSen TV</h1>
              <p style="font-size: 16px; color: #333;">مرحباً بك!</p>
              <p style="font-size: 16px; color: #333;">كود التحقق الخاص بك هو:</p>
              <div style="background: #f4f4f4; padding: 20px; text-align: center; border-radius: 5px;">
                <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #673ab7;">$code</span>
              </div>
              <p style="font-size: 14px; color: #777; margin-top: 20px; text-align: center;">هذا الكود صالح لمدة 10 دقائق.</p>
            </div>
          ''',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
            "ResendService: Verification code sent successfully to $email");
        return true;
      } else if (response.statusCode == 403) {
        debugPrint(
            "ResendService Error: 403 - الحساب في وضع الاختبار. يجب تفعيل الدومين في Resend لإرسال إيميلات لأشخاص آخرين.");
        return false;
      } else {
        debugPrint(
            "ResendService Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("ResendService Exception (sendCode): $e");
      return false;
    }
  }

  /// Verifies the code sent to the email.
  static Future<bool> verifyCode(String email, String code) async {
    if (_otpCache.containsKey(email) && _otpCache[email] == code) {
      _otpCache.remove(email); // Code used
      return true;
    }
    return false;
  }

  /// Sends a password reset code.
  static Future<bool> sendResetCode(String email) async {
    return sendVerificationCode(email); // Reuse the same logic for now
  }

  /// Notifies the admin about a new payment submission.
  static Future<bool> sendAdminPaymentNotification({
    required String userEmail,
    required String packageName,
    required String imageUrl,
    String? paymentIdentifier,
  }) async {
    final apiKey = dotenv.env['RESEND_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '7eSen TV <payments@7esentv.com>',
          'to': [
            'admin@7esentv.com'
          ], // Replace with actual admin email if different
          'subject': 'طلب دفع جديد - $userEmail',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
              <h2 style="color: #673ab7;">طلب فتح اشتراك جديد</h2>
              <p><strong>المستخدم:</strong> $userEmail</p>
              <p><strong>الباقة:</strong> $packageName</p>
              <p><strong>الرقم التعريفي:</strong> ${paymentIdentifier ?? 'غير متوفر'}</p>
              <p><strong>صورة الإيصال:</strong></p>
              <div style="margin-top: 10px;">
                <img src="$imageUrl" style="max-width: 100%; border-radius: 5px;" alt="Receipt" />
              </div>
              <p style="margin-top: 20px;">يرجى مراجعة الطلب في لوحة التحكم وتفعيل الحساب.</p>
            </div>
          ''',
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("ResendService Exception (adminNotify): $e");
      return false;
    }
  }

  /// Sends a welcome/activation email to the user.
  static Future<bool> sendUserActivationNotification(String email) async {
    final apiKey = dotenv.env['RESEND_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '7eSen TV <support@7esentv.com>',
          'to': [email],
          'subject': 'تم تفعيل اشتراكك - 7eSen TV',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px; text-align: center;">
              <h1 style="color: #4CAF50;">مبارك! تم تفعيل اشتراكك</h1>
              <p style="font-size: 16px; color: #333;">تمت مراجعة طلبك وتفعيل مميزات البريميوم في حسابك.</p>
              <div style="background: #e8f5e9; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p style="font-size: 18px; color: #2e7d32; font-weight: bold;">استمتع بمشاهدة ممتعة لجميع القنوات والمباريات الحصرية</p>
              </div>
              <p style="font-size: 14px; color: #777;">إذا كان التطبيق مفتوحاً، يرجى إعادة تشغيله لتفعيل المميزات فوراً.</p>
            </div>
          ''',
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("ResendService Exception (userNotify): $e");
      return false;
    }
  }
}
