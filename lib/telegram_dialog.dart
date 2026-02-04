import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import FontAwesome

void showTelegramDialog(BuildContext context, {String? userName}) {
  final theme = Theme.of(context);
  final secondaryColor = theme.colorScheme.secondary;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(
            color: secondaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        content: Directionality(
          textDirection:
              TextDirection.rtl, // Correct Arabic flow and punctuation
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.end, // Aligns to the physical LEFT in RTL
            children: [
              // Welcome Message
              RichText(
                textAlign: TextAlign.center, // Center text
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: theme.textTheme.bodyLarge?.color,
                    fontFamily: 'Cairo', // Use app font
                  ),
                  children: [
                    const TextSpan(text: 'كيف حالك يا '),
                    TextSpan(
                      text: userName ?? 'صديقي',
                      style: TextStyle(
                        color: secondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                    const TextSpan(text: '؟'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'أتمنى أن تكون بخير وفي أفضل حال ❤️\nصل على النبي',
                textAlign: TextAlign.center, // Center text
                style: TextStyle(
                  fontSize: 16,
                  color:
                      theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        actionsAlignment: MainAxisAlignment.start,
        actions: <Widget>[
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'إغلاق',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color
                          ?.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final telegramUrl = Uri.parse('https://t.me/tv_7esen');
                    try {
                      if (await canLaunchUrl(telegramUrl)) {
                        await launchUrl(telegramUrl,
                            mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {}
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(FontAwesomeIcons.telegram, size: 18),
                  label: const Text('انضم للتيليجرام'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
