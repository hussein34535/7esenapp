import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white),
            children: [
              const TextSpan(
                text: '7eSen TV Application\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: 'Last Updated: 2026-08-28\n\n',
              ),
              const TextSpan(
                text: 'Acceptance of Terms\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'By downloading, accessing, or using the 7eSen TV application or website (the "Service"), you agree to be bound by these Terms of Service ("Terms") and our Privacy Policy. If you do not agree with these Terms, you must not use the Service. You must be at least 13 years old (or the age of digital consent in your country) to use the Service, and at least 18 years old — or have the permission of a parent or guardian — to purchase a subscription.\n\n',
              ),
              const TextSpan(
                text: 'Description of the Service\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    '7eSen TV is a sports streaming service that provides access to live matches, replays, highlights, news, and related content. Some content is available free of charge, while other content requires an active paid subscription. Features and available content may change over time as we add, improve, or remove offerings.\n\n',
              ),
              const TextSpan(
                text: 'Subscriptions & Billing\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Paid plans are billed in advance on a recurring basis (for example, monthly or yearly depending on the plan you choose in the app). Payments, invoicing, and applicable taxes are processed by Paddle.com ("Paddle"), which acts as the Merchant of Record for your purchase. Charges may appear on your bank or card statement under the name Paddle or Paddle*7eSenTV. Prices are displayed in the app before you complete your purchase and may be changed with reasonable notice for future billing periods.\n\n',
              ),
              const TextSpan(
                text: 'Auto-Renewal & Cancellation\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Subscriptions automatically renew at the end of each billing cycle unless you cancel before the renewal date. You may cancel at any time from the app or by contacting us; your access continues until the end of the period you have already paid for. Cancelling stops future charges but does not automatically entitle you to a refund for the current period (see the ',
              ),
              TextSpan(
                text: 'Refund Policy',
                style: const TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse('https://web.7esentv.com/refund'));
                  },
              ),
              const TextSpan(
                text: ').\n\n',
              ),
              const TextSpan(
                text: 'Refunds\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Because Paddle acts as the Merchant of Record, refund requests are reviewed and issued by Paddle in accordance with our Refund Policy and applicable law. For details, see our ',
              ),
              TextSpan(
                text: 'Refund Policy',
                style: const TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse('https://web.7esentv.com/refund'));
                  },
              ),
              const TextSpan(
                text: ' and our ',
              ),
              TextSpan(
                text: 'Privacy Policy',
                style: const TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse('https://web.7esentv.com/privacy'));
                  },
              ),
              const TextSpan(
                text: '.\n\n',
              ),
              const TextSpan(
                text: 'Your License\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Subject to your compliance with these Terms, we grant you a limited, non-exclusive, non-transferable, revocable license to access the Service and view its content for personal, non-commercial use only. You may not copy, record, redistribute, resell, or publicly perform any content; share your account credentials; circumvent access controls or geographic restrictions; or scrape, reverse engineer, or otherwise misuse the Service or its underlying software.\n\n',
              ),
              const TextSpan(
                text: 'Intellectual Property\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'The Service and all of its content — including video, logos, branding, and software — are owned by 7eSen TV or its licensors and are protected by intellectual property laws. Broadcast and streaming rights belong to the respective rights holders, and unauthorized redistribution of content may be unlawful.\n\n',
              ),
              const TextSpan(
                text: 'Suspension & Termination\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'We may suspend or terminate your access to the Service if you materially breach these Terms (including credential sharing, payment fraud, or unlawful use). You may stop using the Service at any time. Provisions that by their nature should survive termination — such as intellectual property, disclaimers, and limitation of liability — will continue to apply.\n\n',
              ),
              const TextSpan(
                text: 'Disclaimer of Warranties\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'The Service is provided "as is" and "as available", without warranties of any kind, whether express or implied. Stream availability depends on third-party sources and broadcasters, and we do not warrant that the Service will be uninterrupted, error-free, or that content will be available at all times.\n\n',
              ),
              const TextSpan(
                text: 'Limitation of Liability\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'To the maximum extent permitted by law, 7eSen TV shall not be liable for any indirect, incidental, special, consequential, or punitive damages, and our total aggregate liability shall not exceed the amounts you paid for the Service in the twelve (12) months preceding the claim (or the fees for your current subscription period, if shorter).\n\n',
              ),
              const TextSpan(
                text: 'Changes to These Terms\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'We may update these Terms from time to time. Changes will be reflected on this page and may be notified through the app. Your continued use of the Service after changes take effect constitutes acceptance of the updated Terms.\n\n',
              ),
              const TextSpan(
                text: 'Governing Law\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'These Terms are governed by the laws of [Your Jurisdiction — please replace with your place of business], without regard to its conflict-of-laws principles. Mandatory consumer protections of your country of residence still apply where required by law.\n\n',
              ),
              const TextSpan(
                text: 'Contact Us\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'If you have any questions about these Terms, please contact us at support@7esentv.com.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
