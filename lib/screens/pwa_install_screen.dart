import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hesen/utils/pwa/pwa_helper.dart'; // Import helper

class PwaInstallScreen extends StatefulWidget {
  const PwaInstallScreen({Key? key}) : super(key: key);

  @override
  State<PwaInstallScreen> createState() => _PwaInstallScreenState();
}

class _PwaInstallScreenState extends State<PwaInstallScreen> {
  bool _isIOS = false;

  @override
  void initState() {
    super.initState();
    _checkPlatform();
  }

  void _checkPlatform() {
    setState(() {
      _isIOS = isIOS();
    });
  }

  void _installPwa() {
    triggerInstallPrompt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C52D8), // Main Purple
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C52D8).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: const Icon(Icons.download_rounded,
                    color: Colors.white, size: 50),
              ),
              const SizedBox(height: 40),

              Text(
                'تثبيت التطبيق مطلوب',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'للحصول على أفضل تجربة ومشاهدة القنوات، يرجى تثبيت التطبيق على هاتفك.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Detection based UI
              if (_isIOS) ...[
                _buildStep(1, 'اضغط على زر المشاركة', Icons.ios_share),
                _buildStep(2, 'اختر "إضافة إلى الشاشة الرئيسية"',
                    Icons.add_box_outlined),
                _buildStep(3, 'اضغط على "إضافة" (Add)', Icons.add),
              ] else ...[
                // Android / Chrome
                InkWell(
                  onTap: _installPwa,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C52D8), Color(0xFF5E3CB5)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C52D8).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.install_mobile, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'تثبيت التطبيق',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'أو اضغط على القائمة (Three Dots) واختر "Install App"',
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center for better look
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white24,
            child: Text('$number',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
          const SizedBox(width: 8),
          Icon(icon, color: Colors.white70, size: 20),
        ],
      ),
    );
  }
}
