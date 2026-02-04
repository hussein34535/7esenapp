import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _baseUrl = 'https://ipwho.is/'; // HTTPS supported
  static String _currencyCode = 'EGP';
  static String _currencySymbol = 'جنية';
  static double _exchangeRate = 1.0;

  // Base is EGP
  static final Map<String, double> _rates = {
    'EG': 1.0, // Egypt
    'US': 0.02, // USA (1 EGP = ~0.02 USD)
    'SA': 0.076, // Saudi Arabia
    'AE': 0.074, // UAE
    'KW': 0.0062, // Kuwait
    'QA': 0.073, // Qatar
    'BH': 0.0076, // Bahrain
    'OM': 0.0078, // Oman
    'JO': 0.014, // Jordan
    'LB': 1800.0, // Lebanon (volatile, maybe stick to USD?)
    'DE': 0.019, // Germany (Euro)
    'FR': 0.019, // France
    'IT': 0.019, // Italy
    'ES': 0.019, // Spain
    'GB': 0.016, // UK
    'CA': 0.027, // Canada
  };

  static final Map<String, String> _symbols = {
    'EG': 'جنية',
    'US': '\$',
    'SA': 'ر.س',
    'AE': 'د.إ',
    'KW': 'د.ك',
    'QA': 'ر.ق',
    'BH': 'د.ب',
    'OM': 'ر.ع',
    'JO': 'د.أ',
    'LB': 'ل.ل',
    'DE': '€',
    'FR': '€',
    'IT': '€',
    'ES': '€',
    'GB': '£',
    'CA': 'C\$',
  };

  static final Map<String, String> _codes = {
    'EG': 'EGP',
    'US': 'USD',
    'SA': 'SAR',
    'AE': 'AED',
    'KW': 'KWD',
    'QA': 'QAR',
    'BH': 'BHD',
    'OM': 'OMR',
    'JO': 'JOD',
    'LB': 'LBP',
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'GB': 'GBP',
    'CA': 'CAD',
  };

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to load cached country
      String? countryCode = prefs.getString('user_country_code');

      if (countryCode == null) {
        // Fetch from API (HTTPS)
        final response = await http.get(Uri.parse(_baseUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // ipwho.is uses 'country_code'
          if (data['success'] == true) {
            countryCode = data['country_code'];
            if (countryCode != null) {
              await prefs.setString('user_country_code', countryCode);
            }
          }
        }
      }

      if (countryCode != null && _rates.containsKey(countryCode)) {
        _exchangeRate = _rates[countryCode]!;
        _currencySymbol = _symbols[countryCode] ?? '\$';
        _currencyCode = _codes[countryCode] ?? 'USD';
      }
    } catch (e) {
      print('Currency init failed: $e');
      // Fallback to defaults (EGP)
    }
  }

  static String get currencySymbol => _currencySymbol;
  static String get currencyCode => _currencyCode;

  static double convert(double amountInEGP) {
    return amountInEGP * _exchangeRate;
  }

  static String format(dynamic amountInEGP) {
    double val = double.tryParse(amountInEGP.toString()) ?? 0.0;
    double converted = convert(val);
    return '${converted.toStringAsFixed(converted < 10 && _currencyCode != "KWD" ? 1 : 0)} $_currencySymbol';
  }
}
