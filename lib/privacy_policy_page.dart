import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge!.color),
            children: [
              TextSpan(
                text: '7eSen TV Application\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: 'Last Updated: 2023-11-19\n\n',
              ),
              TextSpan(
                text: 'Introduction\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    '7eSen TV ("the App") respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, and safeguard your information when you use our app.\n\n',
              ),
              TextSpan(
                text: 'Information We Collect\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    '7eSen TV does not collect any personally identifiable information (PII) such as name, email, or phone number.\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'However, we may collect non-personal data automatically, such as:\n\n',
              ),
              TextSpan(
                text:
                    '*   **Usage Data:** Information on how you use the app, such as pages visited, features used, and session duration.\n',
              ),
              TextSpan(
                text:
                    '*   **Device Information:** Device type, OS, unique device ID (UDID), IP address.\n\n',
              ),
              TextSpan(
                text: 'Third-Party Services:\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    '*   **Firebase:** We use Firebase services from Google to send important notifications to users. Firebase may collect certain data for analytics and service improvement. You can review Firebase\'s privacy policy here: ',
              ),
              TextSpan(
                text: 'https://policies.google.com/privacy',
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse('https://policies.google.com/privacy'));
                  },
              ),
              TextSpan(text: '\n\n'),
              TextSpan(
                text: 'How We Use the Information\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    '*   **App Improvement:** Enhancing user experience and developing new features.\n',
              ),
              TextSpan(
                text:
                    '*   **Trend Analysis:** Understanding general usage patterns.\n',
              ),
              TextSpan(
                text:
                    '*   **Push Notifications:** Sending important updates via Firebase.\n\n',
              ),
              TextSpan(
                text: 'Information Sharing\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'We **do not share any personally identifiable information** as our app does not collect such data.\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'Non-personal data may be shared with third-party services (e.g., Firebase) within the scope of their services.\n\n',
              ),
              TextSpan(
                text: 'Data Security\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'We take reasonable security measures to protect collected data. However, no security system is completely foolproof.\n\n',
              ),
              TextSpan(
                text: 'Changes to This Policy\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'We may update this Privacy Policy periodically. Changes will be notified through the app or on this page.\n\n',
              ),
              TextSpan(
                text: 'Children’s Privacy\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'Our app is not intended for children under 13. If you believe a child has provided personal data, please contact us to remove it.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
