import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import FontAwesome

void showTelegramDialog(BuildContext context, {String? userName}) {
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
              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
              width: 1), // Add border
        ),
        content: Column(
          // Use Column to display text on separate lines
          mainAxisSize: MainAxisSize.min, // Ensure Column takes minimum space
          children: [
            // Display user name if available
            if (userName != null && userName.isNotEmpty)
              Flexible(
                // Wrap with Flexible to allow text to wrap/ellipsis
                child: Directionality(
                  textDirection: TextDirection.rtl, // Force RTL direction
                  child: FittedBox(
                    // Added FittedBox to make text shrink to fit
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      textAlign: TextAlign.center,
                      // Removed maxLines and overflow as FittedBox will handle scaling
                      // maxLines: 1,
                      // overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        // Default style for all parts of the text
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        children: [
                          TextSpan(
                            text: 'كيف حالك يا ',
                          ),
                          TextSpan(
                            text: userName,
                            style: TextStyle(
                              color: Colors.purple.shade400, // Purple color
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              // Removed overflow as FittedBox will handle scaling
                              // overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextSpan(
                            text: ' أتمنى أن تكون بخير ❤️',
                            style: TextStyle(
                              fontSize:
                                  18, // Slightly smaller for the trailing text
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: 16),
            // "Pray upon the Prophet" container
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 8.0), // Add padding
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.3), // Transparent background
                borderRadius: BorderRadius.circular(20.0), // Oval shape
              ),
              child: FittedBox(
                // Added FittedBox to make text shrink to fit
                fit: BoxFit.scaleDown,
                child: Text(
                  'اللهم صل وسلم وبارك على سيدنا محمد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center, // Center align buttons
        actions: <Widget>[
          TextButton(
            child: Text(
              'إغلاق', // Changed text from "لاحقاً" to "إغلاق"
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
            icon:
                Icon(FontAwesomeIcons.telegram, size: 18), // Add telegram icon
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
              try {
                if (await canLaunchUrl(telegramUrl)) {
                  await launchUrl(telegramUrl,
                      mode: LaunchMode.externalApplication);
                } else {
                  // print('Could not launch Telegram URL');
                }
              } catch (e) {
                // Handle error if Telegram URL can't be launched
                // print('Could not launch Telegram URL');
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
