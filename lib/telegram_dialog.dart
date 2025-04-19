import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import FontAwesome

void showTelegramDialog(BuildContext context) {
  final theme = Theme.of(context); // Get theme data

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: theme.cardColor, // Use theme card color
        shape: RoundedRectangleBorder(
          // Add rounded corners and a border
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(
              color: theme.colorScheme.secondary.withOpacity(0.5),
              width: 1), // Add border
        ),
        title: Center(
          // Center the title Row
          child: Row(
            mainAxisSize:
                MainAxisSize.min, // Ensure Row takes minimum space needed
            // Add Telegram icon next to title
            children: [
              Icon(FontAwesomeIcons.telegramPlane,
                  color: Colors.blue, // Set icon color to blue
                  size: 24),
              SizedBox(width: 10),
              Text(
                'انضم لقناتنا على التيليجرام',
                style: TextStyle(
                  color:
                      theme.textTheme.bodyLarge!.color, // Use theme text color
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ), // End Center
        content: Text(
          'تابع آخر الأخبار والتحديثات من خلال الانضمام لقناتنا على التيليجرام!',
          textAlign: TextAlign.center, // Center align content
          style: TextStyle(
              color: theme.textTheme.bodyMedium!.color), // Use theme text color
        ),
        actionsAlignment: MainAxisAlignment.center, // Center align buttons
        actions: <Widget>[
          TextButton(
            child: Text(
              'لاحقاً', // Changed text to "Later"
              style: TextStyle(
                  color: Colors.blue), // Set button text color to blue
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          SizedBox(width: 10), // Add space between buttons
          ElevatedButton.icon(
            // Use ElevatedButton.icon for Join button
            icon: Icon(Icons.send_rounded, size: 18), // Add send icon
            label: Text('انضم للتيليجرام'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  theme.colorScheme.secondary, // Use theme secondary color
              foregroundColor: Colors.white, // White text
              shape: RoundedRectangleBorder(
                // Rounded corners for button
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onPressed: () async {
              final telegramUrl = Uri.parse('https://t.me/tv_7esen');
              if (await canLaunchUrl(telegramUrl)) {
                await launchUrl(telegramUrl);
              } else {
                // Handle error if Telegram URL can't be launched
                print('Could not launch Telegram URL');
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
