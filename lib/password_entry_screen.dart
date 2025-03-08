import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hesen/main.dart';

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
        Navigator.pushReplacementNamed(
            context, '/home'); // Navigate using named route
      }
    } else {
      setState(() => _showError = input.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('7eSen TV'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      SizedBox(height: 30),
                      Text(
                        'Enter URL Code',
                        style: TextStyle(
                            fontSize: 18,
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          labelText: _focusNode.hasFocus ? null : 'URL',
                          labelStyle: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: Icon(
                              Icons
                                  .link, // تم تغيير الأيقونة إلى Icons.key (مفتاح)
                              color: Theme.of(context).iconTheme.color),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.secondary,
                                width: 2.0),
                          ),
                          errorText: _showError ? 'Invalid input' : null,
                          errorStyle: TextStyle(color: Colors.red),
                        ),
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color),
                        keyboardType: TextInputType.text,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _checkInput,
                        child: Text('Submit', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: FaIcon(FontAwesomeIcons.telegram, size: 20),
                        label: Text('Telegram للمساعدة',
                            style: TextStyle(fontSize: 16)),
                        onPressed: () async {
                          final Uri telegramUri =
                              Uri.parse('https://t.me/tv_7esen');
                          if (await canLaunchUrl(telegramUri)) {
                            await launchUrl(telegramUri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            print('Could not launch $telegramUri');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PrivacyPolicyPage()),
                  );
                },
                child: Text(
                  'View Privacy Policy',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.secondary),
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
