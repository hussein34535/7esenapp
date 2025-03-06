import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/privacy_policy_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hesen/main.dart'; // Import main.dart to access HomePage

class PasswordEntryScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final VoidCallback? onCorrectInput; // Callback for correct input

  PasswordEntryScreen({Key? key, required this.prefs, this.onCorrectInput})
      : super(key: key);

  @override
  _PasswordEntryScreenState createState() => _PasswordEntryScreenState();
}

class _PasswordEntryScreenState extends State<PasswordEntryScreen> {
  final TextEditingController _inputController = TextEditingController();
  final String correctInput = "0127"; // Keep the correct input here
  final _focusNode = FocusNode();
  bool _showError = false;
  bool _obscureText = true; // Added for password visibility toggle

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  void _checkInput() async {
    String input = _inputController.text.trim();
    if (input == correctInput) {
      await widget.prefs.setBool('isFirstTime', false);
      widget.onCorrectInput
          ?.call(); // Use null-aware call.  IMPORTANT for integration with MyApp.
      // Check if the route is still mounted before navigating
      if (mounted) {
        // Use mounted check
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => HomePage(
                    onThemeChanged: (bool) {},
                    themeMode: ThemeMode.system,
                  )),
        );
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
        automaticallyImplyLeading: false, // Remove the back button
      ),
      body: Container(
        // Wrap the Column with a Container
        color:
            Theme.of(context).scaffoldBackgroundColor, // Set background color
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
                        'Enter URL Code', // Or 'Enter Password', as appropriate
                        style: TextStyle(
                            fontSize: 18,
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        obscureText:
                            _obscureText, // Use the obscureText variable
                        decoration: InputDecoration(
                          labelText: _focusNode.hasFocus
                              ? null
                              : 'URL', // Hide when focused
                          labelStyle: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: Icon(Icons.lock, // Changed to a lock icon
                              color: Theme.of(context).iconTheme.color),
                          suffixIcon: IconButton(
                            // Added suffixIcon for visibility toggle
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText =
                                    !_obscureText; // Toggle visibility
                              });
                            },
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey
                                      .shade800 // Darker fill for dark mode
                                  : Colors.grey
                                      .shade200, // Lighter fill for light mode
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.secondary,
                                width: 2.0),
                          ),
                          errorText: _showError ? 'Invalid input' : null,
                          errorStyle: TextStyle(
                              color: Colors.red), // Style the error text
                        ),
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color),
                        keyboardType:
                            TextInputType.text, // Changed to TextInputType.text
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
                            // Optionally show an error message to the user.
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
