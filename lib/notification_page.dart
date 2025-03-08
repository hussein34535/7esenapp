import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({Key? key}) : super(key: key); // Added Key? key

  @override
  Widget build(BuildContext context) {
    final message = ModalRoute.of(context)?.settings.arguments
        as RemoteMessage?; // Added null safety

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notification Details"), // عنوان أكثر وضوحًا
      ),
      body: message == null // معالجة حالة الرسالة الفارغة
          ? const Center(
              child: Text("No notification data available."),
            )
          : SingleChildScrollView(
              // لجعل الواجهة قابلة للتمرير إذا كان المحتوى طويلًا
              padding: const EdgeInsets.all(16.0),
              child: Card(
                // استخدام Card لتجميع معلومات الإشعار
                elevation: 5.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // محاذاة العناصر لليسار
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSectionTitle("Notification Title"), // عنوان القسم
                      _buildDetailText(message.notification?.title ??
                          "N/A"), // عرض العنوان مع قيمة افتراضية
                      const SizedBox(height: 12),

                      _buildSectionTitle("Notification Body"), // عنوان القسم
                      _buildDetailText(message.notification?.body ??
                          "N/A"), // عرض المحتوى مع قيمة افتراضية
                      const SizedBox(height: 12),

                      _buildSectionTitle("Data Payload"), // عنوان القسم
                      _buildDataPayloadSection(
                          message.data), // دالة منفصلة لعرض البيانات
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // دالة مساعدة لبناء عناوين الأقسام
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  // دالة مساعدة لعرض النصوص التفصيلية
  Widget _buildDetailText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  // دالة مساعدة لعرض حمولة البيانات بشكل منظم
  Widget _buildDataPayloadSection(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Text("No data payload included.");
    }
    return ListView.builder(
      // استخدام ListView.builder لعرض البيانات بشكل منظم
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // لمنع التمرير داخل Card
      itemCount: data.keys.length,
      itemBuilder: (context, index) {
        final key = data.keys.elementAt(index);
        final value = data[key];
        return ListTile(
          title: Text("$key:",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(value.toString()),
        );
      },
    );
  }
}
