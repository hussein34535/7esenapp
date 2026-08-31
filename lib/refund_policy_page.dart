import 'package:flutter/material.dart';

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Policy'),
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
                text: 'Overview\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Payments for 7eSen TV subscriptions are processed by Paddle.com, which acts as the Merchant of Record for your purchase. This means Paddle issues approved refunds on our behalf. You can request a refund by contacting us at support@7esentv.com or by using the support link included in your Paddle receipt email.\n\n',
              ),
              const TextSpan(
                text: 'Refund Eligibility\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'We work with Paddle to approve refunds in the following situations:\n\n',
              ),
              const TextSpan(
                text:
                    '*   **Technical faults:** A persistent issue prevents you from accessing the Service and we cannot resolve it within a reasonable time.\n',
              ),
              const TextSpan(
                text:
                    '*   **Billing errors:** Accidental duplicate charges or clearly unintended purchases reported promptly.\n',
              ),
              const TextSpan(
                text:
                    '*   **Statutory rights:** Where your local law grants a right of withdrawal or refund for digital services (for example, the EU 14-day right of withdrawal), that right applies.\n',
              ),
              const TextSpan(
                text:
                    '*   **Other fair cases:** Other situations we consider fair at our discretion, such as dissatisfaction reported within 14 days of your first charge.\n\n',
              ),
              const TextSpan(
                text: 'How to Request a Refund\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Email support@7esentv.com with the email address on your account and your order or receipt details, or use the "Get support" link in the receipt email you received from Paddle. Requests are typically answered within 1–2 business days.\n\n',
              ),
              const TextSpan(
                text: 'Processing Time\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Approved refunds are issued by Paddle to the original payment method and typically appear within 3–10 business days, depending on your bank or card issuer.\n\n',
              ),
              const TextSpan(
                text: 'Non-Refundable Situations\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: 'Unless required by law, refunds are generally not granted for:\n\n',
              ),
              const TextSpan(
                text:
                    '*   **Partial periods:** The remainder of a billing period after cancellation (your access continues until the period ends).\n',
              ),
              const TextSpan(
                text:
                    '*   **Extensive use:** Requests made long after the charge where the subscription has been substantially used.\n',
              ),
              const TextSpan(
                text:
                    '*   **Abuse:** Repeated or abusive refund requests.\n',
              ),
              const TextSpan(
                text:
                    '*   **Individual content:** Temporary unavailability of individual matches or channels, where the Service as a whole remained available.\n\n',
              ),
              const TextSpan(
                text: 'Chargebacks\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'Please contact us before opening a dispute with your bank — we can usually resolve issues faster. Fraudulent or abusive chargebacks may result in suspension of your account.\n\n',
              ),
              const TextSpan(
                text: 'Changes to This Policy\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'We may update this Refund Policy periodically. The current version will always be available on this page.\n\n',
              ),
              const TextSpan(
                text: 'Contact Us\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    'If you have any questions about this policy, please contact us at support@7esentv.com.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
