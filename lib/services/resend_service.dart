import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ResendService {
  static const String _resendApiUrl = 'https://api.resend.com/emails';

  /// Notifies the admin about a new payment submission.
  static Future<bool> sendAdminPaymentNotification({
    required String userEmail,
    required String packageName,
    required String imageUrl,
    String? paymentIdentifier,
  }) async {
    const apiKey = String.fromEnvironment('RESEND_API_KEY');
    if (apiKey.isEmpty) return false;

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
          ],
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
    const apiKey = String.fromEnvironment('RESEND_API_KEY');
    if (apiKey.isEmpty) return false;

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
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("ResendService Exception (userNotify): $e");
      return false;
    }
  }
}
