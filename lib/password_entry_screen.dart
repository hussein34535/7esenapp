import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:hesen/video_player_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PasswordEntryScreen extends StatefulWidget {
  final VoidCallback onCorrectInput;
  final SharedPreferences prefs;

  PasswordEntryScreen(
      {Key? key, required this.onCorrectInput, required this.prefs})
      : super(key: key);

  @override
  _PasswordEntryScreenState createState() => _PasswordEntryScreenState();
}

class _PasswordEntryScreenState extends State<PasswordEntryScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false;
  final String correctInput = "0127";
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {}); // Rebuild when focus changes
    });
  }

  void _checkInput() async {
    setState(() {
      _isLoading = true;
    });

    String input = _inputController.text.trim();

    if (input == correctInput) {
      await widget.prefs.setBool('isFirstTime', false);
      widget.onCorrectInput();
    } else if (Uri.tryParse(input) != null &&
        (input.startsWith('http://') || input.startsWith('https://'))) {
      _openVideoFromUrl(input);
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid input. Please try again.')),
      );
    }
  }

  void _openVideoFromUrl(String url) {
    setState(() {
      _isLoading = false;
    });
    if (url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VideoPlayerScreen(initialUrl: url, streamLinks: []),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a URL.')),
      );
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
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
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
                        'Enter IPTV URL',
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
                          labelText: _focusNode.hasFocus ? '' : 'URL',
                          labelStyle: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: Icon(Icons.link),
                          filled: true,
                          fillColor: _focusNode.hasFocus
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2.0)),
                        ),
                        style: TextStyle(
                          color:
                              _focusNode.hasFocus ? Colors.white : Colors.black,
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _checkInput,
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Submit', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Telegram Button
                      ElevatedButton.icon(
                        icon: FaIcon(FontAwesomeIcons.telegram, size: 20),
                        label: Text('Telegram للمساعدة',
                            style: TextStyle(fontSize: 16)),
                        onPressed: () async {
                          final Uri telegramUri =
                              Uri.parse('https://t.me/tv_7esen');
                          try {
                            await launchUrl(telegramUri,
                                mode: LaunchMode.externalApplication);
                          } catch (e) {
                            print('Error launching URL in external app: $e');
                            try {
                              await launchUrl(telegramUri,
                                  mode: LaunchMode.inAppWebView);
                            } catch (e) {
                              print('Error launching URL in browser: $e');
                            }
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
          ),
          // Privacy Policy at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PrivacyPolicyPage()),
                );
              },
              child: Text(
                'View Privacy Policy',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
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
