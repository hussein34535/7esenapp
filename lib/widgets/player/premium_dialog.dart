import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumDialog extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final User? currentUser;

  const PremiumDialog({
    Key? key,
    required this.userData,
    required this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool trialUsed = userData?['trialUsed'] == true;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium,
                color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('محتوى بريميوم',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'هذا المحتوى متاح فقط للمشتركين في الباقات المميزة.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          // Option 1: Trial (If available)
          if (currentUser != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: Text(trialUsed
                  ? 'تم استخدام التجربة المجانية'
                  : 'بدء تجربة 3 أيام مجاناً'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: trialUsed ? null : () => Navigator.pop(context, 1),
            ),
          const SizedBox(height: 12),
          // Option 2: Subscribe
          ElevatedButton.icon(
            icon: const Icon(Icons.star, size: 18),
            label: const Text('اشترك الآن لتفعيل البريميوم'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF673ab7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, 2),
          ),
          const SizedBox(height: 12),
          // Option 3: Free Quality (SD)
          OutlinedButton.icon(
            icon: const Icon(Icons.tv, size: 18),
            label: const Text('مشاهدة الجودات المجانية (SD)'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade700),
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, 3),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
