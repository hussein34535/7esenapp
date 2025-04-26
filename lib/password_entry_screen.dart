import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hesen/main.dart';
import 'package:pinput/pinput.dart';

class PasswordEntryScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final VoidCallback? onCorrectInput;

  PasswordEntryScreen({Key? key, required this.prefs, this.onCorrectInput})
      : super(key: key);

  @override
  _PasswordEntryScreenState createState() => _PasswordEntryScreenState();
}

class _PasswordEntryScreenState extends State<PasswordEntryScreen> {
  final TextEditingController _inputController = TextEditingController();
  final String correctInput = "0127";
  final _focusNode = FocusNode();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  void _checkInput() async {
    String input = _inputController.text.trim();
    if (input == correctInput) {
      await widget.prefs.setBool('isFirstTime', false);
      widget.onCorrectInput?.call();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() => _showError = input.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // REMOVED AppBar
      // appBar: AppBar(
      //   title: Text('7eSen TV'),
      //   backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      //   automaticallyImplyLeading: false,
      // ),
      backgroundColor: Colors.black, // Set background to black
      body: Container(
        // REMOVED BoxDecoration with gradient
        // decoration: BoxDecoration(...),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '7eSen TV',
                        style: TextStyle(
                            fontSize: 36, // Increased size
                            fontWeight: FontWeight.w600, // Slightly less bold
                            color: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.color ??
                                Theme.of(context)
                                    .colorScheme
                                    .primary, // Use headline color or primary
                            shadows: [
                              // Add a subtle shadow
                              Shadow(
                                blurRadius: 4.0,
                                color: Colors.black.withOpacity(0.3),
                                offset: Offset(2.0, 2.0),
                              ),
                            ]),
                      ),
                      SizedBox(height: 30),
                      Text(
                        'Enter The Code',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      SizedBox(height: 30),
                      Pinput(
                        controller: _inputController,
                        length: 4,
                        obscureText: false,
                        defaultPinTheme: PinTheme(
                          width: 56,
                          height: 60,
                          textStyle:
                              TextStyle(fontSize: 22, color: Colors.white),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                        ),
                        focusedPinTheme: PinTheme(
                          width: 56,
                          height: 60,
                          textStyle:
                              TextStyle(fontSize: 22, color: Colors.white),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.secondary),
                          ),
                        ),
                        submittedPinTheme: PinTheme(
                          width: 56,
                          height: 60,
                          textStyle:
                              TextStyle(fontSize: 22, color: Colors.white),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        validator: (s) {
                          if (s == null || s.length != 4) {
                            return 'Code must be 4 digits';
                          }
                          return null;
                        },
                        onCompleted: (pin) => _checkInput(),
                      ),
                      SizedBox(height: 20), // Space below Pinput
                      ElevatedButton(
                        onPressed: _checkInput,
                        child: Text('Submit', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary, // Use primary color
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onPrimary, // Text color on primary
                          padding: EdgeInsets.symmetric(
                              horizontal: 50,
                              vertical: 16), // Slightly larger padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                25.0), // Set radius to 25.0
                          ),
                          elevation: 5, // Add elevation
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Position Telegram button below Expanded content with specific padding
            Padding(
              padding: const EdgeInsets.only(
                  left: 20.0, right: 20.0, top: 10.0, bottom: 30.0),
              child: ElevatedButton.icon(
                icon: FaIcon(FontAwesomeIcons.telegram, size: 20),
                label: Text('Telegram الكود من هنا',
                    style: TextStyle(fontSize: 16)),
                onPressed: () async {
                  final Uri telegramUri = Uri.parse('https://t.me/tv_7esen');
                  if (await canLaunchUrl(telegramUri)) {
                    await launchUrl(telegramUri,
                        mode: LaunchMode.externalApplication);
                  } else {
                    // print('Could not launch $telegramUri');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0088cc), // Specific Telegram blue
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: 25, vertical: 12), // Adjust padding
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(25.0)), // Set radius to 25.0
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
